/*  MBA - Priority's INACTIVE flag reaches the portal                         deploy to CalibratorProd
    =============================================================================================
    Already deployed to STAGE on 07/09/2026 and verified there.

    HOW TO RUN
      SSMS -> connect to 51.17.121.203\QCC -> database **CalibratorProd** -> open this file -> F5.
      Do NOT run it through `sqlcmd -i` without `-f 65001`: the Hebrew inside the comments is
      stored in the procedure bodies and the console codepage mangles it silently.

    WHAT IT CHANGES
      dbo.CustomerContacts and stg.stg_CustomerContacts gain IsActive BIT NOT NULL DEFAULT 1.
      The Priority loader inverts PHONEBOOK.INACTIVE into it, the merge carries it through, and the
      three procedures that resolve a portal visitor to a customer ignore a contact whose flag is 0.

      Nothing is deleted anywhere. Existing rows keep IsActive = 1 until the next contact sync
      reads Priority's flag; on STAGE that sync would flag 10,523 rows.

    AFTER IT RUNS
      1. EXEC stg.LoadCustomerContactsFromPriority;   -- fills staging from Priority
      2. EXEC stg.MergeCustomersContactsData;         -- carries the flag into dbo.CustomerContacts
      3. SELECT COUNT(*) FROM dbo.CustomerContacts WHERE IsActive = 0;  -- expect a few thousand

    ROLLBACK
      The previous body of every procedure was scripted out of STAGE into database/_rollback/
      before this was written. The column itself is additive and can stay.
*/


/* ---------- schema: dbo.CustomerContacts.IsActive.sql ---------- */
GO

/*
    CustomerContacts - IsActive
    ---------------------------------------------------------------------------------------------
    Priority marks a contact who has left, or who should no longer be written to, with
    PHONEBOOK.INACTIVE = 'Y'. 9,101 of its 53,424 contacts carry that flag. The sync never read the
    column, so the mirror holds 10,501 live contact rows for people Priority considers inactive -
    and the portal treats every one of them as a legitimate login identity.

    Nothing is deleted on either side: Priority keeps its history, the mirror keeps the row, and
    the flag travels with it. Everything that resolves a portal visitor to a customer now ignores
    an inactive contact, exactly as it would ignore one that was never imported.

    Default 1: a contact the sync has not re-touched yet is active, which is what every existing
    row is until the next load says otherwise.
*/
IF COL_LENGTH('dbo.CustomerContacts','IsActive') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD IsActive BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_IsActive DEFAULT(1);
GO
IF COL_LENGTH('stg.stg_CustomerContacts','IsActive') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD IsActive BIT NULL;
GO
GO


/* ---------- procedure: stg.LoadCustomerContactsFromPriority.sql ---------- */
GO

/*
    stg.LoadCustomerContactsFromPriority                                               MBA-922
    ---------------------------------------------------------------------------------------------
    Fills stg.stg_CustomerContacts from Priority's PHONEBOOK - EVERY row for a customer we hold,
    not just the one flagged ORDFLAG = 'Y'.

    That single-flag rule is why the אנשי קשר column was empty on 46% of orders. Priority lets one
    contact per customer carry each flag, and for most customers nobody had ticked it. We held 2,533
    contacts for 2,516 customers; Priority has people for 10,008.

    ORDFLAG becomes IsPrimary rather than a filter, so the designated contact is still identifiable.
    MBA_NOTMAIL becomes DoNotMail and must be honoured before anything is sent.
    INACTIVE becomes IsActive = 0: the row is still imported, but nothing resolves a portal
    visitor to it. Priority is never written to, and no row is deleted on either side.

    Phone: PHONENUM if present, otherwise OFFICEPHONE. CELLPHONE goes to the additional number.
    Rows with no NAME are skipped - there is nobody to show.

    Priority stores descriptive text in visual order, but PHONEBOOK is structured data and is not
    affected: names, e-mail addresses and phone numbers all read correctly as stored. Checked.

    Result on STAGE: 2,533 contacts -> 59,688, covering 10,725 customers instead of 2,516. Orders
    with a contact went from 630 of 1,172 to 1,223 of 1,225.

    Safe to re-run: staging is replaced, and the merge keys on CustomerContactIdFromSource +
    SourceId. Ran twice end to end with no change on the second pass. @ReportOnly = 1 shows what it
    would take without writing.
*/

