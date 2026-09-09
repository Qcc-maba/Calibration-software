/*
    Tranche C - objects that do NOT exist on PROD. Run this SECOND, before tranche B.
    ---------------------------------------------------------------------------------------------
    Nothing on PROD calls any of these yet, so if one is wrong the blast radius is zero. Running it
    before B gets the safe half in and shakes out any missing dependency from tranche A while
    nothing is at stake.
*/
SET NOCOUNT ON;
GO

/* ===== dbo.GetPortalCustomerIds ===== */
GO
/*
    dbo.GetPortalCustomerIds                                                        MBA-939
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
/* ===== dbo.GetOrderAttachmentCounts ===== */
GO
-- =============================================
-- Proc:        dbo.GetOrderAttachmentCounts
-- Jira:        MBA-930 ("Work file: show the order's Priority attachments, converted to PDF")
-- Description: How many Priority documents each order carries. This is what drives the file
--              button on the work assignment screen (׳©׳™׳‘׳•׳¥ ׳¢׳‘׳•׳“׳”) ג€” red when the order has
--              files, grey when it has none, matching the icon pattern from MBA-803.
--
--              Built for the GRID, not the detail view: the screen renders a page of orders at
--              once and must not issue one call per row. Pass the page's ids as a CSV; pass
--              NULL to get every order that has at least one file.
--
--              An order with no attachments is NOT returned. The caller treats "absent" as
--              zero and greys the button ג€” that keeps the payload to the orders that actually
--              have something, which on PROD is 13,237 of them.
--
--              TruncatedFiles is surfaced here so the grid can distinguish "has files" from
--              "has files, some of which cannot be opened" without a second round-trip.
--              Priority's EXTFILENAME is varchar(80) and it cuts longer names; 35 rows are
--              unreachable for that reason.
--
-- Param:       @OrderWorkPlanIds NVARCHAR(MAX) = NULL   -- CSV of OrderWorkPlanId, NULL = all
-- Returns:     OrderWorkPlanId, OrderNumber, FileCount, ServableFiles, TruncatedFiles
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetOrderAttachmentCounts]
    @OrderWorkPlanIds NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /* dbo.ParseCSVToTable is the house CSV splitter ג€” dbo.AssignCarToOrder uses it for
       @QuartersOfDay. Reused rather than introducing STRING_SPLIT beside it. */
    DECLARE @Wanted TABLE (OrderWorkPlanId INT PRIMARY KEY);

    IF @OrderWorkPlanIds IS NOT NULL AND LTRIM(RTRIM(@OrderWorkPlanIds)) <> N''
        INSERT INTO @Wanted (OrderWorkPlanId)
        SELECT DISTINCT Value FROM dbo.ParseCSVToTable(@OrderWorkPlanIds) WHERE Value IS NOT NULL;

    DECLARE @Filtered BIT = CASE WHEN EXISTS (SELECT 1 FROM @Wanted) THEN 1 ELSE 0 END;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,FileCount      = COUNT(*)
        ,ServableFiles  = SUM(CASE WHEN a.IsPathTruncated = 0 THEN 1 ELSE 0 END)
        ,TruncatedFiles = SUM(CAST(a.IsPathTruncated AS INT))
    FROM dbo.OrderWorkPlans      AS wp
    JOIN dbo.CrmOrderAttachments AS a ON a.ORD = wp.OrderSourceId
    WHERE ISNULL(wp.IsCancelled, 0) = 0
      AND (@Filtered = 0 OR wp.OrderWorkPlanId IN (SELECT OrderWorkPlanId FROM @Wanted))
    GROUP BY wp.OrderWorkPlanId, wp.OrderNumber
    ORDER BY wp.OrderWorkPlanId DESC;
END

