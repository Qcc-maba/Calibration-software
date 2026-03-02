

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/03/2026
-- Description:	Get information about customer aucomming calibration
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerUpcommingCalibrationInfo] 
@LoggedInUserEmail NVARCHAR(50)
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT

SELECT 
	@CustomerId  = d.CustomerId 
,@SourceId = d.SourceId
FROM [dbo].[CustomerContacts] as d
WHERE CustomerContactEmail = @LoggedInUserEmail 

DECLARE @CurrentDate DATETIME2(0) =  CAST(GETDATE() AS DATE)

SELECT TOP 1 WITH TIES
 u.FirstName	
,u.LastName
,u.Email
,u.Phone
,AssigmentDate
--,wp.OrderWorkPlanId
--, wp.CustomerId
--,wp.OrderNumber
FROM [dbo].[OrderWorkPlans] as wp
JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.IsDeleted = 0
JOIN [dbo].[Users] as u ON ctwp.CalibratorId = u.[ID]
WHERE  wp.CustomerId = @CustomerId AND ctwp.AssigmentDate >= @CurrentDate
AND wp.IsCancelled = 0 
ORDER BY RANK() OVER( ORDER BY ctwp.AssigmentDate)