-- =============================================
-- Proc:        dbo.GetPackingListDocument
-- Jira:        MBA-826 ("Change the order number on packing screen to packing list document, starts with 'D'")
-- Description: Returns the packing-list / delivery document (תעודת משלוח) for an order — the
--              value in OrderDetailsItems.ShippingDoc, which starts with 'D' (e.g. D26008046).
--              The packing screen should show this instead of the order number.
--
--              NOT one document per order (earlier note here claimed that — it is wrong).
--              Re-verified on STAGE 2026-08-10: 21 orders carry 2+ distinct D-docs, e.g.
--              LA26101961 → D26005338 (9 items) + D26005339 (15 items). This SP therefore
--              returns ONE ROW PER (order, document) with its ItemsCount; the caller must
--              decide what to show when an order has several (all of them / the latest /
--              per-item). Also 1,058 of 2,575 items (41%) have NO ShippingDoc at all, so many
--              orders legitimately have no D-doc yet and the screen has nothing to display.
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
