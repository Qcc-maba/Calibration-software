-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	Get info about cars assigned for specific order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-123
-- =============================================
CREATE    Procedure [dbo].[GetCarsByOrderNumber]
@OrderNumber NVARCHAR(100),
@CarAssignDate DATETIME2(0) = NULL

/*
EXEC [dbo].[GetCarsByOrderNumber] @OrderNumber = 'LA25100495'
*/
AS
SELECT 
c.CarId,
p.OrderNumber,
c.LicenseNumber,
c.Model as ModelName,
'not exists in db yet' as Mileage,
cwp.AssignDate as [Date],
c.Seats as NumberOfSeats
FROM [dbo].[CarsToOrder] as cwp
JOIN [dbo].[OrderWorkPlans] as p ON cwp.OrderWorkPlanId = p.OrderWorkPlanId 
JOIN [dbo].[Cars] as c ON cwp.CarId = c.CarId
WHERE p.OrderNumber = @OrderNumber AND cwp.IsDeleted = 0 AND p.IsCancelled = 0
AND (@CarAssignDate IS NULL OR cwp.AssignDate = @CarAssignDate)