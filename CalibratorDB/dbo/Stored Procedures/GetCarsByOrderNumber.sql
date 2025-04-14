-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	Get info about cars assigned for specific order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-123
-- =============================================
CREATE    Procedure [dbo].[GetCarsByOrderNumber]
@OrderNumber NVARCHAR(100)

/*
EXEC [dbo].[GetCarsByOrderNumber] @OrderNumber = 'LA25100495'
*/
AS
SELECT 
p.OrderNumber,
c.LicenseNumber,
c.Model as ModelName,
'not exists in db yet' as Mileage,
p.WorkPlanOpenDate as [Date]
FROM [dbo].[CarsToWorkplan] as cwp
JOIN [dbo].[OrderWorkPlans] as p ON cwp.OrderWorkPlanId = p.OrderWorkPlanId 
JOIN [dbo].[Cars] as c ON cwp.CarId = c.CarId
WHERE p.OrderNumber = @OrderNumber AND cwp.IsDeleted = 0 AND p.IsCancelled = 0