-- =============================================
-- Proc:        dbo.GetAllCalibrators
-- Jira:        MBA-155 (parent MBA-95 "Assign calibrator to the order")
-- Origin:      Originally authored by Eduard Kudlaiev, 17/03/2025, under MABA-178.
--              This file captures the live prod definition as a reviewable, source-controlled
--              CREATE OR ALTER script for MBA-155 "Create SP to get calibrator list".
--
-- Description: Returns the full list of calibrators (users in role 'Calibrator', and
--              'TeamLeader' when @IncludeTeamLeaders = 1) together with their availability
--              status, any calendar event that overlaps @CheckDate, the order they are
--              assigned to on that date, their certification authorities, location and
--              department. This is the list rendered by the app's calibrator-assignment
--              dialog (tRPC calibrators.getMany -> EXEC dbo.GetAllCalibrators).
--
-- Behaviour / branches:
--   * @OrderWorkPlanId IS NOT NULL  -> lightweight branch: just the calibrators already
--                                      assigned to that work plan (ID/name + report number,
--                                      all status columns NULL).
--   * otherwise                     -> full availability computation for @CheckDate
--                                      (defaults to GETDATE()), optionally filtered by
--                                      @MainCategory / @SecondCategories / @CertificationAuthoritiesIdsList.
--
-- Params (all optional; app passes @CheckDate, @OrderWorkPlanId, @IncludeTeamLeaders):
--   @MainCategory                    NVARCHAR(100)  filter on OrderDetails.MainCategory
--   @SecondCategories                NVARCHAR(MAX)  CSV of secondary category names
--   @CertificationAuthoritiesIdsList NVARCHAR(MAX)  CSV of certification-authority ids
--   @CheckDate                       DATE           availability/assignment reference date
--   @OrderWorkPlanId                 INT            selects the lightweight assigned-only branch
--   @IncludeTeamLeaders              BIT            include TeamLeader role (default 0)
--
-- Output columns (order relied on by mapRawToCalibrator / TRawCalibrator):
--   ID, FirstName, LastName, AvailabilityStatusId, StatusENG, StatusHEB, EventDescription,
--   AssignedToOrderNumber, CalibratorAuthorityName, LocationArea, DepartmentName,
--   OrderDetailsMbaReportNumber
--
-- REVIEW NOTE (Ariel): the app mapper reads a column named `Certification`
--   (rawCalibratorFields.Certification), but this SP emits it as `CalibratorAuthorityName`.
--   As-is the app's `certification` field is always null. Body is reproduced verbatim from
--   prod to avoid a silent behaviour change — decide whether to rename the alias to
--   `Certification` here (fixes the app) as part of this ticket.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetAllCalibrators]
@MainCategory NVARCHAR(100) = NULL,
@SecondCategories NVARCHAR(MAX) = NULL,
@CertificationAuthoritiesIdsList NVARCHAR(MAX) = NULL,
@CheckDate DATE = NULL,
@OrderWorkPlanId INT = NULL,
@IncludeTeamLeaders BIT = 0
--EXEC dbo.GetAllCalibrators

AS

SET NOCOUNT ON;

IF @OrderWorkPlanId IS NOT NULL

	SELECT 	u.[ID],
			u.[FirstName],
			u.[LastName],
			NULL as AvailabilityStatusId,
			NULL as [StatusENG],
			NULL as  [StatusHEB],
			NULL as [EventDescription],
			NULL as [AssignedToOrderNumber],
			NULL as CalibratorAuthorityName,
			NULL as LocationArea,
			NULL as DepartmentName,
			wp.OrderDetailsMbaReportNumber
		  FROM [dbo].[Users] as u
          JOIN [dbo].[CalibratorsToWorkPlan] as wp ON u.[ID] = wp.CalibratorId
		  WHERE wp.OrderWorkPlanId = @OrderWorkPlanId
