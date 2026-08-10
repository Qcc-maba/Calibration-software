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
CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
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

    TRUNCATE TABLE dbo.CrmCatalogText;
    INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
    SELECT pt.PART,
           STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N'') WITHIN GROUP (ORDER BY pt.TEXTLINE, pt.TEXTORD)
    FROM [31.168.173.93].amaba.dbo.PARTTEXT AS pt
    WHERE pt.PART IN (SELECT DISTINCT PART FROM dbo.OrderDetails WHERE PART IS NOT NULL)
    GROUP BY pt.PART;

    TRUNCATE TABLE dbo.CrmDeviceText;
    INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
    SELECT st.SERN,
           STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), st.[TEXT])), N'') WITHIN GROUP (ORDER BY st.TEXTLINE, st.TEXTORD)
    FROM [31.168.173.93].amaba.dbo.SERNUMBERSTEXT AS st
    WHERE st.SERN IN (SELECT DISTINCT SERN FROM dbo.OrderDetailsItems WHERE SERN IS NOT NULL)
    GROUP BY st.SERN;

    -- MBA-666: part description + device family, for the Calibration Wizard's "Calibration Item".
    TRUNCATE TABLE dbo.CrmPartInfo;
    INSERT INTO dbo.CrmPartInfo(PART, PartDescription, FamilyId, FamilyDescription)
    SELECT p.PART,
           LTRIM(RTRIM(CONVERT(NVARCHAR(200), p.PARTDES))),
           p.FAMILY,
           LTRIM(RTRIM(CONVERT(NVARCHAR(200), f.FAMILYDES)))
    FROM [31.168.173.93].amaba.dbo.PART AS p
    LEFT JOIN [31.168.173.93].amaba.dbo.FAMILY AS f ON f.FAMILY = p.FAMILY
    WHERE p.PART IN (SELECT DISTINCT PART FROM dbo.OrderDetails WHERE PART IS NOT NULL);
END
GO
