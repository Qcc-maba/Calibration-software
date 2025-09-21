-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a full list of calibrators with their status and order they are assigned to.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-178
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibrators]
@MainCategory NVARCHAR(100) = NULL,
@SecondCategories NVARCHAR(MAX) = NULL, 
@CertificationAuthoritiesIdsList NVARCHAR(MAX) = NULL,
@CheckDate DATE = NULL
--EXEC dbo.GetAllCalibrators

AS 	

IF @CheckDate IS NULL SET @CheckDate = GETDATE()

IF @SecondCategories IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #SecondCategories
CREATE TABLE #SecondCategories
(
OrderWorkPlanId INT
)
INSERT #SecondCategories(OrderWorkPlanId)
SELECT DISTINCT od.OrderWorkPlanId FROM [dbo].[OrderDetailsItems] as odi
JOIN [dbo].[OrderDetails] as od ON odi.OrderDetailId = od.OrderDetailId
JOIN [dbo].[SecondaryCategories] as s ON odi.SecondaryCategoryId = s.ID
JOIN dbo.ParseCSVToTable(@SecondCategories) as sc ON s.SecondaryCategoryName = sc.Value
END

IF @CertificationAuthoritiesIdsList IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #CertificationAuthoritiesIdsList
CREATE TABLE #CertificationAuthoritiesIdsList
(
CalibratorId INT
)
INSERT #CertificationAuthoritiesIdsList(CalibratorId)
SELECT DISTINCT cts.CalibratorId
FROM [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as cts 
JOIN dbo.ParseCSVToTable(@CertificationAuthoritiesIdsList) as sc ON cts.[CalibratorCertificationAuthorityId] = sc.[Value]
WHERE cts.IsDeleted = 0
END

DECLARE @AvailableStatus INT
SELECT @AvailableStatus = s.StatusId
  FROM [dbo].[Statuses] as s
  JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'UserAvailabilityStatus' AND s.StatusDescriptionENG = 'Available'

DROP TABLE IF EXISTS #Events
CREATE TABLE #Events
(
UserId INT PRIMARY KEY,
EventDescription NVARCHAR(300)
)
INSERT #Events (UserId,EventDescription)
SELECT 
ctp.UserId , STRING_AGG(s.StatusDescriptionHEB,',') as EventDescription
FROM [dbo].[CalendarEvents] as ce
JOIN [dbo].[CalendarEventsToParticipants] as ctp ON ce.CalendarEventId = ctp.CalendarEventId
JOIN [dbo].[Statuses] as s ON ce.EventTypeId = s.StatusId
WHERE CAST([ce].[StartDate] AS DATE) <= @CheckDate AND CAST([ce].[EndDate] AS DATE) >= @CheckDate
AND ce.IsDeleted = 0 AND ctp.IsDeleted = 0
GROUP BY ctp.UserId


DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT DISTINCT
    u.[ID],
	u.[FirstName],
	u.[LastName],
	MAX(st.AvailabilityStatusId) as AvailabilityStatusId,
	MAX(st.StatusDescriptionENG)	as [StatusENG],
	MAX(st.StatusDescriptionHEB) as [StatusHEB],
	MAX(ee.EventDescription) as [EventDescription],
	wp.[OrderNumber] as [AssignedToOrderNumber],
	STRING_AGG(cc.[AuthorityName],'', '') as CalibratorAuthorityName,
	u.LocationArea,
	ud.[MainCategoryName] as DepartmentName
  FROM [dbo].[Users] as u
  JOIN [dbo].[UserRoles] as ur ON  u.UserRoleId = ur.UserRoleId AND ur.UserRoleName IN (N''Calibrator'',N''ExternalCalibrator'')
  LEFT JOIN [dbo].[UsersToDepartments] as utd ON u.ID = utd.UserId
  LEFT JOIN [dbo].[MainCategories] as ud ON ud.ID = utd.MainCategoryId
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON u.[ID] = cp.CalibratorId AND cp.IsDeleted = 0 AND cp.AssigmentDate = ''',@CheckDate,'''
  LEFT JOIN [dbo].[OrderWorkPlans] as wp ON cp.OrderWorkPlanId = wp.OrderWorkPlanId AND wp.IsCancelled = 0
  LEFT JOIN #Events as ee ON u.ID = ee.UserId
  LEFT JOIN
   (SELECT  u.ID as UserId, COALESCE(ca.AvailabilityStatusId,',@AvailableStatus,') as AvailabilityStatusId,st.StatusDescriptionENG,st.StatusDescriptionHEB, ROW_NUMBER() OVER( PARTITION BY u.ID ORDER BY ca.AvailbilityDateTo) AS rn   
	FROM [dbo].[Users] as u
	LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON u.ID = ca.UserId AND ca.IsDeleted = 0
			  AND ca.AvailbilityDateFrom >= ''',@CheckDate,'''
			  AND ca.AvailbilityDateTo <= ''',@CheckDate,'''
	LEFT JOIN [dbo].[Statuses] as st ON COALESCE(ca.AvailabilityStatusId,',@AvailableStatus,')  = st.StatusId
	) as st ON u.ID =  st.UserId AND st.rn = 1
  LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND od.IsCancelled = 0
  LEFT JOIN [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as ctc ON u.ID = ctc.CalibratorId
  LEFT JOIN [dbo].[CalibratorCertificationAuthorities] as cc ON ctc.CalibratorCertificationAuthorityId = cc.ID'
  ,CASE WHEN @SecondCategories IS NOT NULL THEN ' JOIN #SecondCategories as sc ON cp.OrderWorkPlanId = sc.OrderWorkPlanId ' ELSE ' ' END
  ,CASE WHEN @CertificationAuthoritiesIdsList IS NOT NULL THEN ' JOIN #CertificationAuthoritiesIdsList as s ON u.ID = s.CalibratorId ' ELSE ' ' END
   ,' WHERE u.IsActive = 1 AND u.ID > 0 '
   ,'
    GROUP BY 
    u.[ID],
	u.[FirstName],
	u.[LastName],
	wp.[OrderNumber],
	u.LocationArea,
	ud.[MainCategoryName]
   '
  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND od.[MainCategory] = '''+ @MainCategory+''' 'ELSE ' ' END
)
PRINT @sql
EXEC (@sql)