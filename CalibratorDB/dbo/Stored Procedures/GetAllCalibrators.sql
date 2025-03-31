-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a full list of calibrators with their status and order they are assigned to.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-178
-- =============================================
CREATE   PROCEDURE dbo.GetAllCalibrators

--EXEC dbo.GetAllCalibrators

AS
SELECT c.[ID],
	u.[FirstName],
	u.[LastName],
	ca.[Status],
	wp.[OrderNumber] as [AssignedToOrderNumber]
  FROM [dbo].[Calibrators] as c
  JOIN [dbo].[Users] as u ON c.[UserId] = u.[ID]
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON c.[UserId] = cp.CalibratorsId
  LEFT JOIN [dbo].[WorkPlan] as wp ON cp.[WorkPlanId] = wp.Id
  LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON c.Availability = ca.ID