ELSE

	BEGIN

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
		JOIN [dbo].[SecondaryCategories] as s ON od.SecondaryCategoryId = s.ID
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
		EventDescriptionHEB NVARCHAR(300) COLLATE Latin1_General_100_CI_AI_SC,
		EventDescriptionENG NVARCHAR(300) COLLATE Latin1_General_100_CI_AI_SC,
		EventStatusId int
		)
		INSERT #Events (UserId,EventDescriptionHEB,EventDescriptionENG,EventStatusId)
		SELECT
		ctp.UserId ,
		STRING_AGG(s.StatusDescriptionHEB,',') as EventDescriptionHEB,
		STRING_AGG(s.StatusDescriptionENG,',') as EventDescriptionENG,
		MAX(ce.EventTypeId) as EventStatusId
		FROM [dbo].[CalendarEvents] as ce
		JOIN [dbo].[CalendarEventsToParticipants] as ctp ON ce.CalendarEventId = ctp.CalendarEventId
		JOIN [dbo].[Statuses] as s ON ce.EventTypeId = s.StatusId
		WHERE CAST([ce].[StartDate] AS DATE) >= @CheckDate AND CAST([ce].[EndDate] AS DATE) <= @CheckDate
		AND ce.IsDeleted = 0 AND ctp.IsDeleted = 0
		GROUP BY ctp.UserId

		DECLARE @UserRoleIdFilter NVARCHAR(MAX)

		SELECt @UserRoleIdFilter = STRING_AGG(UserRoleId,',')
		FROM [dbo].[UserRoles]
		WHERE UserRoleName = 'Calibrator'
		OR (@IncludeTeamLeaders = 1 AND UserRoleName='TeamLeader')

		DECLARE @sql NVARCHAR(MAX) =
		CONCAT(
		'
		SELECT DISTINCT
			u.[ID],
			u.[FirstName],
			u.[LastName],
			MAX(COALESCE(ee.EventStatusId,st.AvailabilityStatusId)) as AvailabilityStatusId,
			MAX(COALESCE(ee.EventDescriptionENG,st.StatusDescriptionENG))	as [StatusENG],
			MAX(COALESCE(ee.EventDescriptionHEB,st.StatusDescriptionHEB)) as [StatusHEB],
			MAX(ee.EventDescriptionHEB) as [EventDescription],
			wp.[OrderNumber] as [AssignedToOrderNumber],
			MAX(can.[CalibratorAuthorityName]) as CalibratorAuthorityName,
			u.LocationArea,
			STRING_AGG(ud.[MainCategoryName],'', '') as DepartmentName,
			MAX(cp.OrderDetailsMbaReportNumber) AS OrderDetailsMbaReportNumber
		  FROM [dbo].[Users] as u
		  JOIN [dbo].[UserRoles] as ur ON  u.UserRoleId = ur.UserRoleId AND ur.UserRoleId IN ('+@UserRoleIdFilter+')
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
		  OUTER APPLY
		  (
		  SELECT STRING_AGG(cc.[AuthorityName],'', '') as CalibratorAuthorityName
		  FROM [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as ctc
		  LEFT JOIN [dbo].[CalibratorCertificationAuthorities] as cc ON ctc.CalibratorCertificationAuthorityId = cc.ID
		  WHERE ctc.IsDeleted = 0 AND u.ID = ctc.CalibratorId
		  GROUP BY ctc.CalibratorId
		  ) as can
		  '
		  ,CASE WHEN @SecondCategories IS NOT NULL THEN ' JOIN #SecondCategories as sc ON cp.OrderWorkPlanId = sc.OrderWorkPlanId ' ELSE ' ' END
		  ,CASE WHEN @CertificationAuthoritiesIdsList IS NOT NULL THEN ' JOIN #CertificationAuthoritiesIdsList as s ON u.ID = s.CalibratorId ' ELSE ' ' END
		   ,' WHERE u.IsActive = 1 AND u.ID > 0 '
		   ,'
			GROUP BY
			u.[ID],
			u.[FirstName],
			u.[LastName],
			wp.[OrderNumber],
			u.LocationArea
			'
		  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND od.[MainCategory] = '''+ @MainCategory+''' 'ELSE ' ' END
		)
		PRINT @sql
		EXEC (@sql)
	END
GO
