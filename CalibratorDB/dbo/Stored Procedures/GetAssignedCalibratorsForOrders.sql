-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/04/2025
-- Description:	Get info about calibrators for specific order
-- JiraLink: 
-- =============================================
CREATE    Procedure [dbo].[GetAssignedCalibratorsForOrders]
@OrderNumber NVARCHAR(100),
@CheckDate DATE = NULL
AS

IF @CheckDate IS NULL SET @CheckDate = GETDATE()

SELECT 
ctp.OrderWorkPlanId,
p.OrderNumber,
u.ID AS UserId,
u.FirstName AS FirstNameHEB,
u.LastName AS LastNameHEB,
u.FirstNameEng AS FirstNameENG,
u.LastNameEng AS LastNameENG
FROM [dbo].[CalibratorsToWorkPlan] as ctp
JOIN [dbo].[OrderWorkPlans] as p ON ctp.OrderWorkPlanId = p.OrderWorkPlanId
JOIN [dbo].[Users] as u ON ctp.CalibratorId = u.ID
WHERE p.OrderNumber = @OrderNumber AND ctp.IsDeleted = 0 AND p.IsCancelled = 0 
	  AND u.IsActive = 1 AND ctp.AssigmentDate = @CheckDate