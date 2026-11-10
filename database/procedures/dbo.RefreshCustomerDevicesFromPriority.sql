/*
    dbo.RefreshCustomerDevicesFromPriority                                              MBA-996
    ---------------------------------------------------------------------------------------------
    Keeps dbo.CustomerDevices in step with Priority's device register (amaba.dbo.SERNUMBERS, with
    MBA_SERNUMBERS, MNFCTR and PART for model, manufacturer, interval, description and device
    type). READ-ONLY against Priority. Design: DBA/schema-updates.md section 2, point 3.

    Why it exists: the portal had no device entity. Its "device" was a group of order lines, and
    the order lines are a lossy copy - the order view looks back 16.7 days and about 5,200
    calibrations never arrived - so devices are taken from the register itself, not from orders.

        @Apply       = 0 : dry run (default). Fetches, compares, reports. Writes nothing.
        @Apply       = 1 : writes.
        @FullRefresh = 0 : incremental (default): the devices Priority changed since the newest
                           SourceUpdatedAt we hold, minus @OverlapMinutes. With nothing held yet it
                           runs as a full refresh.
        @FullRefresh = 1 : the whole register. Nightly, because MBA_SERNUMBERS (model,
                           manufacturer, interval, description) has no UDATE: an edit there does
                           not move SERNUMBERS.UDATE and never shows in an incremental run.

    WHAT IS LOADED
    --------------
    New rows: live devices (CANCELDATE = 0) of active customers we hold (dbo.Customers with
    IsInactiveInSource = 0). Rows already held are kept up to date whatever happens upstream - a
    device cancelled later gets IsInactiveInSource = 1. Nothing is ever deleted.
    Measured on Priority 2026-11-10: 662,117 devices, 633,462 not cancelled, 592,157 of those of
    active customers; the full remote query takes 9.3 s on Priority and returns about 50 MB.
    About 950 devices change a day.

    WHICH CUSTOMER
    --------------
    dbo.Customers holds 747 Priority customers twice (STAGE 2026-11-10: 11,286 rows, 10,539
    distinct CustomerIdFromSource); the second row is a different company carrying the same
    CustomerIdFromSource. In all 747 exactly one row's CustomerCode equals Priority's CUSTNAME, so
    a device goes to: CustomerIdFromSource = CUST, preferring CustomerCode = CUSTNAME; a CUST with
    one row and no code match still maps to that row; anything else is reported, not guessed.

    THE VALUES
    ----------
    SERNUM, MODEL: as stored (5,475 and 5,452 of 5,617 STAGE order lines carry them unchanged).
    MNFDES, SERNDES, PARTDES: through Priority's tabula_hebconvert, which turns its visual-order
    text into logical order the way the order sync does ("KERN & SOHN"; our fnUnreverseVisualText
    gives "SOHN & KERN"). tabula_hebconvert throws on NULL, and a device with no MBA_SERNUMBERS row
    is NULL after the LEFT JOIN, so every call is wrapped in ISNULL(..., '').
    PART is the device's own part. It is NOT the order line's OrdersProductTypeId, which is a
    calibration service (0 of 5,617 coincide), so this procedure never writes OrdersProductTypeId.

    CLAIMING A DEVICE TYPED IN THE PORTAL
    -------------------------------------
    A typed row (SERN IS NULL, IsDeleted = 0) is matched against the Priority devices of its own
    customer that we do not hold yet. Priority's SERNUM is "<CUSTNAME>-<serial>", and the serial
    can be compound ("2025-MPL-244(70135180)").
      1. exact: the typed serial (SerialKey) equals the SERNUM, or the SERNUM without its
         "<CUSTNAME>-" prefix (trimmed, upper case);
      2. otherwise by component (session1 decision 2): the typed serial, reduced by
         dbo.fnSerialAlnum, equals one component of a compound SERNUM - split on brackets,
         slash, comma, semicolon, pipe and whitespace, never on '-', components of 3+ characters.
    Exactly one Priority device, matched by exactly one typed row: the typed row gets its SERN and
    Priority's values; its id, site and contact stay. Anything else: the Priority device is added
    as its own row and the typed row gets NeedsReview = 1 with the reason. Never guessed.

    A DEVICE THAT MOVED TO ANOTHER CUSTOMER
    ---------------------------------------
    Priority's CUST wins. Site and contact belong to the old customer (the foreign keys enforce
    it), so they are cleared and the row gets NeedsReview = 1. A move to a customer we do not hold
    is reported and not applied.

    WRITING
    -------
    dbo.trCustomerDevices_PriorityOwned refuses Priority-owned changes from anyone but this
    procedure, recognised by the session key CustomerDevices.Writer = 'PriorityRefresh', set just
    before the writes and cleared right after, on error too. Writes go in chunks of @ChunkSize rows,
    each its own transaction under an application lock, so the first full load does not hold one
    600k-row transaction; every chunk is idempotent, so an interrupted run is finished by the next.

    Linked server: [31.168.173.93], as every Priority reader here. OPENQUERY with the whole remote
    statement inside (session1 decision 19); the INSERT sits inside the dynamic SQL, writing to a
    temp table this procedure created, so this never becomes INSERT ... EXEC across a linked server.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.RefreshCustomerDevicesFromPriority
    @Apply          BIT = 0,
    @FullRefresh    BIT = 0,
    @OverlapMinutes INT = 60,
    @ChunkSize      INT = 50000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ChunkSize NOT BETWEEN 1 AND 200000
        THROW 51000, '@ChunkSize must be between 1 and 200,000.', 1;
    IF @OverlapMinutes NOT BETWEEN 0 AND 10080
        THROW 51000, '@OverlapMinutes must be between 0 and 10,080 (a week).', 1;

    DECLARE @Epoch DATETIME2(0) = '1988-01-01';   /* Priority stores dates as minutes since this */
    DECLARE @Started DATETIME2(3) = SYSUTCDATETIME();

    /* ------------------------------------------------------------------------------------
       1. Fetch.
       ------------------------------------------------------------------------------------ */
    DECLARE @Watermark INT =
        (SELECT DATEDIFF(MINUTE, @Epoch, MAX(SourceUpdatedAt)) - @OverlapMinutes
         FROM dbo.CustomerDevices WHERE SERN IS NOT NULL);

    DECLARE @Mode VARCHAR(12) =
        CASE WHEN @FullRefresh = 1 OR @Watermark IS NULL THEN 'full' ELSE 'incremental' END;

    CREATE TABLE #Src
    (
        SERN       INT           NOT NULL PRIMARY KEY,
        SERNUM     NVARCHAR(30)  COLLATE DATABASE_DEFAULT NOT NULL,
        CUST       INT           NOT NULL,
        CUSTNAME   NVARCHAR(16)  COLLATE DATABASE_DEFAULT NULL,
        PART       INT           NOT NULL,
        CANCELDATE INT           NOT NULL,
        UDATE      INT           NOT NULL,
        MODEL      NVARCHAR(30)  COLLATE DATABASE_DEFAULT NULL,
        CALIBMONTH INT           NULL,
        MNFDES     NVARCHAR(32)  COLLATE DATABASE_DEFAULT NULL,
        SERNDES    NVARCHAR(48)  COLLATE DATABASE_DEFAULT NULL,
        PARTDES    NVARCHAR(59)  COLLATE DATABASE_DEFAULT NULL
    );
    /* COLLATE DATABASE_DEFAULT: OPENQUERY values arrive in the linked server's collation and are
       compared below with columns of this database. CAST to NVARCHAR happens on the Priority side,
       before any collation change: VARCHAR Hebrew pushed through a Latin collation turns into '?'. */

    /* The remote SELECT, written with single quotes; doubled once below for OPENQUERY. */
    DECLARE @Remote NVARCHAR(4000) =
          N'SELECT s.SERN, CAST(s.SERNUM AS NVARCHAR(30)) AS SERNUM, s.CUST, '
        + N'CAST(c.CUSTNAME AS NVARCHAR(16)) AS CUSTNAME, s.PART, s.CANCELDATE, s.UDATE, '
        + N'CAST(m.MODEL AS NVARCHAR(30)) AS MODEL, m.CALIBMONTH, '
        + N'system.dbo.tabula_hebconvert(ISNULL(f.MNFDES, '''')) AS MNFDES, '
        + N'system.dbo.tabula_hebconvert(ISNULL(m.SERNDES, '''')) AS SERNDES, '
        + N'system.dbo.tabula_hebconvert(ISNULL(p.PARTDES, '''')) AS PARTDES '
        + N'FROM amaba.dbo.SERNUMBERS AS s '
        + N'LEFT JOIN amaba.dbo.CUSTOMERS AS c ON c.CUST = s.CUST '
        + N'LEFT JOIN amaba.dbo.MBA_SERNUMBERS AS m ON m.SERN = s.SERN '
        + N'LEFT JOIN amaba.dbo.MNFCTR AS f ON f.MNF = m.MNF AND m.MNF > 0 '
        + N'LEFT JOIN amaba.dbo.PART AS p ON p.PART = s.PART AND s.PART > 0 '
        + N'WHERE s.SERN > 0'
        + CASE WHEN @Mode = 'incremental'
               THEN N' AND s.UDATE >= ' + CAST(@Watermark AS NVARCHAR(12)) ELSE N'' END;

    DECLARE @Sql NVARCHAR(MAX) =
          N'INSERT INTO #Src (SERN, SERNUM, CUST, CUSTNAME, PART, CANCELDATE, UDATE, MODEL, CALIBMONTH, MNFDES, SERNDES, PARTDES) '
        + N'SELECT SERN, SERNUM, CUST, CUSTNAME, PART, CANCELDATE, UDATE, MODEL, CALIBMONTH, MNFDES, SERNDES, PARTDES '
        + N'FROM OPENQUERY([31.168.173.93], ''' + REPLACE(@Remote, N'''', N'''''') + N''')';
    EXEC sys.sp_executesql @Sql;

    DECLARE @FetchMs INT = DATEDIFF(MILLISECOND, @Started, SYSUTCDATETIME());

    /* ------------------------------------------------------------------------------------
       2. Which customer. See the header: prefer CustomerCode = CUSTNAME.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Cust
    (
        CUST       INT NOT NULL PRIMARY KEY,
        CustomerId INT NULL,
        IsActive   BIT NULL,
        CustomerCode NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL
    );

    INSERT INTO #Cust (CUST, CustomerId, IsActive, CustomerCode)
    SELECT k.CUST, pick.CustomerId, pick.IsActive, pick.CustomerCode
    FROM (SELECT DISTINCT CUST, CUSTNAME FROM #Src) AS k
    OUTER APPLY (
        SELECT TOP (1) c.CustomerId,
               CAST(CASE WHEN c.IsInactiveInSource = 0 AND c.IsDeleted = 0 THEN 1 ELSE 0 END AS BIT) AS IsActive,
               c.CustomerCode
        FROM dbo.Customers AS c
        WHERE c.CustomerIdFromSource = k.CUST
          AND (   c.CustomerCode = k.CUSTNAME
               OR (SELECT COUNT(*) FROM dbo.Customers AS c2 WHERE c2.CustomerIdFromSource = k.CUST) = 1)
        ORDER BY CASE WHEN c.CustomerCode = k.CUSTNAME THEN 0 ELSE 1 END, c.CustomerId
    ) AS pick;

    /* ------------------------------------------------------------------------------------
       3. Shape: our column values, one row per SERN.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Shaped
    (
        SERN                      INT           NOT NULL PRIMARY KEY,
        CustomerId                INT           NULL,
        CustomerIsActive          BIT           NULL,
        CustomerCode              NVARCHAR(50)  COLLATE DATABASE_DEFAULT NULL,
        SerialNumber              NVARCHAR(50)  COLLATE DATABASE_DEFAULT NULL,
        SerialBody                NVARCHAR(50)  COLLATE DATABASE_DEFAULT NULL,   /* SERNUM without "<CUSTNAME>-" */
        Model                     NVARCHAR(150) COLLATE DATABASE_DEFAULT NULL,
        OrdersDeviceManufacturer  NVARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
        DevicePart                INT           NULL,
        DeviceTypeName            NVARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
        DeviceDescription         NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
        CalibrationIntervalMonths TINYINT       NULL,
        IsInactiveInSource        BIT           NOT NULL,
        SourceUpdatedAt           DATETIME2(0)  NULL
    );

    INSERT INTO #Shaped
    SELECT s.SERN, k.CustomerId, k.IsActive, k.CustomerCode,
           NULLIF(LTRIM(RTRIM(s.SERNUM)), N''),
           NULLIF(LTRIM(RTRIM(CASE WHEN s.CUSTNAME <> N'' AND LEFT(s.SERNUM, LEN(s.CUSTNAME) + 1) = s.CUSTNAME + N'-'
                                   THEN SUBSTRING(s.SERNUM, LEN(s.CUSTNAME) + 2, 50)
                                   ELSE s.SERNUM END)), N''),
           NULLIF(LTRIM(RTRIM(s.MODEL)), N''),
           NULLIF(LTRIM(RTRIM(s.MNFDES)), N''),
           NULLIF(s.PART, 0),
           NULLIF(LTRIM(RTRIM(s.PARTDES)), N''),
           NULLIF(LTRIM(RTRIM(s.SERNDES)), N''),
           CASE WHEN s.CALIBMONTH BETWEEN 1 AND 255 THEN s.CALIBMONTH END,
           CASE WHEN s.CANCELDATE > 0 THEN 1 ELSE 0 END,
           CASE WHEN s.UDATE > 0 THEN DATEADD(MINUTE, s.UDATE, @Epoch) END
    FROM #Src AS s
    JOIN #Cust AS k ON k.CUST = s.CUST;

    /* ------------------------------------------------------------------------------------
       4. Classify.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Plan
    (
        SERN             INT           NOT NULL PRIMARY KEY,
        CustomerDeviceID INT           NULL,     /* held row, or the typed row being claimed */
        Action_          VARCHAR(12)   NOT NULL, /* insert | update | claim | move | skip-... */
        Reason           NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL
    );

    /* 4a. Held rows that differ. Text compared in a binary collation so a change of case shows. */
    INSERT INTO #Plan (SERN, CustomerDeviceID, Action_, Reason)
    SELECT s.SERN, d.CustomerDeviceID,
           CASE WHEN s.CustomerId IS NULL THEN 'skip-move'
                WHEN s.CustomerId <> d.CustomerId THEN 'move'
                ELSE 'update' END,
           CASE WHEN s.CustomerId IS NULL THEN N'Priority customer not held here; customer kept'
                WHEN s.CustomerId <> d.CustomerId THEN N'moved to another customer in Priority' END
    FROM #Shaped AS s
    JOIN dbo.CustomerDevices AS d ON d.SERN = s.SERN
    WHERE EXISTS (SELECT ISNULL(s.CustomerId, d.CustomerId),
                         s.SerialNumber COLLATE Latin1_General_100_BIN2, s.Model COLLATE Latin1_General_100_BIN2,
                         s.OrdersDeviceManufacturer COLLATE Latin1_General_100_BIN2, s.DevicePart,
                         s.DeviceTypeName COLLATE Latin1_General_100_BIN2, s.DeviceDescription COLLATE Latin1_General_100_BIN2,
                         s.CalibrationIntervalMonths, s.IsInactiveInSource, s.SourceUpdatedAt
                  EXCEPT
                  SELECT d.CustomerId,
                         d.SerialNumber COLLATE Latin1_General_100_BIN2, d.Model COLLATE Latin1_General_100_BIN2,
                         d.OrdersDeviceManufacturer COLLATE Latin1_General_100_BIN2, d.DevicePart,
                         d.DeviceTypeName COLLATE Latin1_General_100_BIN2, d.DeviceDescription COLLATE Latin1_General_100_BIN2,
                         d.CalibrationIntervalMonths, d.IsInactiveInSource, d.SourceUpdatedAt);

    /* 4b. Devices we do not hold that may be loaded: live, of an active customer we hold. */
    CREATE TABLE #New (SERN INT NOT NULL PRIMARY KEY, CustomerId INT NOT NULL);

    INSERT INTO #New (SERN, CustomerId)
    SELECT s.SERN, s.CustomerId
    FROM #Shaped AS s
    WHERE s.CustomerId IS NOT NULL AND s.CustomerIsActive = 1 AND s.IsInactiveInSource = 0
      AND NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WHERE d.SERN = s.SERN);

    /* 4c. Claims: typed rows of those customers, matched exactly first, then by component. */
    CREATE TABLE #Typed (CustomerDeviceID INT NOT NULL PRIMARY KEY, CustomerId INT NOT NULL,
                         SerialKey NVARCHAR(50) COLLATE DATABASE_DEFAULT NULL, Alnum NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL);

    INSERT INTO #Typed (CustomerDeviceID, CustomerId, SerialKey, Alnum)
    SELECT d.CustomerDeviceID, d.CustomerId, d.SerialKey, dbo.fnSerialAlnum(d.SerialKey)
    FROM dbo.CustomerDevices AS d
    WHERE d.SERN IS NULL AND d.IsDeleted = 0 AND d.SerialKey IS NOT NULL
      AND EXISTS (SELECT 1 FROM #New AS n WHERE n.CustomerId = d.CustomerId);

    CREATE TABLE #Match (CustomerDeviceID INT NOT NULL, SERN INT NOT NULL, Tier TINYINT NOT NULL,
                         PRIMARY KEY (CustomerDeviceID, SERN));

    IF EXISTS (SELECT 1 FROM #Typed)
    BEGIN
        /* tier 1: whole serial, with or without the customer prefix */
        INSERT INTO #Match (CustomerDeviceID, SERN, Tier)
        SELECT t.CustomerDeviceID, s.SERN, 1
        FROM #Typed AS t
        JOIN #New AS n ON n.CustomerId = t.CustomerId
        JOIN #Shaped AS s ON s.SERN = n.SERN
        WHERE t.SerialKey = UPPER(s.SerialNumber) OR t.SerialKey = UPPER(s.SerialBody);

        /* tier 2: one component of a compound serial, for typed rows tier 1 did not place */
        ;WITH comp AS (
            SELECT s.SERN, n.CustomerId, dbo.fnSerialAlnum(x.value) AS Part
            FROM #New AS n
            JOIN #Shaped AS s ON s.SERN = n.SERN
            CROSS APPLY STRING_SPLIT(TRANSLATE(s.SerialBody, N'()[]{}/\,;|' + NCHAR(9), REPLICATE(N' ', 12)), N' ') AS x
            WHERE n.CustomerId IN (SELECT CustomerId FROM #Typed)
        ), usable AS (
            SELECT c.SERN, c.CustomerId, c.Part
            FROM comp AS c
            WHERE LEN(c.Part) >= 3
              AND (SELECT COUNT(DISTINCT c2.Part) FROM comp AS c2
                   WHERE c2.SERN = c.SERN AND LEN(c2.Part) >= 3) > 1   /* only a real compound adds anything */
        )
        INSERT INTO #Match (CustomerDeviceID, SERN, Tier)
        SELECT DISTINCT t.CustomerDeviceID, u.SERN, 2
        FROM #Typed AS t
        JOIN usable AS u ON u.CustomerId = t.CustomerId AND u.Part = t.Alnum
        WHERE NOT EXISTS (SELECT 1 FROM #Match AS m WHERE m.CustomerDeviceID = t.CustomerDeviceID);

        /* Accept only one-to-one pairs. */
        INSERT INTO #Plan (SERN, CustomerDeviceID, Action_, Reason)
        SELECT m.SERN, m.CustomerDeviceID, 'claim',
               CASE m.Tier WHEN 1 THEN N'exact serial' ELSE N'serial component' END
        FROM #Match AS m
        WHERE (SELECT COUNT(*) FROM #Match AS a WHERE a.CustomerDeviceID = m.CustomerDeviceID) = 1
          AND (SELECT COUNT(*) FROM #Match AS b WHERE b.SERN = m.SERN) = 1;
    END

    /* Everything else new is inserted. */
    INSERT INTO #Plan (SERN, CustomerDeviceID, Action_, Reason)
    SELECT n.SERN, NULL, 'insert', NULL
    FROM #New AS n
    WHERE NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.SERN = n.SERN);

    /* Typed rows that matched, but not one-to-one: flagged, never guessed. */
    CREATE TABLE #Review (CustomerDeviceID INT NOT NULL PRIMARY KEY, Reason NVARCHAR(200) COLLATE DATABASE_DEFAULT NOT NULL);

    INSERT INTO #Review (CustomerDeviceID, Reason)
    SELECT m.CustomerDeviceID,
           LEFT(N'matches several Priority devices or shares one with another typed device: SERN '
                + STRING_AGG(CAST(m.SERN AS NVARCHAR(MAX)), N', ') WITHIN GROUP (ORDER BY m.SERN), 200)
    FROM #Match AS m
    WHERE NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.CustomerDeviceID = m.CustomerDeviceID AND p.Action_ = 'claim')
    GROUP BY m.CustomerDeviceID;

    /* ------------------------------------------------------------------------------------
       5. Report.
       ------------------------------------------------------------------------------------ */
    SELECT
        Mode                   = @Mode,
        Applied                = @Apply,
        FetchSeconds           = CAST(@FetchMs / 1000.0 AS DECIMAL(9,1)),
        DevicesFetched         = (SELECT COUNT(*) FROM #Src),
        CustomerNotHeld        = (SELECT COUNT(*) FROM #Src AS s JOIN #Cust AS k ON k.CUST = s.CUST WHERE k.CustomerId IS NULL),
        CustomerInactive       = (SELECT COUNT(*) FROM #Shaped WHERE CustomerIsActive = 0
                                    AND SERN NOT IN (SELECT SERN FROM dbo.CustomerDevices WHERE SERN IS NOT NULL)),
        CancelledNotLoaded     = (SELECT COUNT(*) FROM #Shaped AS s WHERE s.IsInactiveInSource = 1 AND s.CustomerIsActive = 1
                                    AND NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WHERE d.SERN = s.SERN)),
        ToInsert               = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'insert'),
        ToUpdate               = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'update'),
        ToClaim                = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'claim'),
        ToMove                 = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'move'),
        MoveNotApplied         = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'skip-move'),
        TypedNeedingReview     = (SELECT COUNT(*) FROM #Review),
        CancelledNow           = (SELECT COUNT(*) FROM #Plan AS p JOIN #Shaped AS s ON s.SERN = p.SERN
                                  JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = p.CustomerDeviceID
                                  WHERE s.IsInactiveInSource = 1 AND d.IsInactiveInSource = 0 AND d.SERN IS NOT NULL);

    IF @Apply = 0
    BEGIN
        SELECT TOP (20) p.Action_, p.SERN, p.CustomerDeviceID, s.CustomerId, s.SerialNumber, s.Model,
               s.OrdersDeviceManufacturer, s.DeviceTypeName, p.Reason
        FROM #Plan AS p JOIN #Shaped AS s ON s.SERN = p.SERN
        ORDER BY CASE p.Action_ WHEN 'claim' THEN 0 WHEN 'move' THEN 1 WHEN 'update' THEN 2 ELSE 3 END, p.SERN DESC;
        RETURN;
    END

    /* ------------------------------------------------------------------------------------
       6. Write, in chunks. Each chunk: its own transaction, the lock, the writer flag.
       ------------------------------------------------------------------------------------ */
    CREATE TABLE #Chunk (SERN INT NOT NULL PRIMARY KEY);
    DECLARE @rc INT, @Inserted INT = 0, @Updated INT = 0, @Claimed INT = 0, @Moved INT = 0, @Flagged INT = 0;

    /* Claims, moves, updates and the review flags first: few rows, one transaction. */
    BEGIN TRY
        BEGIN TRAN;
        EXEC @rc = sys.sp_getapplock @Resource = N'RefreshCustomerDevicesFromPriority', @LockMode = 'Exclusive',
                                     @LockOwner = 'Transaction', @LockTimeout = 600000;
        IF @rc < 0
            THROW 51000, 'Could not get the RefreshCustomerDevicesFromPriority lock: another run is still writing.', 1;

        EXEC sys.sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';

        UPDATE d SET
            d.SERN                      = s.SERN,
            d.SerialNumber              = s.SerialNumber,
            d.Model                     = s.Model,
            d.OrdersDeviceManufacturer  = s.OrdersDeviceManufacturer,
            d.DevicePart                = s.DevicePart,
            d.DeviceTypeName            = s.DeviceTypeName,
            d.DeviceDescription         = s.DeviceDescription,
            d.CalibrationIntervalMonths = s.CalibrationIntervalMonths,
            d.IsInactiveInSource        = s.IsInactiveInSource,
            d.SourceUpdatedAt           = s.SourceUpdatedAt,
            d.RefreshedAt               = SYSUTCDATETIME(),
            d.NeedsReview               = 0,
            d.NeedsReviewReason         = NULL,
            d.UpdatedDate               = GETDATE()
        FROM dbo.CustomerDevices AS d
        JOIN #Plan AS p ON p.CustomerDeviceID = d.CustomerDeviceID AND p.Action_ = 'claim'
        JOIN #Shaped AS s ON s.SERN = p.SERN
        WHERE d.SERN IS NULL;                    /* still typed: nobody claimed it since the plan */
        SET @Claimed = @@ROWCOUNT;

        UPDATE d SET
            d.CustomerId                = CASE WHEN p.Action_ = 'move' THEN s.CustomerId ELSE d.CustomerId END,
            d.CustomerSiteId            = CASE WHEN p.Action_ = 'move' THEN NULL ELSE d.CustomerSiteId END,
            d.CustomerContactId         = CASE WHEN p.Action_ = 'move' THEN NULL ELSE d.CustomerContactId END,
            d.NeedsReview               = CASE WHEN p.Action_ = 'move' THEN 1 ELSE d.NeedsReview END,
            d.NeedsReviewReason         = CASE WHEN p.Action_ = 'move' THEN p.Reason ELSE d.NeedsReviewReason END,
            d.SerialNumber              = s.SerialNumber,
            d.Model                     = s.Model,
            d.OrdersDeviceManufacturer  = s.OrdersDeviceManufacturer,
            d.DevicePart                = s.DevicePart,
            d.DeviceTypeName            = s.DeviceTypeName,
            d.DeviceDescription         = s.DeviceDescription,
            d.CalibrationIntervalMonths = s.CalibrationIntervalMonths,
            d.IsInactiveInSource        = s.IsInactiveInSource,
            d.SourceUpdatedAt           = s.SourceUpdatedAt,
            d.RefreshedAt               = SYSUTCDATETIME(),
            d.UpdatedDate               = GETDATE()
        FROM dbo.CustomerDevices AS d
        JOIN #Plan AS p ON p.CustomerDeviceID = d.CustomerDeviceID AND p.Action_ IN ('update', 'move', 'skip-move')
        JOIN #Shaped AS s ON s.SERN = p.SERN;
        SET @Updated = @@ROWCOUNT;
        SET @Moved = (SELECT COUNT(*) FROM #Plan WHERE Action_ = 'move');

        UPDATE d SET d.NeedsReview = 1, d.NeedsReviewReason = r.Reason, d.UpdatedDate = GETDATE()
        FROM dbo.CustomerDevices AS d
        JOIN #Review AS r ON r.CustomerDeviceID = d.CustomerDeviceID
        WHERE d.NeedsReview = 0 OR ISNULL(d.NeedsReviewReason, N'') <> r.Reason;
        SET @Flagged = @@ROWCOUNT;

        EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;
        THROW;
    END CATCH

    /* Inserts in chunks: the first full load is about 590k rows. */
    WHILE 1 = 1
    BEGIN
        DELETE FROM #Chunk;
        INSERT INTO #Chunk (SERN)
        SELECT TOP (@ChunkSize) p.SERN FROM #Plan AS p WHERE p.Action_ = 'insert' ORDER BY p.SERN;
        IF @@ROWCOUNT = 0 BREAK;

        BEGIN TRY
            BEGIN TRAN;
            EXEC @rc = sys.sp_getapplock @Resource = N'RefreshCustomerDevicesFromPriority', @LockMode = 'Exclusive',
                                         @LockOwner = 'Transaction', @LockTimeout = 600000;
            IF @rc < 0
                THROW 51000, 'Could not get the RefreshCustomerDevicesFromPriority lock: another run is still writing.', 1;

            EXEC sys.sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';

            INSERT INTO dbo.CustomerDevices
                (CustomerId, SERN, SerialNumber, Model, OrdersDeviceManufacturer, DevicePart, DeviceTypeName,
                 DeviceDescription, CalibrationIntervalMonths, IsInactiveInSource, SourceUpdatedAt, RefreshedAt)
            SELECT s.CustomerId, s.SERN, s.SerialNumber, s.Model, s.OrdersDeviceManufacturer, s.DevicePart,
                   s.DeviceTypeName, s.DeviceDescription, s.CalibrationIntervalMonths, s.IsInactiveInSource,
                   s.SourceUpdatedAt, SYSUTCDATETIME()
            FROM #Chunk AS c
            JOIN #Shaped AS s ON s.SERN = c.SERN
            WHERE NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WITH (UPDLOCK, HOLDLOCK) WHERE d.SERN = c.SERN);
            SET @Inserted += @@ROWCOUNT;

            EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            EXEC sys.sp_set_session_context N'CustomerDevices.Writer', NULL;
            THROW;
        END CATCH

        DELETE p FROM #Plan AS p JOIN #Chunk AS c ON c.SERN = p.SERN;
    END

    SELECT Inserted = @Inserted, Updated = @Updated, Claimed = @Claimed, Moved = @Moved, FlaggedForReview = @Flagged,
           Seconds = CAST(DATEDIFF(MILLISECOND, @Started, SYSUTCDATETIME()) / 1000.0 AS DECIMAL(9,1)),
           HeldRegistered = (SELECT COUNT(*) FROM dbo.CustomerDevices WHERE SERN IS NOT NULL),
           HeldTyped      = (SELECT COUNT(*) FROM dbo.CustomerDevices WHERE SERN IS NULL);
END
GO

/*
    First run, on each server
    -------------------------
        EXEC dbo.RefreshCustomerDevicesFromPriority;                  -- dry run: read the counts
        EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1;       -- first run loads the register
        EXEC dbo.RefreshCustomerDevicesFromPriority @FullRefresh = 1; -- must now report 0 everywhere

    Then from the SQL Agent jobs in database/jobs/Setup-SqlAgentJobs.sql:
        hourly   EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1;
        nightly  EXEC dbo.RefreshCustomerDevicesFromPriority @Apply = 1, @FullRefresh = 1;
*/
