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
-- NOTE: ORDERSTEXT holds the FULL order-document HTML (can be tens of KB / >1000 lines per order),
--       not just a short note. Reads Priority live over the linked server (~2s/order in testing).
--       For production/scale consider replicating ORDERSTEXT into Calibrator (SSIS/Agent) — see MBA-806.
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
        ,(
            SELECT STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), ot.[TEXT])), N'')
                   WITHIN GROUP (ORDER BY ot.[TEXTLINE], ot.[TEXTORD])
            FROM [31.168.173.93].[amaba].[dbo].[ORDERSTEXT] AS ot
            WHERE ot.[ORD] = @Ord
         ) AS OrderInstructions;
END
GO
