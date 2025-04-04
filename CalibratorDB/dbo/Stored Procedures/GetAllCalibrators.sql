-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a full list of calibrators with their status and order they are assigned to.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-178
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibrators]

--EXEC dbo.GetAllCalibrators

AS
SELECT u.[ID],
	u.[FirstName],
	u.[LastName],
	ca.[Status],
	wp.[OrderNumber] as [AssignedToOrderNumber]
  FROM [dbo].[Users] as u
  LEFT JOIN [dbo].[Calibrators] as c ON c.UserId = u.ID 
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON u.[ID] = cp.CalibratorId
  LEFT JOIN [dbo].[OrderWorkPlans] as wp ON cp.OrderWorkPlanId = wp.OrderWorkPlanId
  LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON c.Availability = ca.ID