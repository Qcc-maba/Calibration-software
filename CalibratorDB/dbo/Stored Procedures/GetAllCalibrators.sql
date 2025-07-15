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
JOIN [dbo].[OrdersSecondaryCategories] as s ON odi.OrdersSecondaryCategoryId = s.OrdersSecondaryCategoryId
JOIN dbo.ParseCSVToTable(@SecondCategories) as sc ON s.OrdersSecondaryCategoryName = sc.Value
END

IF @Certifications IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #Certifications
CREATE TABLE #Certifications
(
CalibratorId INT
)
INSERT #Certifications(CalibratorId)
SELECT DISTINCT wp.CalibratorId
FROM [dbo].[CalibratorsToWorkPlan] as wp 
JOIN [dbo].[CalibratorsToCertification] as cts ON wp.CalibratorId = cts.CalibratorId and cts.IsDeleted = 0
JOIN [dbo].[MeasurementsSpecifications] as s ON cts.CertificationId = s.ID and s.IsDeleted = 0
JOIN dbo.ParseCSVToTable(@Certifications) as sc ON s.[Name] = sc.[Value]
END

DECLARE @AvailableStatus INT
SELECT @AvailableStatus = s.StatusId
  FROM [dbo].[Statuses] as s
  JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'UserAvailabilityStatus' AND s.StatusDescriptionENG = 'Available'

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
	wp.[OrderNumber] as [AssignedToOrderNumber],
	STRING_AGG(cc.[Name],'', '') as Certification,
	u.LocationArea,
	ud.DepartmentName
  FROM [dbo].[Users] as u
  JOIN [dbo].[UserRoles] as ur ON  u.UserRoleId = ur.UserRoleId AND ur.UserRoleDescriptionENG = ''Calibrator''
  LEFT JOIN [dbo].[UsersToDepartments] as utd ON u.ID = utd.UserId
  LEFT JOIN [dbo].[Departments] as ud ON ud.ID = utd.DepartmentId
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON u.[ID] = cp.CalibratorId AND cp.IsDeleted = 0
  LEFT JOIN [dbo].[OrderWorkPlans] as wp ON cp.OrderWorkPlanId = wp.OrderWorkPlanId AND wp.IsCancelled = 0
  LEFT JOIN
    (SELECT  u.ID as UserId, COALESCE(ca.AvailabilityStatusId,',@AvailableStatus,') as AvailabilityStatusId,st.StatusDescriptionENG,st.StatusDescriptionHEB, ROW_NUMBER() OVER( PARTITION BY u.ID ORDER BY ca.AvailbilityDateTo) AS rn   
	FROM [dbo].[Users] as u
	LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON u.ID = ca.UserId 
			  AND ca.AvailbilityDateFrom >= CAST(GETDATE() AS DATE) 
			  AND ca.AvailbilityDateTo <= CAST(GETDATE() AS DATE) 
	LEFT JOIN [dbo].[Statuses] as st ON COALESCE(ca.AvailabilityStatusId,',@AvailableStatus,')  = st.StatusId
	) as st ON u.ID =  st.UserId AND st.rn = 1
  LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND od.IsCancelled = 0
  LEFT JOIN [dbo].[CalibratorsToCertification] as ctc ON u.ID = ctc.CalibratorId
  LEFT JOIN [dbo].[MeasurementsSpecifications] as cc ON ctc.CertificationId = cc.ID'
  ,CASE WHEN @SecondCategories IS NOT NULL THEN ' JOIN #SecondCategories as sc ON cp.OrderWorkPlanId = sc.OrderWorkPlanId ' ELSE ' ' END
  ,CASE WHEN @Certifications IS NOT NULL THEN ' JOIN #Certifications as s ON u.ID = s.CalibratorId ' ELSE ' ' END
   ,' WHERE u.IsActive = 1 AND u.ID > 0'
   ,'
    GROUP BY 
    u.[ID],
	u.[FirstName],
	u.[LastName],
	wp.[OrderNumber],
	u.LocationArea,
	ud.DepartmentName
   '
  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND od.[MainCategory] = '''+ @MainCategory+''' 'ELSE ' ' END
)
PRINT @sql
EXEC (@sql)