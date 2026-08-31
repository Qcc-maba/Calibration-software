SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetCustomerPortalContactByEmail
    -----------------------------------
    Step 2 of the customer-portal login: does this e-mail belong to a customer contact?

    Two sources, in order:
      1. dbo.CustomerContacts  - the local mirror of Priority, fast and always available.
      2. Priority PHONEBOOK    - over the linked server, because the mirror only carries a fraction
                                 of the contacts that exist in Priority (~2k of ~22k). Without this
                                 fallback most legitimate contacts are told their e-mail is unknown.

    The Priority lookup is wrapped in TRY/CATCH: if the linked server is unreachable the procedure
    degrades to the mirror instead of failing the login outright.

    Returns exactly 0 or 1 rows. `Source` says where the match came from.

    2026-08-31 - MBA-943: which customer the SESSION is stamped with.
    ---------------------------------------------------------------------------------------------
    The row returned here becomes the session: CustomerId and CustomerName are signed into the
    cookie and shown in the portal header. It used to take the lowest CustomerContactId, so
    davide@iscar.co.il was greeted as "ישקר בע"מ" - a company record holding none of his devices -
    while every screen below showed devices from three other ישקר divisions. The header disagreed
    with the page.

    It now takes the PRIMARY customer from dbo.GetPortalCustomerIds: the one holding the most
    devices. When that function returns nothing (an address that is a contact of no customer with
    a devices record) the original lowest-id behaviour applies unchanged, so the Priority fallback
    path and brand-new customers are unaffected.

    MatchCount was documented as "a data-quality problem worth logging" when above 1. That is no
    longer the right reading: 3,684 addresses legitimately serve several customers, and the portal
    now shows all of them. It is kept as an informational count, not a warning.
*/
CREATE OR ALTER PROCEDURE dbo.GetCustomerPortalContactByEmail
    @Email NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));

    IF @NormalizedEmail IS NULL OR @NormalizedEmail = ''
        RETURN;

    DECLARE @CustomerContactId INT,
            @CustomerId        INT,
            @ContactName       NVARCHAR(100),
            @ContactPhone      NVARCHAR(100),
            @PriorityPhone     INT,
            @MatchCount        INT = 0,
            @Source            NVARCHAR(10),
            @PrimaryCustomerId INT;

    /* MBA-943: the customer this caller actually works with. NULL falls through to the old rule. */
    SELECT @PrimaryCustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@NormalizedEmail)
    WHERE IsPrimary = 1;

    /* ---------- 1. local mirror ---------- */
    SELECT TOP (1)
        @CustomerContactId = cc.CustomerContactId,
        @CustomerId        = cc.CustomerId,
        @ContactName       = cc.CustomerContactName,
        @ContactPhone      = cc.CustomerContactPhone
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
      AND (@PrimaryCustomerId IS NULL OR cc.CustomerId = @PrimaryCustomerId)
    ORDER BY cc.CustomerContactId ASC;   /* deterministic pick within the chosen customer */

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @Source = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail;
    END
    ELSE
    BEGIN
        /* ---------- 2. Priority fallback ---------- */
        CREATE TABLE #PriorityContacts (PHONE INT, CUST INT, NAME NVARCHAR(100), PHONENUM NVARCHAR(50));

        BEGIN TRY
            INSERT INTO #PriorityContacts (PHONE, CUST, NAME, PHONENUM)
            EXEC dbo.GetPriorityContactsByEmail @Email = @NormalizedEmail;
        END TRY
        BEGIN CATCH
            /* linked server unreachable - behave as "not found in Priority" */
            DELETE FROM #PriorityContacts;
        END CATCH

        SELECT TOP (1)
            @PriorityPhone = p.PHONE,
            @CustomerId    = c.CustomerId,
            @ContactName   = LEFT(LTRIM(RTRIM(p.NAME)), 100),
            @ContactPhone  = LEFT(LTRIM(RTRIM(p.PHONENUM)), 100)
        FROM #PriorityContacts AS p
        INNER JOIN dbo.Customers AS c
                ON c.CustomerIdFromSource = p.CUST
               AND c.IsDeleted = 0
        ORDER BY p.PHONE ASC;

        IF @PriorityPhone IS NOT NULL
        BEGIN
            SET @Source = N'Priority';

            SELECT @MatchCount = COUNT(DISTINCT c.CustomerId)
            FROM #PriorityContacts AS p
            INNER JOIN dbo.Customers AS c
                    ON c.CustomerIdFromSource = p.CUST
                   AND c.IsDeleted = 0;
        END

        DROP TABLE #PriorityContacts;
    END

    IF @Source IS NULL
        RETURN;   /* no rows: the e-mail is not a customer contact anywhere */

    SELECT
        @CustomerContactId AS CustomerContactId,
        @PriorityPhone     AS PriorityContactId,
        @CustomerId        AS CustomerId,
        @ContactName       AS CustomerContactName,
        @ContactPhone      AS CustomerContactPhone,
        @NormalizedEmail   AS Email,
        c.CustomerName,
        c.CustomerNameENG,
        c.CustomerCode,
        @MatchCount        AS MatchCount,
        @Source            AS Source
    FROM (SELECT 1 AS X) AS Anchor
    LEFT JOIN dbo.Customers AS c
           ON c.CustomerId = @CustomerId
          AND c.IsDeleted = 0;
END
GO
