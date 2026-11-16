/*
    dbo.RefreshPriorityCalibrationStatus                                               MBA-911
    ---------------------------------------------------------------------------------------------
    Mirrors Priority's calibration status log (amaba.dbo.MBA_CALIBSTATSLOG) into
    dbo.PriorityCalibrationStatusLog for every calibration document (Doc) this system holds, and
    refreshes the Hebrew text of dbo.PriorityCalibrationStatusCodes. READ-ONLY against Priority.

    Why it exists: every work plan on PROD sits at "waiting for calibration" (3,144 of 3,144 on
    2026-10-07) because nothing ever carries Priority's progress into this database. The order
    sync brings a "current status" into stg_Orders.CurrentCalibrationStatus, but stg.MergeOrdersData
    drops it (the joins are commented out), and the view it comes from orders steps by CDATE,
    which picks the wrong "latest" step for 5.3% of documents. See the table headers.

    Until the Calibrator app rolls out (February 2027) every device is calibrated in MABA 2000, so
    this log - not the app - is the real progress of each device: received, calibration opened,
    report generated, signatures, packed, sent.

        @Apply       = 0 : dry run (default). Fetches, compares, reports. Writes nothing.
        @Apply       = 1 : writes.
        @FullRefresh = 0 : incremental (default). Fetches (a) every log row Priority loaded since
                           the newest one we hold, minus an hour of overlap, and (b) the whole log
                           of any Doc we hold but have never fetched (new orders).
        @FullRefresh = 1 : refetches the whole log of every Doc we hold.

    HOW IT TALKS TO PRIORITY
    ------------------------
    OPENQUERY over the existing linked server [31.168.173.93], so filtering and joins run on the
    Priority side. The Doc list is pushed into the remote query as an IN list of integers taken
    from our own table, in batches of @BatchSize (OPENQUERY text is limited to 8,000 characters:
    500 Docs is about 4,400). The INSERT sits INSIDE the dynamic SQL, writing to a temp table the
    caller created, so this never becomes INSERT ... EXEC across a linked server.

    Volume, measured 2026-11-09: 8,291 Docs held (PROD copy of 2026-10-21); Priority loads about
    3,400 log rows a day in total. A full refresh is 17 round-trips; a normal incremental run is
    one round-trip plus one per 500 new Docs.

    Never deletes. A row we hold that Priority no longer has is reported by a full refresh, not
    removed: Priority owns this data (session1 decision 17).
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the client that deploys it (sqlcmd defaults
    QUOTED_IDENTIFIER to OFF). Same convention as dbo.CalibrationReportFile.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.RefreshPriorityCalibrationStatus
    @Apply       BIT = 0,
    @FullRefresh BIT = 0,
    @BatchSize   INT = 500
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @BatchSize NOT BETWEEN 1 AND 800
        THROW 51000, '@BatchSize must be between 1 and 800 (OPENQUERY text is limited to 8,000 characters).', 1;

    DECLARE @Epoch DATETIME2(0) = '1988-01-01';   /* Priority stores dates as minutes since this */

    /* ------------------------------------------------------------------------------------
       1. The code list. 23 rows; row 0 is Priority's empty placeholder.
       tabula_hebconvert turns Priority's visual-order text into logical order: it un-mirrors
       the parentheses (the DC text arrives as "... )customer reason(") and un-reverses Latin
       ("FDP" -> "PDF"). English only in this comment: sqlcmd without -f 65001 corrupts Hebrew,
       and a corrupted comment makes the stored definitions differ between servers.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Codes
    (
        PriorityStatusId INT           NOT NULL PRIMARY KEY,
        StatusCode       CHAR(2)       COLLATE DATABASE_DEFAULT NOT NULL,
        DescriptionHEB   NVARCHAR(100) COLLATE DATABASE_DEFAULT NULL
    );
    /* COLLATE DATABASE_DEFAULT: values arrive from OPENQUERY as Latin1_General_100_CI_AI_SC and
       are compared below with columns of this database. Without it the comparisons fail. */

    INSERT INTO #Codes (PriorityStatusId, StatusCode, DescriptionHEB)
    SELECT q.CALIBSTATUSES, q.STATCODE, q.STATDES
    FROM OPENQUERY([31.168.173.93],
        'SELECT CALIBSTATUSES, STATCODE, system.dbo.tabula_hebconvert(STATDES) AS STATDES
           FROM amaba.dbo.MBA_CALIBSTATUSES
          WHERE STATCODE <> ''''') AS q;

    /* ------------------------------------------------------------------------------------
       2. The Docs we hold.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Wanted (Doc INT NOT NULL PRIMARY KEY);

    INSERT INTO #Wanted (Doc)
    SELECT DISTINCT i.Doc
    FROM dbo.OrderDetailsItems AS i
    WHERE i.Doc IS NOT NULL AND i.IsDeleted = 0;

    DECLARE @MinDoc INT = (SELECT MIN(Doc) FROM #Wanted),
            @MaxDoc INT = (SELECT MAX(Doc) FROM #Wanted);

    CREATE TABLE #Src
    (
        Doc                INT           NOT NULL,
        Kline              INT           NOT NULL,
        StatusCode         CHAR(2)       COLLATE DATABASE_DEFAULT NOT NULL,
        CDATE              INT           NULL,
        UDATE              INT           NULL,
        StatusByUserName   NVARCHAR(40)  COLLATE DATABASE_DEFAULT NULL,
        UpdateReportNumber NVARCHAR(16)  COLLATE DATABASE_DEFAULT NULL
    );

    /* The remote SELECT, without its WHERE. No string literals inside, so the only quoting
       below is the one level OPENQUERY needs. */
    DECLARE @RemoteSelect NVARCHAR(1000) = N'SELECT l.DOC, l.KLINE, s.STATCODE, l.CDATE, l.UDATE, '
        + N'system.dbo.tabula_hebconvert(l.CALIB_USERNAME) AS CALIB_USERNAME, l.MBA_UPDTRPORTNUM '
        + N'FROM amaba.dbo.MBA_CALIBSTATSLOG AS l '
        + N'JOIN amaba.dbo.MBA_CALIBSTATUSES AS s ON s.CALIBSTATUSES = l.CALIBSTATUSES ';

    DECLARE @Sql NVARCHAR(MAX), @Where NVARCHAR(MAX), @RoundTrips INT = 0;

    /* ------------------------------------------------------------------------------------
       3a. Incremental: everything Priority loaded since our newest row, minus an hour of
       overlap (rows loaded in the same minute as the watermark, clock skew). Bounded by our
       Doc range so Priority filters it; rows of Docs we do not hold are dropped in step 4.
       ------------------------------------------------------------------------------------ */
    DECLARE @Watermark INT =
        (SELECT DATEDIFF(MINUTE, @Epoch, MAX(LoadedAt)) - 60 FROM dbo.PriorityCalibrationStatusLog);

    IF @FullRefresh = 0 AND @Watermark IS NOT NULL AND @MinDoc IS NOT NULL
    BEGIN
        SET @Where = N'WHERE l.UDATE >= ' + CAST(@Watermark AS NVARCHAR(12))
                   + N' AND l.DOC BETWEEN ' + CAST(@MinDoc AS NVARCHAR(12))
                   + N' AND ' + CAST(@MaxDoc AS NVARCHAR(12));
        SET @Sql = N'INSERT INTO #Src (Doc, Kline, StatusCode, CDATE, UDATE, StatusByUserName, UpdateReportNumber) '
                 + N'SELECT DOC, KLINE, STATCODE, CDATE, UDATE, CALIB_USERNAME, MBA_UPDTRPORTNUM '
                 + N'FROM OPENQUERY([31.168.173.93], ''' + REPLACE(@RemoteSelect + @Where, N'''', N'''''') + N''')';
        EXEC sys.sp_executesql @Sql;
        SET @RoundTrips += 1;
    END

    /* ------------------------------------------------------------------------------------
       3b. Whole log, per Doc, in batches: every Doc on a full refresh, otherwise the Docs we
       hold but have never fetched.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Queue (Doc INT NOT NULL PRIMARY KEY);

    INSERT INTO #Queue (Doc)
    SELECT w.Doc
    FROM #Wanted AS w
    WHERE @FullRefresh = 1
       OR NOT EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusFetch AS f WHERE f.Doc = w.Doc);
    /* "Never fetched" comes from the fetch marker, not from "has no log rows": a Doc whose Priority
       log is still empty would otherwise be refetched whole on every run, forever. Once marked, a
       Doc's later steps arrive through the incremental pull in 3a, which covers our whole Doc range. */

    CREATE TABLE #FetchedWhole (Doc INT NOT NULL PRIMARY KEY);
    INSERT INTO #FetchedWhole (Doc) SELECT Doc FROM #Queue;

    DECLARE @QueuedDocs INT = (SELECT COUNT(*) FROM #Queue);
    DECLARE @Batch TABLE (Doc INT NOT NULL PRIMARY KEY);
    DECLARE @List NVARCHAR(MAX);

    WHILE EXISTS (SELECT 1 FROM #Queue)
    BEGIN
        DELETE FROM @Batch;
        INSERT INTO @Batch (Doc) SELECT TOP (@BatchSize) Doc FROM #Queue ORDER BY Doc;

        /* Integers from our own table: nothing here can carry a quote. */
        SELECT @List = STRING_AGG(CAST(Doc AS NVARCHAR(MAX)), N',') WITHIN GROUP (ORDER BY Doc)
        FROM @Batch;

        SET @Where = N'WHERE l.DOC IN (' + @List + N')';
        SET @Sql = N'INSERT INTO #Src (Doc, Kline, StatusCode, CDATE, UDATE, StatusByUserName, UpdateReportNumber) '
                 + N'SELECT DOC, KLINE, STATCODE, CDATE, UDATE, CALIB_USERNAME, MBA_UPDTRPORTNUM '
                 + N'FROM OPENQUERY([31.168.173.93], ''' + REPLACE(@RemoteSelect + @Where, N'''', N'''''') + N''')';
        EXEC sys.sp_executesql @Sql;
        SET @RoundTrips += 1;

        DELETE q FROM #Queue AS q JOIN @Batch AS b ON b.Doc = q.Doc;
    END

    /* ------------------------------------------------------------------------------------
       4. Shape: only Docs we hold, one row per (Doc, Kline) - 3a and 3b can both return a row.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Shaped
    (
        Doc                INT           NOT NULL,
        Kline              INT           NOT NULL,
        StatusCode         CHAR(2)       COLLATE DATABASE_DEFAULT NOT NULL,
        StatusDate         DATETIME2(0)  NULL,
        LoadedAt           DATETIME2(0)  NULL,
        StatusByUserName   NVARCHAR(40)  COLLATE DATABASE_DEFAULT NULL,
        UpdateReportNumber NVARCHAR(16)  COLLATE DATABASE_DEFAULT NULL,
        PRIMARY KEY (Doc, Kline)
    );

    INSERT INTO #Shaped (Doc, Kline, StatusCode, StatusDate, LoadedAt, StatusByUserName, UpdateReportNumber)
    SELECT d.Doc, d.Kline, d.StatusCode,
           CASE WHEN d.CDATE > 0 THEN DATEADD(MINUTE, d.CDATE, @Epoch) END,
           CASE WHEN d.UDATE > 0 THEN DATEADD(MINUTE, d.UDATE, @Epoch) END,
           NULLIF(LTRIM(RTRIM(d.StatusByUserName)), N''),
           NULLIF(LTRIM(RTRIM(d.UpdateReportNumber)), N'')
    FROM (SELECT s.*, ROW_NUMBER() OVER (PARTITION BY s.Doc, s.Kline ORDER BY s.UDATE DESC) AS rn
          FROM #Src AS s
          JOIN #Wanted AS w ON w.Doc = s.Doc) AS d
    WHERE d.rn = 1;

    /* ------------------------------------------------------------------------------------
       5. What would change.
       ------------------------------------------------------------------------------------ */
    SELECT s.*,
           CASE WHEN g.Doc IS NULL THEN 'insert' ELSE 'update' END AS Action_
    INTO #Diff
    FROM #Shaped AS s
    LEFT JOIN dbo.PriorityCalibrationStatusLog AS g ON g.Doc = s.Doc AND g.Kline = s.Kline
    WHERE g.Doc IS NULL
       OR g.StatusCode <> s.StatusCode
       OR ISNULL(g.StatusDate, '1900-01-01')       <> ISNULL(s.StatusDate, '1900-01-01')
       OR ISNULL(g.LoadedAt, '1900-01-01')         <> ISNULL(s.LoadedAt, '1900-01-01')
       OR ISNULL(g.StatusByUserName, N'')          <> ISNULL(s.StatusByUserName, N'')
       OR ISNULL(g.UpdateReportNumber, N'')        <> ISNULL(s.UpdateReportNumber, N'');

    /* Codes: Hebrew text and Priority id for the codes we know; any code Priority has that the
       seed does not is added as 'Unknown' so it shows up instead of vanishing. */
    SELECT c.PriorityStatusId, c.StatusCode, c.DescriptionHEB,
           CASE WHEN k.StatusCode IS NULL THEN 'insert' ELSE 'update' END AS Action_
    INTO #CodeDiff
    FROM #Codes AS c
    LEFT JOIN dbo.PriorityCalibrationStatusCodes AS k ON k.StatusCode = c.StatusCode
    WHERE k.StatusCode IS NULL
       OR ISNULL(k.PriorityStatusId, -1)  <> c.PriorityStatusId
       OR ISNULL(k.DescriptionHEB, N'')   <> ISNULL(c.DescriptionHEB, N'');

    SELECT
        Mode               = CASE WHEN @FullRefresh = 1 THEN 'full' ELSE 'incremental' END,
        Applied            = @Apply,
        DocsHeld           = (SELECT COUNT(*) FROM #Wanted),
        DocsQueuedForWhole = @QueuedDocs,
        RoundTrips         = @RoundTrips,
        RowsFetched        = (SELECT COUNT(*) FROM #Src),
        RowsForOurDocs     = (SELECT COUNT(*) FROM #Shaped),
        RowsToInsert       = (SELECT COUNT(*) FROM #Diff WHERE Action_ = 'insert'),
        RowsToUpdate       = (SELECT COUNT(*) FROM #Diff WHERE Action_ = 'update'),
        CodesToWrite       = (SELECT COUNT(*) FROM #CodeDiff),
        DocsWithNoLogYet   = (SELECT COUNT(*) FROM #Wanted AS w
                              WHERE NOT EXISTS (SELECT 1 FROM #Shaped s WHERE s.Doc = w.Doc)
                                AND NOT EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusLog g WHERE g.Doc = w.Doc)),
        /* Codes the seed has not described. Non-zero after a deploy means the seed was skipped:
           dbo.RecordPriorityStatusEvent then refuses to open such calibrations (it fails closed),
           but the screens show '(not in seed)'. Run Seed-PriorityCalibrationStatusCodes.sql. */
        UnseededCodes      = (SELECT COUNT(*) FROM dbo.PriorityCalibrationStatusCodes WHERE WrittenBy = 'Unknown')
                           + (SELECT COUNT(*) FROM #CodeDiff WHERE Action_ = 'insert'),
        /* Only meaningful on a full refresh, which refetches every Doc's whole log. */
        RowsGoneUpstream   = CASE WHEN @FullRefresh = 1 THEN
                                 (SELECT COUNT(*) FROM dbo.PriorityCalibrationStatusLog AS g
                                  JOIN #Wanted AS w ON w.Doc = g.Doc
                                  WHERE NOT EXISTS (SELECT 1 FROM #Shaped s
                                                    WHERE s.Doc = g.Doc AND s.Kline = g.Kline))
                             END;

    IF @Apply = 0
    BEGIN
        SELECT TOP (20) Doc, Kline, StatusCode, StatusDate, StatusByUserName, Action_
        FROM #Diff ORDER BY Doc DESC, Kline;
        RETURN;
    END

    /* ------------------------------------------------------------------------------------
       6. Write.
       ------------------------------------------------------------------------------------ */
    BEGIN TRY
        BEGIN TRAN;

        /* Two runs at once - a manual full refresh still going when the hourly job starts - would
           both see a step as new and both insert it, and one would fail on the primary key. The
           application lock makes the writes take turns; HOLDLOCK makes each MERGE's
           "not matched" decision hold until it has inserted. */
        DECLARE @rc INT;
        EXEC @rc = sys.sp_getapplock @Resource = N'RefreshPriorityCalibrationStatus', @LockMode = 'Exclusive',
                                     @LockOwner = 'Transaction', @LockTimeout = 600000;
        IF @rc < 0
            THROW 51000, 'Could not get the RefreshPriorityCalibrationStatus lock: another run is still writing.', 1;

        MERGE dbo.PriorityCalibrationStatusCodes WITH (HOLDLOCK) AS dest
        USING #CodeDiff AS src ON dest.StatusCode = src.StatusCode
        WHEN MATCHED THEN UPDATE SET
             dest.PriorityStatusId = src.PriorityStatusId,
             dest.DescriptionHEB   = src.DescriptionHEB,
             dest.UpdatedAt        = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
             INSERT (StatusCode, PriorityStatusId, DescriptionHEB, DescriptionENG, WrittenBy, Stage, SortOrder)
             VALUES (src.StatusCode, src.PriorityStatusId, src.DescriptionHEB,
                     N'(not in seed) ' + src.StatusCode, 'Unknown', 'Unknown', 255);

        MERGE dbo.PriorityCalibrationStatusLog WITH (HOLDLOCK) AS dest
        USING #Diff AS src ON dest.Doc = src.Doc AND dest.Kline = src.Kline
        WHEN MATCHED THEN UPDATE SET
             dest.StatusCode         = src.StatusCode,
             dest.StatusDate         = src.StatusDate,
             dest.LoadedAt           = src.LoadedAt,
             dest.StatusByUserName   = src.StatusByUserName,
             dest.UpdateReportNumber = src.UpdateReportNumber,
             dest.FetchedAt          = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET THEN
             INSERT (Doc, Kline, StatusCode, StatusDate, LoadedAt, StatusByUserName, UpdateReportNumber)
             VALUES (src.Doc, src.Kline, src.StatusCode, src.StatusDate, src.LoadedAt,
                     src.StatusByUserName, src.UpdateReportNumber);

        /* Mark every Doc whose whole log was just fetched, including those that came back empty. */
        MERGE dbo.PriorityCalibrationStatusFetch WITH (HOLDLOCK) AS dest
        USING #FetchedWhole AS src ON dest.Doc = src.Doc
        WHEN MATCHED THEN UPDATE SET dest.LastWholeFetchAt = SYSUTCDATETIME()
        WHEN NOT MATCHED BY TARGET THEN INSERT (Doc) VALUES (src.Doc);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT LoggedDocs = COUNT(DISTINCT Doc), LoggedRows = COUNT(*), NewestLoadedAt = MAX(LoadedAt)
    FROM dbo.PriorityCalibrationStatusLog;
END
GO

/*
    Running it
    ----------
    Hourly, from the SQL Agent job in database/jobs/Setup-SqlAgentJobs.sql:
        EXEC dbo.RefreshPriorityCalibrationStatus @Apply = 1;
    The job's first scheduled run does the backfill by itself, so nothing is required by hand.

    On a PROD deploy, do the first run by hand anyway, before creating the job. The job only reports
    that it succeeded; the second dry run is the proof that the backfill is complete:
        EXEC dbo.RefreshPriorityCalibrationStatus;                       -- dry run: read the counts
        EXEC dbo.RefreshPriorityCalibrationStatus @Apply = 1;            -- first run fetches every Doc
        EXEC dbo.RefreshPriorityCalibrationStatus;                       -- must now report 0 / 0

    Sanity check - the distribution of current status should look like the lab, not like
    "everything waiting": mostly H2 / TX for older Docs, AA / AC / GR for recent ones.
        SELECT StatusCode, COUNT(*) FROM dbo.vwOrderDetailsItemsPriorityStatus
        GROUP BY StatusCode ORDER BY 2 DESC;
*/
