/*
    dbo.RefreshOrderAttachmentsCache                                                   MBA-930
    ---------------------------------------------------------------------------------------------
    Fills dbo.CrmOrderAttachments from Priority's EXTFILES over the linked server
    [31.168.173.93]. Mirrors dbo.RefreshCrmTextCache: full rebuild by default, incremental
    top-up for the rows a sync has just introduced.

        @IncrementalOnly = 0 : full rebuild (default).
        @IncrementalOnly = 1 : only orders that have no cached row yet.

    ONE linked-server round-trip either way. The whole TYPE='O' set is ~15,300 rows, small enough
    to pull in a single OPENQUERY and filter locally — no batching needed, unlike the ORDERSTEXT
    pull in RefreshCrmTextCache which reaches into a 1.7M-row table.

    Only orders we actually hold are kept, so the cache never grows past OrderWorkPlans.

    PREREQUISITE ON PROD
    --------------------
    dbo.fnUnreverseVisualText exists on STAGE but NOT on PROD — it is queued in
    database/deploy-prod/03-tranche-C-new.sql. Deploy that first or this procedure will fail on
    PROD with "cannot find the user-defined function".

    Where to call it from
    ---------------------
    stg.MergeOrdersData already ends with `EXEC dbo.RefreshCrmTextCache @IncrementalOnly = 1`
    for exactly this reason: the order sync is what creates new keys, so a cache hooked there
    cannot drift and needs no SQL Agent job (the app login is db_owner on Calibrator but has no
    server-level rights and cannot create one). Adding this call beside it is the intended home —
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
       I 240,375 | O 15,326 | C 3,101 — so filtering on the remote side matters.

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

       FileExtension is taken only when the path is NOT truncated — a cut name's tail is not an
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

/*
    Verify after the first run
    --------------------------
        EXEC dbo.RefreshOrderAttachmentsCache;          -- full rebuild

    Expected on PROD as of 30/08/2026, before filtering to the orders we hold:
        13,237 orders · 15,326 files · 35 truncated paths. Priority is live, so the first two
        drift upward; 35 has been stable.
    After filtering to OrderWorkPlans the counts will be lower — that is correct, the cache
    only covers orders the system actually knows about.

        SELECT TOP 20 ORD, EXTFILENUM, FileExtension, IsPathTruncated, Description
        FROM dbo.CrmOrderAttachments ORDER BY ORD DESC, EXTFILENUM;

        SELECT FileExtension, COUNT(*) AS Files
        FROM dbo.CrmOrderAttachments GROUP BY FileExtension ORDER BY Files DESC;

    The extension breakdown should be overwhelmingly .msg. If .pdf leads instead, the TYPE
    filter has slipped and the cache is holding the wrong entity.
*/
