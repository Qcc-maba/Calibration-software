-- =============================================
-- Proc:        dbo.GetDeviceTextsByOrder
-- Jira:        MBA-806 ("Add description to the device")
-- Description: Returns the two CRM free-text blocks for each device (OrderDetailsItem) of an order:
--                * DeviceText  (טקסט למכשיר) — keyed by SERN
--                * CatalogText (טקסט למק"ט)  — keyed by PART
--              Reads from the LOCAL cache (dbo.CrmDeviceText / dbo.CrmCatalogText), refreshed from
--              Priority by dbo.RefreshCrmTextCache (scheduled) — fast, no per-request linked-server hit.
--              Original CRM text is multi-line char-reversed HTML; the cache stores it already
--              reconstructed (STRING_AGG(REVERSE(TEXT)) ORDER BY TEXTLINE,TEXTORD).
-- Param:       @OrderWorkPlanId INT
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetDeviceTextsByOrder]
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         itm.OrderDetailsItemId
        ,itm.SerialNumber
        ,itm.SERN
        ,od.PART
        ,ct.CatalogText
        ,dt.DeviceText
    FROM dbo.OrderWorkPlans    AS wp
    JOIN dbo.OrderDetails      AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN dbo.OrderDetailsItems AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN dbo.CrmCatalogText AS ct ON ct.PART = od.PART
    LEFT JOIN dbo.CrmDeviceText  AS dt ON dt.SERN = itm.SERN
    WHERE wp.OrderWorkPlanId      = @OrderWorkPlanId
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsDeleted, 0) = 0;
END
GO