GO
/* ===== dbo.GetOrderAttachmentsByOrder ===== */
GO
-- =============================================
-- Proc:        dbo.GetOrderAttachmentsByOrder
-- Jira:        MBA-930 ("Work file: show the order's Priority attachments, converted to PDF")
-- Description: The documents Priority hangs off an order ג€” the "׳ ׳¡׳₪׳—׳™׳" sub-form of
--              "׳׳™׳©׳•׳¨ ׳”׳–׳׳ ׳”" ג€” for one order, served from dbo.CrmOrderAttachments so the
--              request never crosses the linked server.
--
--              Returns ONE ROW PER FILE, ordered by EXTFILENUM, the file's sequence within
--              the order. Most orders carry one, but 215 carry 3, 39 carry 4, 8 carry 5 and one
--              carries 12 ג€” do NOT assume a small fixed maximum. 13,237 orders carry at least
--              one and many carry none, so an empty result is normal and is what greys out the
--              file button on the work assignment screen.
--
--              LINE is returned for reference only. It is NOT a file index: it takes 3 distinct
--              values across the source table and repeats within an order.
--
--              CanBeServed is the column the UI acts on:
--                1 -> the file is locatable and can be sent to the converter.
--                0 -> IsPathTruncated: Priority's EXTFILENAME is varchar(80) and it cut the
--                     name, so the file cannot be found. 35 rows are in this state.
--                     These MUST still be listed, as an error row. Hiding them leaves the
--                     calibrator with no way to know a document exists.
--
--              SourceKind tells the conversion layer what it is dealing with. 99.3% of order
--              attachments are .msg Outlook messages, not documents ג€” for those the converter
--              has to render the message body AND each attachment carried inside it. Only 62
--              files in the whole system are already PDF.
--
-- Param:       @OrderWorkPlanId INT           -- required
-- Returns:     OrderWorkPlanId, OrderNumber, FileNumber, Line, FileName, FilePath,
--              FileExtension, SourceKind, Description, DescriptionRaw,
--              CanBeServed, IsPathTruncated
--
--              No file size is returned. Priority's EXTFILES.FILESIZE holds the length of the
--              path string, not the file ג€” the conversion layer stats the file on disk.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetOrderAttachmentsByOrder]
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,a.EXTFILENUM                               AS FileNumber
        ,a.LINE                                     AS Line
        /* Trailing segment of the UNC path. NULL when truncated ג€” a cut path has no filename. */
        ,FileName = CASE
                        WHEN a.IsPathTruncated = 1 THEN NULL
                        WHEN CHARINDEX('\', REVERSE(a.FilePath)) = 0 THEN a.FilePath
                        ELSE RIGHT(a.FilePath, CHARINDEX('\', REVERSE(a.FilePath)) - 1)
                    END
        ,a.FilePath
        ,a.FileExtension
        ,SourceKind = CASE
                        WHEN a.IsPathTruncated = 1     THEN 'Unreachable'
                        WHEN a.FileExtension = 'msg'   THEN 'OutlookMessage'
                        WHEN a.FileExtension = 'pdf'   THEN 'Pdf'
                        WHEN a.FileExtension IN ('jpeg','jpg','tif','tiff','png','bmp','gif')
                                                       THEN 'Image'
                        WHEN a.FileExtension IN ('xls','xlsx','doc','docx','rtf','htm','html','txt')
                                                       THEN 'Document'
                        ELSE 'Other'
                      END
        ,a.Description          /* un-reversed, safe to display */
        ,a.DescriptionRaw       /* Priority's own text, kept for diagnosis */
        ,CanBeServed     = CAST(CASE WHEN a.IsPathTruncated = 1 THEN 0 ELSE 1 END AS BIT)
        ,a.IsPathTruncated
    FROM dbo.OrderWorkPlans      AS wp
    JOIN dbo.CrmOrderAttachments AS a ON a.ORD = wp.OrderSourceId
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
      AND ISNULL(wp.IsCancelled, 0) = 0
    ORDER BY a.EXTFILENUM;
END

GO
/* ===== dbo.RefreshOrderAttachmentsCache ===== */
GO
/*
    dbo.RefreshOrderAttachmentsCache                                                   MBA-930
    ---------------------------------------------------------------------------------------------
    Fills dbo.CrmOrderAttachments from Priority's EXTFILES over the linked server
    [31.168.173.93]. Mirrors dbo.RefreshCrmTextCache: full rebuild by default, incremental
    top-up for the rows a sync has just introduced.

        @IncrementalOnly = 0 : full rebuild (default).
        @IncrementalOnly = 1 : only orders that have no cached row yet.

    ONE linked-server round-trip either way. The whole TYPE='O' set is ~15,300 rows, small enough
    to pull in a single OPENQUERY and filter locally ג€” no batching needed, unlike the ORDERSTEXT
    pull in RefreshCrmTextCache which reaches into a 1.7M-row table.

    Only orders we actually hold are kept, so the cache never grows past OrderWorkPlans.

    PREREQUISITE ON PROD
    --------------------
    dbo.fnUnreverseVisualText exists on STAGE but NOT on PROD ג€” it is queued in
    database/deploy-prod/03-tranche-C-new.sql. Deploy that first or this procedure will fail on
    PROD with "cannot find the user-defined function".

    Where to call it from
    ---------------------
    stg.MergeOrdersData already ends with `EXEC dbo.RefreshCrmTextCache @IncrementalOnly = 1`
    for exactly this reason: the order sync is what creates new keys, so a cache hooked there
    cannot drift and needs no SQL Agent job (the app login is db_owner on Calibrator but has no
    server-level rights and cannot create one). Adding this call beside it is the intended home ג€”
    but stg.MergeOrdersData is a shared path, so that edit needs explicit approval and is NOT
    done here. See MBA-933.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshOrderAttachmentsCache
    @IncrementalOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* ------------------------------------------------------------------------------------
       Pull the whole order-attachment set in one round-trip.

       TYPE = 'O' is the order entity; IV is then ORDERS.ORD, which is what we carry as
       OrderWorkPlans.OrderSourceId. Counts by TYPE on PROD 30/08/2026: D 1,637,222 |
       I 240,375 | O 15,326 | C 3,101 ג€” so filtering on the remote side matters.

       Keyed on (IV, EXTFILENUM). LINE is NOT a file index: it has 3 distinct values in the whole
       table and repeats inside an order, so keying on it loses files and fails the PK. See the
       header of dbo.CrmOrderAttachments.table.sql.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Ext
    (
        ORD          INT           NOT NULL,
        EXTFILENUM   INT           NOT NULL,
        LINE         INT           NULL,
        FilePath       NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        DescriptionRaw NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL
    );
    /* COLLATE DATABASE_DEFAULT is not decoration. The values arrive from OPENQUERY carrying
       Latin1_General_100_CI_AI_SC while dbo.CrmOrderAttachments is Hebrew_CI_AS, and the
       change-detection comparisons in the MERGE below fail with a collation conflict without
       it. Pinning both temp tables to the database default settles it in one place. */

    /* FILESIZE is not selected: it holds the length of EXTFILENAME, not the file size.
       See the header of dbo.CrmOrderAttachments.table.sql. */
    INSERT INTO #Ext (ORD, EXTFILENUM, LINE, FilePath, DescriptionRaw)
    SELECT q.IV, q.EXTFILENUM, q.LINE, q.EXTFILENAME, q.EXTFILEDES
    FROM OPENQUERY([31.168.173.93],
        'SELECT IV, LINE, EXTFILENUM, EXTFILENAME, EXTFILEDES
           FROM amaba.dbo.EXTFILES
          WHERE TYPE = ''O''') AS q;

    /* Keep only orders we hold, and in incremental mode only those not cached yet. */
    CREATE TABLE #Wanted (ORD INT NOT NULL PRIMARY KEY);

    INSERT INTO #Wanted (ORD)
    SELECT DISTINCT wp.OrderSourceId
    FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderSourceId IS NOT NULL
      AND ISNULL(wp.IsCancelled, 0) = 0
      AND EXISTS (SELECT 1 FROM #Ext e WHERE e.ORD = wp.OrderSourceId)
      AND (@IncrementalOnly = 0
           OR NOT EXISTS (SELECT 1 FROM dbo.CrmOrderAttachments c WHERE c.ORD = wp.OrderSourceId));

    /* ------------------------------------------------------------------------------------
       Shape the rows.

       IsPathTruncated: the source column is varchar(80) and Priority cuts anything longer.
       35 rows sit exactly at 80 characters; their names end mid-extension (.ms, .m, .pd) and
       the file cannot be located. The normal length is 74, so >= 80 is a clean signal rather
       than a guess. That count has stayed at 35 while the total grew.

       FileExtension is taken only when the path is NOT truncated ג€” a cut name's tail is not an
       extension, and treating it as one would send the converter after a file type that does
       not exist.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Shaped
    (
        ORD             INT           NOT NULL,
        EXTFILENUM      INT           NOT NULL,
        LINE            INT           NULL,
        FilePath        NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        FileExtension   NVARCHAR(20)  COLLATE DATABASE_DEFAULT NULL,
        Description     NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        DescriptionRaw  NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        IsPathTruncated BIT           NOT NULL,
        PRIMARY KEY (ORD, EXTFILENUM)
    );

    INSERT INTO #Shaped (ORD, EXTFILENUM, LINE, FilePath, FileExtension,
                         Description, DescriptionRaw, IsPathTruncated)
    SELECT
        e.ORD,
        e.EXTFILENUM,
        e.LINE,
        RTRIM(e.FilePath),
        CASE
            WHEN LEN(RTRIM(e.FilePath)) >= 80 THEN NULL          /* truncated: tail is not an extension */
            WHEN CHARINDEX('.', REVERSE(RTRIM(e.FilePath))) = 0 THEN NULL
            ELSE LOWER(RIGHT(RTRIM(e.FilePath),
                             CHARINDEX('.', REVERSE(RTRIM(e.FilePath))) - 1))
        END,
        dbo.fnUnreverseVisualText(RTRIM(e.DescriptionRaw)),
        RTRIM(e.DescriptionRaw),
        CASE WHEN LEN(RTRIM(e.FilePath)) >= 80 THEN 1 ELSE 0 END
    FROM #Ext AS e
    JOIN #Wanted AS w ON w.ORD = e.ORD;

    BEGIN TRY
        BEGIN TRAN;

        IF @IncrementalOnly = 0
            TRUNCATE TABLE dbo.CrmOrderAttachments;

        /* MERGE rather than plain INSERT so a re-run after a partial failure is a no-op
           instead of a primary-key violation, and so an incremental run can still correct a
           description Priority has since edited. */
        MERGE dbo.CrmOrderAttachments AS dest
        USING #Shaped AS src
           ON dest.ORD = src.ORD AND dest.EXTFILENUM = src.EXTFILENUM
        WHEN MATCHED AND (
                   ISNULL(dest.FilePath, N'')       <> ISNULL(src.FilePath, N'')
                OR ISNULL(dest.FileExtension, N'')  <> ISNULL(src.FileExtension, N'')
                OR ISNULL(dest.Description, N'')    <> ISNULL(src.Description, N'')
                OR ISNULL(dest.DescriptionRaw, N'') <> ISNULL(src.DescriptionRaw, N'')
                OR dest.IsPathTruncated             <> src.IsPathTruncated
                OR ISNULL(dest.LINE, -1)            <> ISNULL(src.LINE, -1)
             )
        THEN UPDATE SET
                 dest.LINE            = src.LINE,
                 dest.FilePath        = src.FilePath,
                 dest.FileExtension   = src.FileExtension,
                 dest.Description     = src.Description,
                 dest.DescriptionRaw  = src.DescriptionRaw,
                 dest.IsPathTruncated = src.IsPathTruncated,
                 dest.FetchedAt       = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (ORD, EXTFILENUM, LINE, FilePath, FileExtension,
                     Description, DescriptionRaw, IsPathTruncated, FetchedAt)
             VALUES (src.ORD, src.EXTFILENUM, src.LINE, src.FilePath, src.FileExtension,
                     src.Description, src.DescriptionRaw, src.IsPathTruncated,
                     SYSUTCDATETIME())
        /* Only on a full rebuild: an order whose files Priority has removed must lose them
           here too. In incremental mode #Shaped holds just the new orders, so deleting on
           "not in source" would wipe the entire existing cache. */
        WHEN NOT MATCHED BY SOURCE AND @IncrementalOnly = 0
        THEN DELETE;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    /* What moved, so a caller can log it. */
    SELECT
        CachedOrders    = COUNT(DISTINCT ORD),
        CachedFiles     = COUNT(*),
        TruncatedPaths  = SUM(CAST(IsPathTruncated AS INT))
    FROM dbo.CrmOrderAttachments;
END

GO
/* ===== stg.LoadCustomerContactsFromPriority ===== */
GO

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
               NOTMAIL     = LTRIM(RTRIM(ISNULL(MBA_NOTMAIL,'''')))
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
               MarkedDoNotMail    = SUM(CASE WHEN c.CustomerId IS NOT NULL AND p.NOTMAIL = 'Y' THEN 1 ELSE 0 END)
        FROM #PB AS p
        LEFT JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST;
        RETURN;
    END

    DELETE FROM stg.stg_CustomerContacts;

    INSERT INTO stg.stg_CustomerContacts
          (CustomerContactIdFromSource, CustomerContactName, CustomerContactPersonRole,
           CustomerContactPhone, CustomerContactAdditionalPhoneNumber, CustomerContactEmail,
           CustomerId, SourceSystem, IsPrimary, DoNotMail)
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
           CAST(CASE WHEN p.NOTMAIL = 'Y' THEN 1 ELSE 0 END AS BIT)
    FROM #PB AS p
    JOIN dbo.Customers AS c ON c.CustomerIdFromSource = p.CUST
    JOIN dbo.Source    AS s ON s.SourceId = c.SourceId
    WHERE NULLIF(p.NAME, '') IS NOT NULL;

    SELECT Staged      = COUNT(*),
           Customers   = COUNT(DISTINCT CustomerId),
           Primary_    = SUM(CAST(IsPrimary AS INT)),
           DoNotMail_  = SUM(CAST(DoNotMail AS INT))
    FROM stg.stg_CustomerContacts;
END

GO