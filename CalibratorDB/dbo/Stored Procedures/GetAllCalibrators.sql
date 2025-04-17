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
SELECT DISTINCT od.OrderWorkPlanId FROM [dbo].[OrderDetails] as od
JOIN dbo.ParseCSVToTable(@SecondCategories) as sc ON od.SecondCategory = sc.Value
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
JOIN [dbo].[CalibratorsToCertification] as cts ON wp.CalibratorId = cts.CalibratorId
JOIN [dbo].[CalibratorsCertifications] as s ON cts.CertificationId = s.ID
JOIN dbo.ParseCSVToTable(@Certifications) as sc ON s.[Certificate] = sc.[Value]
END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT DISTINCT
    u.[ID],
	u.[FirstName],
	u.[LastName],
	NULL as [Status],
	wp.[OrderNumber] as [AssignedToOrderNumber],
	STRING_AGG(cc.Certificate,'', '') as Certification 
  FROM [dbo].[Users] as u
  LEFT JOIN [dbo].[Calibrators] as c ON c.UserId = u.ID 
  LEFT JOIN [dbo].[CalibratorsToWorkPlan] cp ON u.[ID] = cp.CalibratorId AND cp.IsDeleted = 0
  LEFT JOIN [dbo].[OrderWorkPlans] as wp ON cp.OrderWorkPlanId = wp.OrderWorkPlanId AND wp.IsCancelled = 0
 -- LEFT JOIN [dbo].[CalibratorsAvailability] as ca ON c.Availability = ca.ID
  LEFT JOIN [dbo].[OrderDetails] as od ON od.OrderWorkPlanId = wp.OrderWorkPlanId AND od.IsCancelled = 0
  LEFT JOIN [dbo].[CalibratorsToCertification] as ctc ON u.ID = ctc.CalibratorId
  LEFT JOIN [dbo].[CalibratorsCertifications] as cc ON ctc.CertificationId = cc.ID'
  ,CASE WHEN @SecondCategories IS NOT NULL THEN ' JOIN #SecondCategories as sc ON cp.OrderWorkPlanId = sc.OrderWorkPlanId ' ELSE ' ' END
  ,CASE WHEN @Certifications IS NOT NULL THEN ' JOIN #Certifications as s ON u.ID = s.CalibratorId ' ELSE ' ' END
   ,' WHERE u.IsActive = 1 AND u.ID > 0'
   ,'
     GROUP BY 
    u.[ID],
	u.[FirstName],
	u.[LastName],
	--NULL as [Status],
	wp.[OrderNumber]
   '
  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND od.[MainCategory] = '''+ @MainCategory+''' 'ELSE ' ' END
)
PRINT @sql
EXEC (@sql)