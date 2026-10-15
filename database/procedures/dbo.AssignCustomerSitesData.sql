/*
    dbo.AssignCustomerSitesData                                                         MBA-627
    ---------------------------------------------------------------------------------------------
    Adds, edits and removes sub-sites (dbo.CustomerSites) from the portal profile screen - only
    sites of the customers the caller is a contact of.

    2026-10-15 - MBA-627: rewritten before its first caller. The previous definition (identical on
    STAGE and PROD, kept in database/_rollback/BOTH.dbo.AssignCustomerSitesData.before-MBA-627.sql)
    had no caller anywhere and the same faults as dbo.AssignCustomerContactsData:

      1. The remove path soft-deleted every id in @CustomerSitesIdsToRemove with no customer filter,
         and ran even when the e-mail resolved to nobody - any caller could delete any customer's
         sites by id. (SECURITY.md SEC-11.)
      2. The caller was resolved through dbo.GetSourceFilterByEmail (dbo.Users). A portal customer
         has no Users row, so @CustomerId was NULL: update silently did nothing, insert failed.

    The rules now:

      - The caller is the SET dbo.GetPortalCustomerIds returns - the same set dbo.GetCustomerSites
        lists sites for, so a caller can change exactly the sites the screen shows them.
      - Edit and remove: every id must be a site of a customer in that set. Removal is all or
        nothing - one foreign or unknown id refuses the whole call, rather than deleting the rest
        and leaving the screen to guess what happened.
      - Add: the new site goes to the caller's PRIMARY customer, the one dbo.GetCustomerProfile
        shows at the top of the same screen.
      - Portal callers only. The staff path is gone: the staff app has no server-side session
        (SEC-3), so an e-mail it sends proves nothing.

    Removal is this system's soft delete (IsDeleted), never a row delete.

    stg.MergeCustomersData matches sites on (CustomerId, CustomerSiteCode) and overwrites their
    text from Priority, so a site edited here that Priority also holds reverts on the next sync.
    Same known gap as the contacts; tracked on MBA-627. A site added here with a code Priority
    later uses for that customer would be taken over by Priority the same way.

    PARAMETERS
    ----------
    @CustomerSitesIdsToRemove   comma-separated CustomerSiteId list. When given, the call only
                                removes; every other parameter is ignored.
    @CustomerSiteId             edit that site. NULL with no removal list = add a new site.
    @RevertDeletion = 1         with @CustomerSiteId: bring a removed site back.
    The text fields: NULL keeps the current value on an edit.

    Refusals, all before anything is written:
      54101  the address is not a portal contact
      54102  a removal id is not a site of the caller (or not a number)
      54103  @CustomerSiteId is not a site of the caller
      54104  a new site's code is already used by a live site of the same customer
      54105  a new site has neither description nor address

    UpdateUserID is NULL on a portal write: the caller has no dbo.Users row. The sync writes 0.

    Returns the sites written.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignCustomerSitesData]
    @LoggedInUserEmail          NVARCHAR(100),
    @CustomerSitesIdsToRemove   NVARCHAR(400) = NULL,
    @CustomerSiteAddress        NVARCHAR(80)  = NULL,
    @CustomerSiteState          NVARCHAR(40)  = NULL,
    @CustomerSiteZIP            NVARCHAR(10)  = NULL,
    @CustomerSitePhone          NVARCHAR(30)  = NULL,
    @CustomerSiteDescription    NVARCHAR(50)  = NULL,
    @CustomerSiteCode           INT           = NULL,
    @CustomerSiteAddressENG     NVARCHAR(80)  = NULL,
    @CustomerSiteStateENG       NVARCHAR(40)  = NULL,
    @CustomerSiteDescriptionENG NVARCHAR(50)  = NULL,
    @CustomerSiteId             INT           = NULL,
    @RevertDeletion             BIT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    SELECT m.CustomerId, m.IsPrimary
    INTO #Mine
    FROM dbo.GetPortalCustomerIds(@Email) AS m;

    IF NOT EXISTS (SELECT 1 FROM #Mine)
        THROW 54101, 'The address does not belong to any customer contact.', 1;

    DECLARE @Written TABLE (CustomerSiteId INT PRIMARY KEY);

    /* ---- Remove ------------------------------------------------------------------------- */
    IF @CustomerSitesIdsToRemove IS NOT NULL
    BEGIN
        /* Keep every non-blank entry, numeric or not, so a junk entry is refused below instead of
           silently dropped. STRING_SPLIT('', ',') yields one empty string (the MBA-902 trap). */
        DECLARE @Requested TABLE (Value NVARCHAR(400) NOT NULL);
        INSERT INTO @Requested (Value)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@CustomerSitesIdsToRemove, ',')
        WHERE LTRIM(RTRIM(value)) <> N'';

        IF NOT EXISTS (SELECT 1 FROM @Requested)
           OR EXISTS (SELECT 1 FROM @Requested AS r
                      WHERE r.Value LIKE N'%[^0-9]%' OR LEN(r.Value) > 9
                         OR NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                                        INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
                                        WHERE cs.CustomerSiteId = TRY_CAST(r.Value AS INT)))
            THROW 54102, 'A site to remove does not belong to the caller.', 1;

        BEGIN TRAN;
            UPDATE cs
            SET  cs.IsDeleted    = 1
                ,cs.UpdatedDate  = GETDATE()
                ,cs.UpdateUserID = NULL
            OUTPUT inserted.CustomerSiteId INTO @Written (CustomerSiteId)
            FROM dbo.CustomerSites AS cs
            INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
            INNER JOIN @Requested AS r ON cs.CustomerSiteId = TRY_CAST(r.Value AS INT);
        COMMIT;
    END

    /* ---- Edit --------------------------------------------------------------------------- */
    ELSE IF @CustomerSiteId IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                       INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
                       WHERE cs.CustomerSiteId = @CustomerSiteId)
            THROW 54103, 'The site does not belong to the caller.', 1;

        BEGIN TRAN;
            UPDATE cs
            SET  cs.CustomerSiteAddress        = COALESCE(@CustomerSiteAddress, cs.CustomerSiteAddress)
                ,cs.CustomerSiteState          = COALESCE(@CustomerSiteState, cs.CustomerSiteState)
                ,cs.CustomerSiteZIP            = COALESCE(@CustomerSiteZIP, cs.CustomerSiteZIP)
                ,cs.CustomerSitePhone          = COALESCE(@CustomerSitePhone, cs.CustomerSitePhone)
                ,cs.CustomerSiteDescription    = COALESCE(@CustomerSiteDescription, cs.CustomerSiteDescription)
                ,cs.CustomerSiteAddressENG     = COALESCE(@CustomerSiteAddressENG, cs.CustomerSiteAddressENG)
                ,cs.CustomerSiteStateENG       = COALESCE(@CustomerSiteStateENG, cs.CustomerSiteStateENG)
                ,cs.CustomerSiteDescriptionENG = COALESCE(@CustomerSiteDescriptionENG, cs.CustomerSiteDescriptionENG)
                ,cs.IsDeleted                  = IIF(@RevertDeletion = 1, 0, cs.IsDeleted)
                ,cs.UpdatedDate                = GETDATE()
                ,cs.UpdateUserID               = NULL
            OUTPUT inserted.CustomerSiteId INTO @Written (CustomerSiteId)
            FROM dbo.CustomerSites AS cs
            INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
            WHERE cs.CustomerSiteId = @CustomerSiteId;
        COMMIT;
    END

    /* ---- Add ---------------------------------------------------------------------------- */
    ELSE
    BEGIN
        DECLARE @PrimaryCustomerId INT = (SELECT TOP (1) m.CustomerId FROM #Mine AS m
                                          ORDER BY m.IsPrimary DESC, m.CustomerId);

        IF NULLIF(LTRIM(RTRIM(@CustomerSiteDescription)), N'') IS NULL
           AND NULLIF(LTRIM(RTRIM(@CustomerSiteAddress)), N'') IS NULL
            THROW 54105, 'A new site needs a description or an address.', 1;

        /* (CustomerId, CustomerSiteCode) is the key the Priority sync matches on. */
        IF @CustomerSiteCode IS NOT NULL
           AND EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                       WHERE cs.CustomerId = @PrimaryCustomerId
                         AND cs.CustomerSiteCode = @CustomerSiteCode
                         AND cs.IsDeleted = 0)
            THROW 54104, 'A site with this code already exists for the customer.', 1;

        BEGIN TRAN;
            INSERT INTO dbo.CustomerSites
                (CustomerId, CustomerSiteAddress, CustomerSiteState, CustomerSiteZIP, CustomerSitePhone,
                 CustomerSiteDescription, CustomerSiteCode, CreateDate, UpdateUserID, IsDeleted, SourceId,
                 CustomerSiteAddressENG, CustomerSiteStateENG, CustomerSiteDescriptionENG)
            OUTPUT inserted.CustomerSiteId INTO @Written (CustomerSiteId)
            SELECT @PrimaryCustomerId, @CustomerSiteAddress, @CustomerSiteState, @CustomerSiteZIP, @CustomerSitePhone,
                   @CustomerSiteDescription, @CustomerSiteCode, GETDATE(), NULL, 0, c.SourceId,
                   @CustomerSiteAddressENG, @CustomerSiteStateENG, @CustomerSiteDescriptionENG
            FROM dbo.Customers AS c
            WHERE c.CustomerId = @PrimaryCustomerId;
        COMMIT;
    END

    SELECT cs.CustomerSiteId             AS customerSiteId,
           cs.CustomerId                 AS customerId,
           c.CustomerName                AS customerName,
           cs.CustomerSiteDescription    AS description,
           cs.CustomerSiteAddress        AS address,
           cs.CustomerSiteState          AS state,
           cs.CustomerSiteZIP            AS zip,
           cs.CustomerSitePhone          AS phone,
           cs.CustomerSiteCode           AS siteCode,
           cs.CustomerSiteDescriptionENG AS descriptionENG,
           cs.CustomerSiteAddressENG     AS addressENG,
           cs.CustomerSiteStateENG       AS stateENG,
           cs.IsDeleted                  AS isDeleted
    FROM @Written AS w
    INNER JOIN dbo.CustomerSites AS cs ON cs.CustomerSiteId = w.CustomerSiteId
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = cs.CustomerId
    ORDER BY cs.CustomerSiteId;
END
GO
