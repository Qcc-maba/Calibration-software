-- =============================================
-- Proc:        dbo.RefreshCrmTextCache
-- Jira:        MBA-806 (device/catalog text) · MBA-666 (part description + family) · MBA-792 (order instructions)
-- Description: Local cache of the Priority CRM text, filled over the existing linked server
--              [31.168.173.93]. Everything the screens need is served from these tables, so no
--              request ever pays for a linked-server round-trip.
--
--   dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
--                                        <- amaba.dbo.PART + amaba.dbo.FAMILY
--   dbo.CrmCatalogText(PART, CatalogText)      <- amaba.dbo.PARTTEXT        (טקסט למק"ט)
--   dbo.CrmDeviceText(SERN, DeviceText)        <- amaba.dbo.SERNUMBERSTEXT  (טקסט למכשיר)
--   dbo.CrmOrderInstructions(ORD, OrderInstructionsZ, InstructionsText)
--                                              <- amaba.dbo.ORDERSTEXT      (הנחיות לביצוע)
--
-- ── 1. KEYED BY CATALOG NUMBER, NOT BY OrderDetails.PART ────────────────────────────────────
-- OrderDetails.PART cannot be trusted. Measured 2026-08-13: of 4,257 order lines that join to
-- Priority on that numeric key, 169 land on a DIFFERENT product than the line's own catalog
-- number says — e.g. a line named '110219-7' (רגש טמפרטורה) carrying PART 8, which in Priority is
-- '120301-0' מתקן שקילה. OrdersProductTypeName agrees with PartName in those rows, so PartName is
-- the authoritative field and PART is the corrupted one.
-- amaba.dbo.PART.PARTNAME is unique (7,927 of 7,927 rows), so the catalog number is a safe key.
-- CrmPartInfo is therefore keyed on PartName, and callers resolve
--        OrderDetails.PartName -> CrmPartInfo.PART -> CrmCatalogText.PART
-- instead of joining OrderDetails.PART directly.
--
-- ── 2. ORDERSTEXT HIDES TWO TEXTS BEHIND THE SIGN OF ORD ───────────────────────────────────
--    ORD = +OrderSourceId -> the printed order DOCUMENT. 24-111 KB of Word HTML, and mostly
--                            boilerplate: 622 of 1,025 STAGE orders share a byte-identical
--                            87,069-char body. NOT the instructions.
--    ORD = -OrderSourceId -> the short free-text NOTE = הנחיות לביצוע, 165-2,404 chars,
--                            e.g. "כיול מבוצע ע"י לרית / לרית צריכים להגיע עם 1000 ק"ג".
-- Reading only the positive side is what made this look like the wrong source for months.
--
-- ── 3. amaba TABLE NAMES ───────────────────────────────────────────────────────────────────
-- The catalog table is [PART], SINGULAR. There is no [PARTS]; asking for it returns "linked
-- server does not contain the table", which reads like a permission error and is not one.
-- PART, FAMILY, SERNUMBERS, PARTTEXT, SERNUMBERSTEXT and ORDERSTEXT are all readable.
--
-- ── 4. PART.PARTDES STORES HEBREW IN VISUAL ORDER ──────────────────────────────────────────
-- Digits come out mirrored ("מאזניים עד 001 ק'ג" = 100). Cached verbatim; do NOT REVERSE() it,
-- that fixes the digits and breaks the Hebrew. dbo.OrdersProductTypes.OrdersProductTypeName holds
-- the same description with correct digits and is the better display source.
--
-- Scheduling: there is no SQL Agent job (the app login is db_owner but has no server-level
-- rights). stg.MergeOrdersData calls this with @IncrementalOnly = 1 at the end of every order
-- sync — the process that introduces new keys in the first place — so the cache cannot drift.
--   @IncrementalOnly = 0 : full rebuild.  1 : top up only what is missing.
-- =============================================

-- ── migrations, each in its own batch (column names of an EXISTING table resolve at compile
--    time, so the procedure below cannot even be created against an older shape) ─────────────
IF OBJECT_ID('dbo.CrmOrderInstructions') IS NOT NULL
   AND COL_LENGTH('dbo.CrmOrderInstructions', 'OrderInstructionsZ') IS NULL
    DROP TABLE dbo.CrmOrderInstructions;
GO
IF OBJECT_ID('dbo.CrmOrderInstructions') IS NOT NULL
   AND COL_LENGTH('dbo.CrmOrderInstructions', 'InstructionsText') IS NULL
    ALTER TABLE dbo.CrmOrderInstructions ADD InstructionsText NVARCHAR(MAX) NULL;
GO
-- CrmPartInfo was keyed on PART; it is now keyed on PartName (see note 1). It is a cache, so the
-- old shape is dropped and refilled rather than migrated.
IF OBJECT_ID('dbo.CrmPartInfo') IS NOT NULL
   AND COL_LENGTH('dbo.CrmPartInfo', 'PartName') IS NULL
    DROP TABLE dbo.CrmPartInfo;
GO

CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
    @IncrementalOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.CrmCatalogText') IS NULL
        CREATE TABLE dbo.CrmCatalogText(PART INT PRIMARY KEY, CatalogText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmDeviceText') IS NULL
        CREATE TABLE dbo.CrmDeviceText(SERN INT PRIMARY KEY, DeviceText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmOrderInstructions') IS NULL
        CREATE TABLE dbo.CrmOrderInstructions(
             ORD                INT PRIMARY KEY      -- = OrderWorkPlans.OrderSourceId (positive)
            ,OrderInstructionsZ VARBINARY(MAX) NULL  -- COMPRESS(HTML). 18.2:1 on real data.
            ,InstructionsText   NVARCHAR(MAX)  NULL  -- tags stripped, for table cells
            ,RefreshedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmPartInfo') IS NULL
        CREATE TABLE dbo.CrmPartInfo(
             PartName          NVARCHAR(30) NOT NULL PRIMARY KEY  -- = OrderDetails.PartName = PART.PARTNAME
            ,PART              INT           NULL                 -- the real Priority key
            ,PartDescription   NVARCHAR(200) NULL                 -- PART.PARTDES (תיאור מכשיר)
            ,FamilyId          INT           NULL                 -- PART.FAMILY
            ,FamilyDescription NVARCHAR(200) NULL                 -- FAMILY.FAMILYDES
            ,RefreshedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

    -- ── what the cache is expected to hold; in incremental mode only what it is missing ──────
    -- COLLATE DATABASE_DEFAULT is required: a temp table inherits tempdb's collation
-- (Latin1_General_100_CI_AI_SC here) while the user database is Hebrew_CI_AS, so every
-- comparison against a local column fails with a collation conflict.
    CREATE TABLE #WantedName(PartName NVARCHAR(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
    INSERT INTO #WantedName(PartName)
    SELECT DISTINCT LTRIM(RTRIM(od.PartName)) FROM dbo.OrderDetails AS od
    WHERE od.PartName IS NOT NULL AND LTRIM(RTRIM(od.PartName)) <> N''
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = LTRIM(RTRIM(od.PartName))));

    CREATE TABLE #WantedSern(SERN INT PRIMARY KEY);
    INSERT INTO #WantedSern(SERN)
    SELECT DISTINCT itm.SERN FROM dbo.OrderDetailsItems AS itm
    WHERE itm.SERN IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = itm.SERN));

    CREATE TABLE #WantedOrd(ORD INT PRIMARY KEY);
    INSERT INTO #WantedOrd(ORD)
    SELECT DISTINCT wp.OrderSourceId FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderSourceId IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = wp.OrderSourceId));

    IF @IncrementalOnly = 0
    BEGIN
        TRUNCATE TABLE dbo.CrmCatalogText;
        TRUNCATE TABLE dbo.CrmDeviceText;
        TRUNCATE TABLE dbo.CrmPartInfo;
        TRUNCATE TABLE dbo.CrmOrderInstructions;
    END

    -- ── part description + family, resolved by CATALOG NUMBER ────────────────────────────────
    IF EXISTS (SELECT 1 FROM #WantedName)
        INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
        SELECT w.PartName,
               p.PART,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), p.PARTDES))),
               p.FAMILY,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), f.FAMILYDES)))
        FROM #WantedName AS w
        -- both sides collated explicitly: the remote PARTNAME comes back as
        -- Latin1_General_100_CI_AI_SC and the local column is Hebrew_CI_AS, which cannot be
        -- compared without this.
        JOIN [31.168.173.93].amaba.dbo.PART AS p
             ON LTRIM(RTRIM(p.PARTNAME)) COLLATE Hebrew_BIN = w.PartName COLLATE Hebrew_BIN
        LEFT JOIN [31.168.173.93].amaba.dbo.FAMILY AS f ON f.FAMILY = p.FAMILY;

    -- ── catalog text, for the PARTs we just resolved ─────────────────────────────────────────
    CREATE TABLE #WantedPart(PART INT PRIMARY KEY);
    INSERT INTO #WantedPart(PART)
    SELECT DISTINCT c.PART FROM dbo.CrmPartInfo c
    WHERE c.PART IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText t WHERE t.PART = c.PART));

    IF EXISTS (SELECT 1 FROM #WantedPart)
        INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
        SELECT pt.PART,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N'') WITHIN GROUP (ORDER BY pt.TEXTLINE, pt.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.PARTTEXT AS pt
        WHERE pt.PART IN (SELECT PART FROM #WantedPart)
        GROUP BY pt.PART;

    IF EXISTS (SELECT 1 FROM #WantedSern)
        INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
        SELECT st.SERN,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), st.[TEXT])), N'') WITHIN GROUP (ORDER BY st.TEXTLINE, st.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.SERNUMBERSTEXT AS st
        WHERE st.SERN IN (SELECT SERN FROM #WantedSern)
        GROUP BY st.SERN;

    /* ORDERSTEXT is ~89.6M rows, so it is fetched in BATCHES over the orders Calibrator knows.
       Measured: one order alone ~0.7s, but 20 in a single remote query ~1.9s together — roughly
       7x cheaper per order. NOTE THE MINUS SIGN; the cache key stays the positive OrderSourceId. */
    IF EXISTS (SELECT 1 FROM #WantedOrd)
    BEGIN
        CREATE TABLE #OrdQueue(ORD INT PRIMARY KEY);       -- drain a copy; #WantedOrd is needed below
        INSERT INTO #OrdQueue(ORD) SELECT ORD FROM #WantedOrd;

        DECLARE @OrdBatch TABLE(ORD INT PRIMARY KEY);
        WHILE EXISTS (SELECT 1 FROM #OrdQueue)
        BEGIN
            DELETE FROM @OrdBatch;
            INSERT INTO @OrdBatch(ORD) SELECT TOP (20) ORD FROM #OrdQueue ORDER BY ORD;

            INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
            SELECT -ot.ORD,
                   COMPRESS(STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), ot.[TEXT])), N'') WITHIN GROUP (ORDER BY ot.TEXTLINE, ot.TEXTORD))
            FROM [31.168.173.93].amaba.dbo.ORDERSTEXT AS ot
            WHERE ot.ORD IN (SELECT -ORD FROM @OrdBatch)
            GROUP BY ot.ORD;

            DELETE q FROM #OrdQueue AS q WHERE q.ORD IN (SELECT ORD FROM @OrdBatch);
        END
    END

    /* Plain-text rendering for table cells. Outside the block above on purpose: that block only
       runs when there are new ORDs, so keeping this inside meant text added later never filled. */
    UPDATE ci SET ci.InstructionsText =
           dbo.fnStripHtml(CAST(DECOMPRESS(ci.OrderInstructionsZ) AS NVARCHAR(MAX)))
    FROM dbo.CrmOrderInstructions AS ci
    WHERE ci.OrderInstructionsZ IS NOT NULL AND ci.InstructionsText IS NULL;

    /* Negative caching — do not remove.
       Most keys have no CRM text at all, and without a row saying "checked, nothing there",
       absence is indistinguishable from "not cached yet": every incremental run re-queried them
       over the linked server, measured at 96.7s per no-op run versus 0.09s now. A row with NULL
       content means CHECKED-AND-EMPTY. Callers LEFT JOIN these tables and see NULL either way. */
    INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
    SELECT w.PartName, NULL, NULL, NULL, NULL FROM #WantedName AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = w.PartName);

    INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
    SELECT w.PART, NULL FROM #WantedPart AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText c WHERE c.PART = w.PART);

    INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
    SELECT w.SERN, NULL FROM #WantedSern AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = w.SERN);

    INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
    SELECT w.ORD, NULL FROM #WantedOrd AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = w.ORD);
END
GO
