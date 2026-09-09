-- =============================================
-- Proc:        dbo.GetOrderInstructionsByOrder
-- Jira:        MBA-806 ("Add description to the device") — order-level execution instructions
-- Description: Returns the CRM order text ("הנחיות לביצוע" / Execution Instructions) for an order,
--              from Priority amaba.dbo.ORDERSTEXT via the existing linked server [31.168.173.93].
--              Key: ORDERSTEXT.ORD = OrderWorkPlans.OrderSourceId.
--              CRM text is multi-line, CHARACTER-REVERSED HTML; reconstructed with
--              STRING_AGG(REVERSE(TEXT)) ordered by TEXTLINE, TEXTORD.
-- Param:       @OrderWorkPlanId INT
-- Returns:     one row: OrderWorkPlanId, ORD, OrderInstructions (NVARCHAR(MAX) HTML; NULL if none).
-- NOTE: ORDERSTEXT holds the FULL order-document HTML — measured on STAGE at ~62,600 chars and
--       ~720 source lines per order, not a short note.
--
-- 2026-08-10: no longer reads Priority live. Served from dbo.CrmOrderInstructions, filled in
--       batches of 20 orders by dbo.RefreshCrmTextCache and topped up automatically at the end of
--       every stg.MergeOrdersData run. Live read was ~0.7-2s per order; the cache is ~0.01s.
--       A row with NULL OrderInstructions means checked-and-empty (18 of 1,003 orders on STAGE),
--       which is why this SP does not fall back to the linked server on a miss — a miss means the
--       order has not been through a sync yet, and the next sync will pick it up.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetOrderInstructionsByOrder]
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Ord INT;
    SELECT @Ord = wp.OrderSourceId
    FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderWorkPlanId = @OrderWorkPlanId;

    SELECT
         @OrderWorkPlanId AS OrderWorkPlanId
        ,@Ord             AS ORD
        ,CAST(DECOMPRESS(ci.OrderInstructionsZ) AS NVARCHAR(MAX)) AS OrderInstructions
    FROM (SELECT 1 AS one) AS anchor
    LEFT JOIN dbo.CrmOrderInstructions AS ci ON ci.ORD = @Ord;
END
GO
