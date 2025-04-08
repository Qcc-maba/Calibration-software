-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a full list of calibrators with their status and order they are assigned to.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-178
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibrators]
@MainCategory NVARCHAR(100) = NULL,
@SecondCategories NVARCHAR(MAX) = NULL, 
@Certifications NVARCHAR(100) = NULL
--EXEC dbo.GetAllCalibrators

AS 	

--IF @SecondCategories IS NOT NULL
--BEGIN
--DROP TABLE IF EXISTS #SecondCategories
--CREATE TABLE #SecondCategories
--(
--CalibratorId INT
--)
--INSERT #SecondCategories(CalibratorId)
--SELECT u.ID FROM [dbo].[Users] as u 
--JOIN [dbo].[UsersToUserRoles] as r ON u.ID = r.UserId
--WHERE u.IsActive = 1 AND r.UserRoleId = 3 --Calibrator
--	AND (
--u.LastName LIKE '%'+@CalibratorFullName+'%' 
--		OR u.FirstName LIKE '%'+@CalibratorFullName+'%'
--		OR u.FirstNameEng LIKE '%'+@CalibratorFullName+'%'
--		OR u.LastNameEng LIKE '%'+@CalibratorFullName+'%'
--		OR CONCAT(u.FirstName,' ',u.LastName) LIKE '%'+@CalibratorFullName+'%'
--		OR CONCAT(u.FirstNameEng,' ',u.LastNameEng) LIKE '%'+@CalibratorFullName+'%'
--		OR CONCAT(u.LastName,' ',u.FirstName) LIKE '%'+@CalibratorFullName+'%'
--		OR CONCAT(u.LastNameEng,' ',u.FirstNameEng) LIKE '%'+@CalibratorFullName+'%'
--)
--END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT 
    u.[ID],
	u.[FirstName],
	u.[LastName],
	ca.[Status],
	wp.[OrderNumber] as [AssignedToOrderNumber]
  FROM [dbo].[Users] as u
  LEFT JOIN [dbo].[Calibrators] as c ON c.UserId = u.ID 
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON u.[ID] = cp.CalibratorId
  LEFT JOIN [dbo].[OrderWorkPlans] as wp ON cp.OrderWorkPlanId = wp.OrderWorkPlanId
  LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON c.Availability = ca.ID
  LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId'
 -- ,CASE WHEN @MainCategory IS NOT NULL THEN ' JOIN #Calibrators as cf ON ce.[CalibratorId] = cf.[CalibratorId] ' ELSE ' ' END
  --,CASE WHEN @StatusDescription IS NOT NULL THEN ' JOIN #StatusDescriptions as sdf ON ce.[StatusId] = sdf.[StatusId] ' ELSE ' ' END
   ,' WHERE u.IsActive = 1 AND u.ID > 0'
  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND od.[MainCategory] = '''+ @MainCategory+''' 'ELSE ' ' END
)
PRINT @sql
EXEC (@sql)