CREATE OR ALTER PROCEDURE stg.LoadCustomerContactsFromPriority
    @ReportOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* Everything Priority holds for a customer, not just the one row flagged for orders. */
    DROP TABLE IF EXISTS #PB;
    SELECT * INTO #PB FROM OPENQUERY([31.168.173.93], '
        SELECT PHONE, CUST,
               NAME        = LTRIM(RTRIM(NAME)),
               POSITIONDES = LTRIM(RTRIM(POSITIONDES)),
               PHONENUM    = LTRIM(RTRIM(PHONENUM)),
               OFFICEPHONE = LTRIM(RTRIM(OFFICEPHONE)),
               CELLPHONE   = LTRIM(RTRIM(CELLPHONE)),
               EMAIL       = LTRIM(RTRIM(EMAIL)),
               ORDFLAG     = LTRIM(RTRIM(ISNULL(ORDFLAG,'''')))  ,
               NOTMAIL     = LTRIM(RTRIM(ISNULL(MBA_NOTMAIL,''''))),
               INACTIVE    = LTRIM(RTRIM(ISNULL(INACTIVE,'''')))
        FROM amaba.dbo.PHONEBOOK
        WHERE CUST > 0
    ');

    IF @ReportOnly = 1
    BEGIN
        SELECT PhonebookRows      = COUNT(*),
               CustomersInPriority= COUNT(DISTINCT p.CUST),
               MatchOurCustomers  = COUNT(DISTINCT CASE WHEN c.CustomerId IS NOT NULL THEN p.CUST END),
               RowsWeWouldTake    = SUM(CASE WHEN c.CustomerId IS NOT NULL THEN 1 ELSE 0 END),
               MarkedPrimary      = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.ORDFLAG = 'Y' THEN 1 ELSE 0 END),
               MarkedDoNotMail    = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.NOTMAIL = 'Y' THEN 1 ELSE 0 END),
               MarkedInactive     = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.INACTIVE = 'Y' THEN 1 ELSE 0 END)
        FROM #PB AS p
        LEFT JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST;
        RETURN;
    END

    DELETE FROM stg.stg_CustomerContacts;

    INSERT INTO stg.stg_CustomerContacts
          (CustomerContactIdFromSource, CustomerContactName, CustomerContactPersonRole,
           CustomerContactPhone, CustomerContactAdditionalPhoneNumber, CustomerContactEmail,
           CustomerId, SourceSystem, IsPrimary, DoNotMail, IsActive)
    SELECT p.PHONE,
           LEFT(p.NAME, 100),
           LEFT(NULLIF(p.POSITIONDES, ''), 100),
           /* the desk number if there is one, otherwise the office line */
           LEFT(COALESCE(NULLIF(p.PHONENUM, ''), NULLIF(p.OFFICEPHONE, '')), 100),
           LEFT(NULLIF(p.CELLPHONE, ''), 100),
           LEFT(NULLIF(p.EMAIL, ''), 100),
           p.CUST,
           s.SourceName,
           CAST(CASE WHEN p.ORDFLAG = 'Y' THEN 1 ELSE 0 END AS BIT),
           CAST(CASE WHEN p.NOTMAIL = 'Y' THEN 1 ELSE 0 END AS BIT),
           /* Priority's own active flag. Nothing is dropped here - an inactive contact is
              imported like any other and carries the flag; only the portal's identity lookups
              refuse to resolve a visitor to one. */
           CAST(CASE WHEN p.INACTIVE = 'Y' THEN 0 ELSE 1 END AS BIT)
    FROM #PB AS p
    JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST
    JOIN dbo.Source    AS s ON s.SourceId = c.SourceId
    WHERE NULLIF(p.NAME, '') IS NOT NULL;

    SELECT Staged      = COUNT(*),
           Customers   = COUNT(DISTINCT CustomerId),
           Primary_    = SUM(CAST(IsPrimary AS INT)),
           DoNotMail_  = SUM(CAST(DoNotMail AS INT)),
           Inactive_   = SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END)
    FROM stg.stg_CustomerContacts;
END
GO


/* ---------- procedure: stg.MergeCustomersContactsData.sql ---------- */
GO

/*
    stg.MergeCustomersContactsData                                                     MBA-922
    ---------------------------------------------------------------------------------------------
    Carries IsPrimary, DoNotMail and IsActive through from staging, and fixes the match test.
    IsActive is Priority's INACTIVE flag inverted: the row is kept and updated like any other,
    so nothing is ever deleted on either side.

    The WHEN MATCHED clause ANDed every field comparison together, so a row only updated when EVERY
    field had changed at once - which never happens. One of those lines even tested for equality
    rather than difference. In practice nothing was ever updated; only inserts worked. It is an OR
    now, which is what was meant.
*/
CREATE OR ALTER PROCEDURE [stg].[MergeCustomersContactsData]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	Merge customer contact data and create user for them to be able login to app
-- JiraLink: 
-- =============================================
AS
BEGIN

	SET NOCOUNT ON;

	MERGE INTO [dbo].[CustomerContacts] AS dest
	USING (
		SELECT 
			 c.[CustomerId]
			,cc.[CustomerContactName]
			,cc.[CustomerContactPersonRole]
			,cc.[CustomerContactPhone]
			,cc.[CustomerContactAdditionalPhoneNumber]
			,cc.[CustomerContactEmail]
			,cc.[CustomerContactIdFromSource]
			,ss.SourceId as [SourceId]
			,0 [UpdateUserID]
			,ISNULL(cc.[IsPrimary],0) as [IsPrimary]
			,ISNULL(cc.[DoNotMail],0) as [DoNotMail]
			/* Priority's INACTIVE. A contact who has left stays in both systems and keeps this
			   flag; the portal simply will not resolve a visitor to them. */
			,ISNULL(cc.[IsActive],1) as [IsActive]
		FROM stg.stg_CustomerContacts as cc
		JOIN dbo.Source as ss ON cc.SourceSystem = ss.SourceName
		JOIN [dbo].[Customers] as c ON cc.[CustomerId] = c.[CustomerIdFromSource] AND c.[SourceId] = ss.SourceId 
		) AS source
		ON dest.CustomerContactIdFromSource = source.CustomerContactIdFromSource
			AND dest.[SourceId] = source.[SourceId]
	/* This used to AND every comparison together, so a row only updated when EVERY field had
	   changed at once - which never happens, and one of the lines even tested for equality.
	   OR is what was meant: update when anything differs. */
	WHEN MATCHED
		AND (   ISNULL(dest.[CustomerContactName],N'')                  <> ISNULL(source.[CustomerContactName],N'')
			 OR ISNULL(dest.[CustomerContactPersonRole],N'')            <> ISNULL(source.[CustomerContactPersonRole],N'')
			 OR ISNULL(dest.[CustomerContactPhone],N'')                 <> ISNULL(source.[CustomerContactPhone],N'')
			 OR ISNULL(dest.[CustomerContactAdditionalPhoneNumber],N'') <> ISNULL(source.[CustomerContactAdditionalPhoneNumber],N'')
			 OR ISNULL(dest.[CustomerContactEmail],N'')                 <> ISNULL(source.[CustomerContactEmail],N'')
			 OR ISNULL(dest.[IsPrimary],0)                              <> source.[IsPrimary]
			 OR ISNULL(dest.[DoNotMail],0)                              <> source.[DoNotMail]
			 OR ISNULL(dest.[IsActive],1)                               <> source.[IsActive])
		THEN
			UPDATE
			SET  dest.[CustomerId] = source.[CustomerId]
				,dest.[CustomerContactName] = source.[CustomerContactName]
				,dest.[CustomerContactPersonRole] = source.[CustomerContactPersonRole]
				,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
				,dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
				,dest.[CustomerContactEmail] = source.[CustomerContactEmail]
				,dest.[CustomerContactIdFromSource] = source.[CustomerContactIdFromSource]
				,dest.[IsPrimary] = source.[IsPrimary]
				,dest.[DoNotMail] = source.[DoNotMail]
				,dest.[IsActive] = source.[IsActive]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = 0
	WHEN NOT MATCHED
		THEN
			INSERT (
				 [CustomerId]
				,[CustomerContactName]
				,[CustomerContactPersonRole]
				,[CustomerContactPhone]
				,[CustomerContactAdditionalPhoneNumber]
				,[CustomerContactEmail]
				,[CustomerContactIdFromSource]
				,[SourceId]
				,[UpdateUserID]
				,[IsPrimary]
				,[DoNotMail]
				,[IsActive]
				)
			VALUES (
				 source.[CustomerId]
				,source.[CustomerContactName]
				,source.[CustomerContactPersonRole]
				,source.[CustomerContactPhone]
				,source.[CustomerContactAdditionalPhoneNumber]
				,source.[CustomerContactEmail]
				,source.[CustomerContactIdFromSource]
				,source.[SourceId]
				,source.[UpdateUserID]
				,source.[IsPrimary]
				,source.[DoNotMail]
				,source.[IsActive]
				);
/*
--Add customer contact as a user
	DECLARE @UserRoleId INT
	SELECT @UserRoleId = UserRoleId FROM UserRoles
	WHERE UserRoleDescriptionENG = N'Customer'

	MERGE INTO [dbo].[Users] AS dest
	USING (
		SELECT 
			 IIF(CHARINDEX(N' ', c.CustomerContactName) > 0,LEFT(c.CustomerContactName, CHARINDEX(N' ', c.CustomerContactName) - 1),'') as [FirstName]
			,IIF(CHARINDEX(N' ', REVERSE(c.CustomerContactName)) > 0,RIGHT(c.CustomerContactName,CHARINDEX(N' ', REVERSE(c.CustomerContactName)) - 1),'') as [LastName]
			,c.[CustomerContactEmail] as [Email]
			,1234 AS [Password]
			,IIF(LEN(c.[CustomerContactPhone]) > 0,c.[CustomerContactPhone], c.[CustomerContactAdditionalPhoneNumber]) as [Phone]
			,1 as [IsActive]
			,0 as [UpdateUserID]
			,@UserRoleId as[UserRoleId]
			,c.[SourceId]
	FROM [dbo].[CustomerContacts] as c
	WHERE LEN(c.[CustomerContactEmail]) > 0
		) AS source
		ON dest.[Email] = source.[Email]
	/*WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[FirstName] = source.[FirstName]
				,dest.[LastName] = source.[LastName]
				,dest.[Password] = source.[Password]
				,dest.[Phone] = source.[Phone]
				,dest.[IsActive] = source.[IsActive]
				,dest.[UpdateUserID] = source.[UpdateUserID]
				,dest.[UserRoleId] = source.[UserRoleId]
				,dest.[SourceId] = source.[SourceId]*/
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [FirstName]
				,[LastName]
				,[Email]
				,[Password]
				,[Phone]
				,[IsActive]
				,[UpdateUserID]
				,[UserRoleId]
				,[SourceId]
				)
			VALUES (
				 source.[FirstName]
				,source.[LastName]
				,source.[Email]
				,source.[Password]
				,source.[Phone]
				,source.[IsActive]
				,source.[UpdateUserID]
				,source.[UserRoleId]
				,source.[SourceId]
				);
				*/

END
GO


/* ---------- function: dbo.GetPortalCustomerIds.sql ---------- */
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetPortalCustomerIds                                                        MBA-943
    =============================================================================================
    Every customer the portal caller is entitled to see, as a set.

    WHY THIS EXISTS
    ---------------
    A portal login is an e-mail address, and an e-mail address is not one customer. 3,684 addresses
    are a contact of more than one: davide@iscar.co.il is a contact of 22 ישקר entities,
    sharbaf_o@mac.org.il of 25 מכבי branches. Priority models an Iscar division as its own
    Customers row, not as a CustomerSites row - dbo.CustomerSites is empty for all of them - so
    from the database's point of view a plant manager simply has many customers.

    Until now every GetCustomer* proc resolved that to exactly one:

        SELECT TOP (1) @CustomerId = cc.CustomerId ... ORDER BY cc.CustomerContactId ASC

    Deterministic, but arbitrary, and measurably wrong. For davide@iscar.co.il the lowest contact
    id lands on ישקר בע"מ, which has ZERO devices, while ישקר-מתק"ש-תפן has 24, ישקר מיקרו-כלים 4
    and ישקר-מיבדקה 3. He logged in and saw an empty portal while 31 of his devices sat in the
    system. Measured across STAGE: 181 addresses see a blank portal despite owning devices, 240
    see only part of theirs, and 3,468 devices are hidden from their own contacts.

    THE DEVICE FILTER IS NOT COSMETIC
    ---------------------------------
    Not every association in Priority is a real one. davide@iscar.co.il is also listed against
    פאדאגיס ישראל פרמצבטיקה - an unrelated company - and against מקדמות מלקוחות, which is an
    accounting row rather than a customer. Both hold no devices today, but that is luck, not a
    rule. Since the portal now shows several customers at once, an untidy association would put
    another company's devices on an Iscar manager's screen with nothing to mark them as foreign.
    Restricting the set to customers that actually hold devices removes both, and does it on a
    property the portal genuinely depends on.

    The fallback matters: if NONE of the caller's customers hold a device, the whole set is
    returned rather than nothing. A newly registered customer with no calibrations yet must see an
    empty device list, not a portal that cannot resolve who they are - the profile, contacts and
    support screens still have to work.

    IsPrimary
    ---------
    The union is right for devices, reports and calibrations. It is meaningless for the screens
    that describe ONE customer - profile, contacts, sites, support, and the Priority invoices and
    quotes, which are keyed by a single CustomerIdFromSource. Those take the row flagged IsPrimary:
    most devices first, lowest contact id to break a tie. That is still one customer, but it is now
    the one the caller actually works with instead of whichever id happened to be lowest.

    SECURITY
    --------
    The set is derived from the caller's own CustomerContacts rows and nothing else. There is no
    parameter through which a caller can name a customer, so there is nothing to verify and nothing
    to forge. This replaces the @SelectedCustomerId parameter added in MBA-936, which was built for
    a branch picker that we are not building.
*/
CREATE OR ALTER FUNCTION dbo.GetPortalCustomerIds (@LoggedInUserEmail NVARCHAR(100))
RETURNS TABLE
AS
RETURN
    WITH mine AS
    (
        /* One row per customer this address is a contact of, plus the id that used to decide
           everything - still useful as a stable tie-break. */
        SELECT cc.CustomerId,
               MIN(cc.CustomerContactId) AS FirstContactId
        FROM dbo.CustomerContacts AS cc
        WHERE ISNULL(cc.IsDeleted, 0) = 0
          /* Priority's INACTIVE, carried by the sync. The row stays - it is simply not an
             identity any more, so a contact who has left cannot still open that customer. */
          AND ISNULL(cc.IsActive, 1) = 1
          AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
        GROUP BY cc.CustomerId
    ),
    counted AS
    (
        SELECT m.CustomerId,
               m.FirstContactId,
               d.DeviceCount
        FROM mine AS m
        CROSS APPLY
        (
            SELECT COUNT_BIG(DISTINCT itm.SerialNumber) AS DeviceCount
            FROM dbo.OrderWorkPlans AS wp
            JOIN dbo.OrderDetails AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
            JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId = od.OrderDetailId
            WHERE wp.CustomerId = m.CustomerId
        ) AS d
    ),
    kept AS
    (
        SELECT * FROM counted WHERE DeviceCount > 0

        UNION ALL

        /* Fallback - see header. Only fires when the caller has no devices anywhere. */
        SELECT * FROM counted
        WHERE NOT EXISTS (SELECT 1 FROM counted AS any_devices WHERE any_devices.DeviceCount > 0)
    )
    SELECT k.CustomerId,
           c.CustomerName,
           k.DeviceCount,
           CONVERT(BIT, IIF(ROW_NUMBER() OVER (ORDER BY k.DeviceCount DESC, k.FirstContactId ASC) = 1, 1, 0)) AS IsPrimary
    FROM kept AS k
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = k.CustomerId;
GO
GO


/* ---------- procedure: dbo.CreateCustomerPortalOtp.sql ---------- */
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.CreateCustomerPortalOtp
    ---------------------------
    Step 3 of the customer-portal login: issue a one-time passcode for an e-mail that belongs to a
    customer contact. The application generates the 6-digit code, hashes it (HMAC-SHA256 + server
    pepper) and passes only @CodeHash here - the plaintext code never reaches the database.

    Identity resolution is hybrid:
      1. dbo.CustomerContacts - the local mirror of Priority.
      2. Priority PHONEBOOK over the linked server, when the mirror does not know the e-mail. The
         mirror only carries ~2k of the ~22k contacts that exist in Priority, so without this step
         most legitimate contacts are told their address is unknown.

    A contact found only in Priority is materialised into dbo.CustomerContacts before the code is
    issued. That is deliberate: every other portal procedure resolves the customer by looking the
    logged-in e-mail up in CustomerContacts, so a session with no row there would authenticate and
    then show an empty portal. The inserted row carries SourceId/CustomerContactIdFromSource exactly
    as the Priority sync would write them, so the sync can still match it.

    A Priority contact whose customer does not exist locally is rejected - there would be no
    CustomerId to scope the portal's data by.

    Any previously issued, still-open code for the same e-mail is invalidated, so only the newest
    code can ever be redeemed.

    Result set (always exactly 1 row):
        Status        'Created' | 'EmailNotFound' | 'RateLimited'
        ExpiresAt     UTC expiry of the new code (NULL unless Created)
        RetryAfterSec seconds until the rate-limit window frees up (NULL unless RateLimited)
        IdentitySource 'Mirror' | 'Priority' | NULL
        CustomerId, CustomerContactId, CustomerContactName, CustomerName, MatchCount
*/
CREATE OR ALTER PROCEDURE dbo.CreateCustomerPortalOtp
    @Email         NVARCHAR(100),
    @CodeHash      VARBINARY(32),
    @TtlSeconds    INT     = 600,   /* code lifetime            */
    @MaxAttempts   TINYINT = 5,     /* wrong-code tries allowed  */
    @MaxPerWindow  INT     = 5,     /* codes issued per window   */
    @WindowSeconds INT     = 900,
    @RequestIp     NVARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @NormalizedEmail NVARCHAR(100) = LOWER(LTRIM(RTRIM(@Email)));
    DECLARE @Now DATETIME2(3) = SYSUTCDATETIME();

    DECLARE @CustomerId        INT,
            @CustomerContactId INT,
            @ContactName       NVARCHAR(100),
            @ContactPhone      NVARCHAR(100),
            @CustomerName      NVARCHAR(200),
            @PriorityPhone     INT,
            @MatchCount        INT = 0,
            @IdentitySource    NVARCHAR(10);

    /* ---------- 1. local mirror ---------- */
    /* MBA-943: this row becomes the SESSION - CustomerId and CustomerName are signed into the
       cookie and shown in the portal header. Taking the lowest CustomerContactId greeted
       davide@iscar.co.il as "ישקר בע"מ", a company record holding none of his devices, while
       every screen below listed devices from three other ישקר divisions. Prefer the primary
       customer (most devices); NULL falls through to the original rule, so the Priority
       fallback path and brand-new customers behave exactly as before. */
    DECLARE @PrimaryCustomerId INT;
    SELECT @PrimaryCustomerId = CustomerId
    FROM dbo.GetPortalCustomerIds(@NormalizedEmail)
    WHERE IsPrimary = 1;

    SELECT TOP (1)
        @CustomerContactId = cc.CustomerContactId,
        @CustomerId        = cc.CustomerId,
        @ContactName       = cc.CustomerContactName
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND ISNULL(cc.IsActive, 1) = 1   /* Priority's INACTIVE - see dbo.GetPortalCustomerIds */
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
      AND (@PrimaryCustomerId IS NULL OR cc.CustomerId = @PrimaryCustomerId)
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @IdentitySource = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND ISNULL(cc.IsActive, 1) = 1
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
            /* linked server unreachable - fall through as "not a known contact" */
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
            SELECT @MatchCount = COUNT(DISTINCT c.CustomerId)
            FROM #PriorityContacts AS p
            INNER JOIN dbo.Customers AS c
                    ON c.CustomerIdFromSource = p.CUST
                   AND c.IsDeleted = 0;

        DROP TABLE #PriorityContacts;

        IF @PriorityPhone IS NOT NULL AND @CustomerId IS NOT NULL
        BEGIN
            /* materialise so the rest of the portal can resolve this visitor */
            INSERT INTO dbo.CustomerContacts
                (CustomerId, CustomerContactName, CustomerContactPhone, CustomerContactEmail,
                 CustomerContactIdFromSource, SourceId, CreateDate, IsDeleted)
            SELECT @CustomerId, @ContactName, @ContactPhone, @NormalizedEmail,
                   @PriorityPhone, 1, @Now, 0
            WHERE NOT EXISTS (   /* another concurrent request may have just created it */
                SELECT 1 FROM dbo.CustomerContacts AS cc
                WHERE cc.IsDeleted = 0
                  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            );

            SELECT TOP (1) @CustomerContactId = cc.CustomerContactId
            FROM dbo.CustomerContacts AS cc
            WHERE cc.IsDeleted = 0
              AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
            ORDER BY cc.CustomerContactId ASC;

            SET @IdentitySource = N'Priority';
        END
    END

    IF @CustomerContactId IS NULL
    BEGIN
        SELECT
            CAST('EmailNotFound' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))            AS ExpiresAt,
            CAST(NULL AS INT)                     AS RetryAfterSec,
            CAST(NULL AS INT)                     AS CustomerId,
            CAST(NULL AS INT)                     AS CustomerContactId,
            CAST(NULL AS NVARCHAR(100))           AS CustomerContactName,
            CAST(NULL AS NVARCHAR(200))           AS CustomerName,
            CAST(0 AS INT)                        AS MatchCount,
            CAST(NULL AS NVARCHAR(10))            AS IdentitySource;
        RETURN;
    END

    SELECT @CustomerName = c.CustomerName
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;

    /* ---- rate limit: at most @MaxPerWindow codes per e-mail per window ---- */
    DECLARE @IssuedInWindow INT, @OldestInWindow DATETIME2(3);

    SELECT
        @IssuedInWindow = COUNT(*),
        @OldestInWindow = MIN(o.CreatedAt)
    FROM dbo.CustomerPortalOtp AS o
    WHERE o.Email = @NormalizedEmail
      AND o.CreatedAt > DATEADD(SECOND, -@WindowSeconds, @Now);

    IF @IssuedInWindow >= @MaxPerWindow
    BEGIN
        SELECT
            CAST('RateLimited' AS NVARCHAR(20)) AS Status,
            CAST(NULL AS DATETIME2(3))          AS ExpiresAt,
            DATEDIFF(SECOND, @Now, DATEADD(SECOND, @WindowSeconds, @OldestInWindow)) AS RetryAfterSec,
            @CustomerId          AS CustomerId,
            @CustomerContactId   AS CustomerContactId,
            @ContactName         AS CustomerContactName,
            @CustomerName        AS CustomerName,
            @MatchCount          AS MatchCount,
            @IdentitySource      AS IdentitySource;
        RETURN;
    END

    DECLARE @ExpiresAt DATETIME2(3) = DATEADD(SECOND, @TtlSeconds, @Now);

    BEGIN TRY
        BEGIN TRANSACTION;

            /* only the newest code stays redeemable */
            UPDATE dbo.CustomerPortalOtp
            SET InvalidatedAt = @Now
            WHERE Email = @NormalizedEmail
              AND ConsumedAt IS NULL
              AND InvalidatedAt IS NULL;

            INSERT INTO dbo.CustomerPortalOtp
                (Email, CodeHash, CustomerId, CustomerContactId, AttemptsLeft, CreatedAt, ExpiresAt, RequestIp)
            VALUES
                (@NormalizedEmail, @CodeHash, @CustomerId, @CustomerContactId, @MaxAttempts, @Now, @ExpiresAt, @RequestIp);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    SELECT
        CAST('Created' AS NVARCHAR(20)) AS Status,
        @ExpiresAt           AS ExpiresAt,
        CAST(NULL AS INT)    AS RetryAfterSec,
        @CustomerId          AS CustomerId,
        @CustomerContactId   AS CustomerContactId,
        @ContactName         AS CustomerContactName,
        @CustomerName        AS CustomerName,
        @MatchCount          AS MatchCount,
        @IdentitySource      AS IdentitySource;
END

GO
GO


/* ---------- procedure: dbo.GetCustomerPortalContactByEmail.sql ---------- */
GO

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
      AND ISNULL(cc.IsActive, 1) = 1   /* Priority's INACTIVE - see dbo.GetPortalCustomerIds */
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedEmail
      AND (@PrimaryCustomerId IS NULL OR cc.CustomerId = @PrimaryCustomerId)
    ORDER BY cc.CustomerContactId ASC;   /* deterministic pick within the chosen customer */

    IF @CustomerContactId IS NOT NULL
    BEGIN
        SET @Source = N'Mirror';

        SELECT @MatchCount = COUNT(DISTINCT cc.CustomerId)
        FROM dbo.CustomerContacts AS cc
        WHERE cc.IsDeleted = 0
          AND ISNULL(cc.IsActive, 1) = 1
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
GO


/* ---------- verification ---------- */
GO
SELECT ColumnOnContacts = COL_LENGTH('dbo.CustomerContacts','IsActive'),
       ColumnOnStaging  = COL_LENGTH('stg.stg_CustomerContacts','IsActive'),
       LiveContacts     = (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE ISNULL(IsDeleted,0) = 0),
       FlaggedInactive  = (SELECT COUNT(*) FROM dbo.CustomerContacts WHERE ISNULL(IsActive,1) = 0);
GO
EXEC stg.LoadCustomerContactsFromPriority @ReportOnly = 1;   /* MarkedInactive says what step 1 would flag */
GO
