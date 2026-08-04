-- =============================================
-- Proc:        dbo.RefreshCrmTextCache
-- Jira:        MBA-806 — performance: local cache of CRM device/catalog text
-- Description: (Re)populates the local cache tables from Priority via linked server
--              [31.168.173.93], pre-reconstructing the reversed multi-line HTML into one
--              row per key. Intended to run on a schedule (SQL Agent, e.g. nightly).
--              Only rows relevant to Calibrator (order PARTs / item SERNs) are cached.
--              ORDERSTEXT (~89.6M rows) is NOT cached here — too large for a naive pull;
--              dbo.GetOrderInstructionsByOrder reads it live per-order (see MBA-806, prefer SSIS).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.CrmCatalogText') IS NULL
        CREATE TABLE dbo.CrmCatalogText(PART INT PRIMARY KEY, CatalogText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmDeviceText') IS NULL
        CREATE TABLE dbo.CrmDeviceText(SERN INT PRIMARY KEY, DeviceText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

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
END
GO
