-- =============================================
-- Proc:        dbo.GetPackingListDocument
-- Jira:        MBA-826 ("Change the order number on packing screen to packing list document, starts with 'D'")
-- Description: Returns the packing-list / delivery document (תעודת משלוח) for an order — the
--              value in OrderDetailsItems.ShippingDoc, which starts with 'D' (e.g. D26008046).
--              One packing-list document per order (verified on STAGE: 1 distinct D-doc / order).
--              The packing screen should show this instead of the order number.
-- Param:       @OrderWorkPlanId INT = NULL  (NULL = all orders that have a packing document)
-- Returns:     OrderWorkPlanId, OrderNumber, PackingListDocument, ItemsCount
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetPackingListDocument]
    @OrderWorkPlanId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         wp.OrderWorkPlanId
        ,wp.OrderNumber
        ,itm.ShippingDoc            AS PackingListDocument   -- תעודת משלוח (starts with 'D')
        ,COUNT(*)                   AS ItemsCount
    FROM dbo.OrderWorkPlans     AS wp
    JOIN dbo.OrderDetails       AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN dbo.OrderDetailsItems  AS itm ON itm.OrderDetailId  = od.OrderDetailId
    WHERE itm.ShippingDoc LIKE 'D%'
      AND (@OrderWorkPlanId IS NULL OR wp.OrderWorkPlanId = @OrderWorkPlanId)
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
    GROUP BY wp.OrderWorkPlanId, wp.OrderNumber, itm.ShippingDoc
    ORDER BY wp.OrderWorkPlanId DESC;
END
GO
