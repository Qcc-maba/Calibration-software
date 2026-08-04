-- =============================================
-- Proc:        dbo.GetDeviceTextsByOrder
-- Jira:        MBA-806 ("Add description to the device")
-- Description: Returns the two CRM free-text blocks for each device (OrderDetailsItem)
--              of an order, pulled from Priority (amaba) via the existing linked server
--              [31.168.173.93]:
--                * CatalogText (טקסט למק"ט) — amaba.dbo.PARTTEXT     keyed by PART (= OrderDetails.PART)
--                * DeviceText  (טקסט למכשיר) — amaba.dbo.SERNUMBERSTEXT keyed by SERN (= OrderDetailsItems.SERN)
--              The CRM stores the text as multi-line, CHARACTER-REVERSED HTML (RTL artifact);
--              it is reconstructed with STRING_AGG(REVERSE(TEXT)) ordered by TEXTLINE, TEXTORD.
-- Param:       @OrderWorkPlanId INT
-- NOTE (perf): reads Priority live over the linked server per item. Fine for a STAGE prototype /
--              small orders; for production consider replicating PARTTEXT/SERNUMBERSTEXT into
--              Calibrator (SSIS / Agent job) and reading locally (see MBA-806 discussion).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetDeviceTextsByOrder]
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH items AS
    (
        SELECT
             itm.OrderDetailsItemId
            ,itm.SerialNumber
            ,itm.SERN
            ,od.PART
        FROM dbo.OrderWorkPlans   AS wp
        JOIN dbo.OrderDetails     AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId  = od.OrderDetailId
        WHERE wp.OrderWorkPlanId     = @OrderWorkPlanId
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
    )
    SELECT
         i.OrderDetailsItemId
        ,i.SerialNumber
        ,i.SERN
        ,i.PART
        ,(
            SELECT STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N'')
                   WITHIN GROUP (ORDER BY pt.[TEXTLINE], pt.[TEXTORD])
            FROM [31.168.173.93].[amaba].[dbo].[PARTTEXT] AS pt
            WHERE pt.[PART] = i.PART
         ) AS CatalogText     -- טקסט למק"ט
        ,(
            SELECT STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), st.[TEXT])), N'')
                   WITHIN GROUP (ORDER BY st.[TEXTLINE], st.[TEXTORD])
            FROM [31.168.173.93].[amaba].[dbo].[SERNUMBERSTEXT] AS st
            WHERE st.[SERN] = i.SERN
         ) AS DeviceText       -- טקסט למכשיר
    FROM items AS i;
END
GO
