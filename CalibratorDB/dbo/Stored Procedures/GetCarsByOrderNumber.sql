-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 14/04/2025
-- Description:	Get info about cars assigned for specific order
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-123
-- =============================================
CREATE     Procedure [dbo].[GetCarsByOrderNumber]
@OrderNumber NVARCHAR(100),
@AssignStartDate DATETIME2(0) = NULL,
@AssignEndDate DATETIME2(0) = NULL,
@LoggedInUserEmail NVARCHAR(100) = NULL

/*
EXEC [dbo].[GetCarsByOrderNumber] @OrderNumber = 'LA25105420'
*/
AS

DECLARE @CalibratorId INT = NULL

SELECT @CalibratorId = u.ID 
FROM [dbo].[Users] as u
JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
WHERE u.Email=@LoggedInUserEmail AND ur.UserRoleName = 'Calibrator' 

SELECT 
c.CarId,
p.OrderNumber,
c.LicenseNumber,
c.Model as ModelName,
'not exists in db yet' as Mileage,
cwp.AssignDate as [Date],
c.Seats as NumberOfSeats,
acto.AssignedCalibrators
FROM [dbo].[CarsToOrder] as cwp
JOIN [dbo].[OrderWorkPlans] as p ON cwp.OrderWorkPlanId = p.OrderWorkPlanId 
JOIN [dbo].[Cars] as c ON cwp.CarId = c.CarId
OUTER APPLY
(
SELECT ctwp.CalibratorId,STRING_AGG(ctwp.CalibratorId,',') as AssignedCalibrators
FROM [dbo].[CalibratorsToWorkPlan] as ctwp
WHERE p.OrderWorkPlanId = ctwp.OrderWorkPlanId AND ctwp.CarId = cwp.CarId AND ctwp.AssigmentDate = cwp.AssignDate and ctwp.IsDeleted = 0 
  AND (@CalibratorId IS NULL OR ctwp.CalibratorId = @CalibratorId)
GROUP BY ctwp.CalibratorId
) as acto
WHERE p.OrderNumber = @OrderNumber AND cwp.IsDeleted = 0 AND p.IsCancelled = 0
AND (@AssignStartDate IS NULL OR (cwp.AssignDate >= @AssignStartDate AND cwp.AssignDate <= @AssignEndDate))
AND (@CalibratorId IS NULL OR acto.CalibratorId = @CalibratorId)