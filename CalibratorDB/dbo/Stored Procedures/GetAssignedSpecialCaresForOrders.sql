-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/04/2025
-- Description:	Get info about special care
-- JiraLink: 
-- =============================================
CREATE   Procedure [dbo].[GetAssignedSpecialCaresForOrders]
@OrderNumber NVARCHAR(max)

/*
EXEC dbo.GetAssignedSpecialCaresForOrders @OrderNumber=N'LA25100677,LA25100036,LA25100039,LA25100040' 
*/

AS

DROP TABLE IF EXISTS #Orders
CREATE TABLE #Orders
(
OrderWorkPlanId INT PRIMARY KEY
)
INSERT #Orders(OrderWorkPlanId)
SELECT DISTINCT wp.OrderWorkPlanId FROM  dbo.ParseCSVToTable(@OrderNumber) as v
JOIN [dbo].[OrderWorkPlans] as wp ON v.Value = wp.OrderNumber

SELECT DISTINCT
p.OrderWorkPlanId,
p.OrderNumber,
s.StatusId,
s.StatusDescriptionENG,	
s.StatusDescriptionHEB
FROM [dbo].[OrderWorkPlans] as p
JOIN [dbo].[OrderDetails] as od ON p.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
JOIN #Orders as o ON p.OrderWorkPlanId = o.OrderWorkPlanId
WHERE p.IsCancelled = 0 and od.IsCancelled = 0