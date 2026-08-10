-- =============================================
-- Proc:        dbo.RefreshCrmTextCache
-- Jira:        MBA-806 — performance: local cache of CRM device/catalog text
--              MBA-666 — adds the Priority part description + device family to the same cache
-- Description: (Re)populates the local cache tables from Priority via linked server
--              [31.168.173.93], pre-reconstructing the reversed multi-line HTML into one
--              row per key. Intended to run on a schedule (SQL Agent, e.g. nightly).
--              Only rows relevant to Calibrator (order PARTs / item SERNs) are cached.
--              ORDERSTEXT (~89.6M rows) is NOT cached here — too large for a naive pull;
--              dbo.GetOrderInstructionsByOrder reads it live per-order (see MBA-806, prefer SSIS).
--
-- Cache tables:
--   dbo.CrmCatalogText(PART, CatalogText)   <- amaba.dbo.PARTTEXT        (טקסט למק"ט)
--   dbo.CrmDeviceText (SERN, DeviceText)    <- amaba.dbo.SERNUMBERSTEXT  (טקסט למכשיר)
--   dbo.CrmPartInfo   (PART, PartDescription, FamilyId, FamilyDescription)
--                                           <- amaba.dbo.PART + amaba.dbo.FAMILY
--
-- Note on amaba table names (cost us time once — do not repeat): the Priority catalog table is
-- [PART] (singular). There is no [PARTS] table; asking for it returns "linked server does not
-- contain the table", which reads like a permissions error but is not. PART, FAMILY, SERNUMBERS,
-- PARTTEXT, SERNUMBERSTEXT and ORDERSTEXT are all readable by app_stage over the linked server.
--
-- Note on PART.PARTDES: Hebrew reads correctly but embedded numbers are in visual order
-- ("מאזניים עד 001 ק'ג" = 100 ק"ג, "000,1" = 1,000). It is cached verbatim - do NOT REVERSE() it,
-- that would break the Hebrew. dbo.OrdersProductTypes.OrdersProductTypeName holds the same
-- description with the digits already correct and is the better choice for display.
-- =============================================
-- Scheduling: there is NO SQL Agent job for this (the app login is db_owner on Calibrator but has
-- no server-level rights, so it cannot create one). Instead stg.MergeOrdersData calls this with
-- @IncrementalOnly = 1 at the end of every order sync, which is the process that introduces new
-- PARTs/SERNs in the first place — so the cache cannot drift and needs no scheduler.
--   @IncrementalOnly = 0 : full rebuild (TRUNCATE + reload). Run manually after schema changes.
--   @IncrementalOnly = 1 : top up ONLY keys missing from the cache, and touch the linked server
--                          only if there is something missing (the normal case costs 3 local
--                          EXISTS checks and no remote traffic at all).
CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
    @IncrementalOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.CrmCatalogText') IS NULL
        CREATE TABLE dbo.CrmCatalogText(PART INT PRIMARY KEY, CatalogText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmDeviceText') IS NULL
        CREATE TABLE dbo.CrmDeviceText(SERN INT PRIMARY KEY, DeviceText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmPartInfo') IS NULL
        CREATE TABLE dbo.CrmPartInfo(
             PART              INT PRIMARY KEY
            ,PartDescription   NVARCHAR(200) NULL   -- amaba.dbo.PART.PARTDES  (תיאור מכשיר)
            ,FamilyId          INT           NULL   -- amaba.dbo.PART.FAMILY
            ,FamilyDescription NVARCHAR(200) NULL   -- amaba.dbo.FAMILY.FAMILYDES (e.g. מאזניים, מד לחץ)
            ,RefreshedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

    -- Keys the cache is expected to hold. In incremental mode, only the ones it is missing.
    CREATE TABLE #WantedPart(PART INT PRIMARY KEY);
    CREATE TABLE #WantedSern(SERN INT PRIMARY KEY);
    CREATE TABLE #WantedInfo(PART INT PRIMARY KEY);

    INSERT INTO #WantedPart(PART)
    SELECT DISTINCT od.PART FROM dbo.OrderDetails AS od
    WHERE od.PART IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText c WHERE c.PART = od.PART));

    INSERT INTO #WantedSern(SERN)
    SELECT DISTINCT itm.SERN FROM dbo.OrderDetailsItems AS itm
    WHERE itm.SERN IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = itm.SERN));

    INSERT INTO #WantedInfo(PART)
    SELECT DISTINCT od.PART FROM dbo.OrderDetails AS od
    WHERE od.PART IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PART = od.PART));

    IF @IncrementalOnly = 0
    BEGIN
        TRUNCATE TABLE dbo.CrmCatalogText;
        TRUNCATE TABLE dbo.CrmDeviceText;
        TRUNCATE TABLE dbo.CrmPartInfo;
    END

    -- Each block is guarded so that "nothing new" costs no linked-server traffic at all.
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

    -- MBA-666: part description + device family, for the Calibration Wizard's "Calibration Item".
    IF EXISTS (SELECT 1 FROM #WantedInfo)
        INSERT INTO dbo.CrmPartInfo(PART, PartDescription, FamilyId, FamilyDescription)
        SELECT p.PART,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), p.PARTDES))),
               p.FAMILY,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), f.FAMILYDES)))
        FROM [31.168.173.93].amaba.dbo.PART AS p
        LEFT JOIN [31.168.173.93].amaba.dbo.FAMILY AS f ON f.FAMILY = p.FAMILY
        WHERE p.PART IN (SELECT PART FROM #WantedInfo);

    /* Negative caching — do not remove.
       Most keys have no CRM text at all (only 305 of ~558 order PARTs have PARTTEXT rows, and
       ~500 of ~2,100 SERNs have SERNUMBERSTEXT rows). Without a row to say "checked, nothing
       there", absence is indistinguishable from "not cached yet", so every incremental run
       re-queried those keys over the linked server: measured 96-120s per run instead of
       instant. A row with NULL text means CHECKED-AND-EMPTY. Downstream SPs LEFT JOIN these
       tables and return NULL either way, so this is invisible to callers. */
    INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
    SELECT w.PART, NULL FROM #WantedPart AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText c WHERE c.PART = w.PART);

    INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
    SELECT w.SERN, NULL FROM #WantedSern AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = w.SERN);

    INSERT INTO dbo.CrmPartInfo(PART, PartDescription, FamilyId, FamilyDescription)
    SELECT w.PART, NULL, NULL, NULL FROM #WantedInfo AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PART = w.PART);
END
GO
