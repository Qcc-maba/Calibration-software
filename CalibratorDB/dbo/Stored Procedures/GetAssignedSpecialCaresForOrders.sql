-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/04/2025
-- Description:	Get info about special care
-- JiraLink: 
-- =============================================
CREATE   Procedure dbo.GetAssignedSpecialCaresForOrders
@OrderNumber NVARCHAR(100)

/*
EXEC dbo.GetAssignedSpecialCaresForOrders @OrderNumber='LA25100677' 
*/

AS
SELECT DISTINCT
p.OrderWorkPlanId,
p.OrderNumber,
s.StatusId,
s.StatusDescriptionENG,	
s.StatusDescriptionHEB
FROM [dbo].[OrderWorkPlans] as p
JOIN [dbo].[OrderDetails] as od ON p.OrderWorkPlanId = od.OrderWorkPlanId
JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
WHERE p.OrderNumber = @OrderNumber