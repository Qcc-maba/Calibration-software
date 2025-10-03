
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a list of all company employees
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-168
-- =============================================
CREATE    PROCEDURE [dbo].[GetAllEmployees]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 5000,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'Email',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@FirstName NVARCHAR(255) = NULL,
    @LastName NVARCHAR(255) = NULL,
	@Phone NVARCHAR(20) =  NULL,
	@Address NVARCHAR(200) = NULL,
    @LocationArea NVARCHAR(200) = NULL,
	@Email NVARCHAR(50) = NULL,
    @UserRoleId INT  = NULL,
	@UserStatusIds NVARCHAR(50) = NULL,
	@DepartmentIdsList NVARCHAR(max) = NULL, -- mapped to main category
	@CertificationAuthoritiesIdsList NVARCHAR(MAX) = NULL,
	@EventStartDate DATETIME2(0) = NULL,
    @EventEndDate DATETIME2(0) = NULL,
	@PositionId INT = NULL,
	@GlobalSearch NVARCHAR(200) = NULL
AS
BEGIN

SET NOCOUNT ON;

	IF @OrderBy NOT IN 
	(N'FirstName', N'LastName', N'FirstNameEng', N'LastNameEng', N'Phone', N'Email', N'UserAddress', N'LocationArea', N'UserRoleENG', N'UserRoleHEB', N'DepartmentNames', N'Certification',N'Stamp',N'Position',N'CalibratorAuthorityNames')
	THROW 51000, 'Incorrect value for parameter @OrderBy. Available values FirstName|LastName|FirstNameEng|LastNameEng|Phone|Email|UserAddress|LocationArea|UserRoleENG|UserRoleHEB|DepartmentNames|Certification|Stamp|Position|CalibratorAuthorityNames', 1;


	IF @FirstName IS NOT NULL OR @LastName IS NOT NULL 
	BEGIN
	DROP TABLE IF EXISTS #UserFullName
	CREATE TABLE #UserFullName
	(
	UserId INT
	)
	INSERT #UserFullName(UserId)
	SELECT u.ID FROM [dbo].[Users] as u 
	WHERE u.IsActive = 1
		  AND (
			u.LastName LIKE '%'+@LastName+'%' 
			OR u.LastNameEng LIKE '%'+@LastName+'%'
	) and u.ID > 0
	UNION ALL
		SELECT u.ID FROM [dbo].[Users] as u 
	WHERE u.IsActive = 1
		  AND (
			u.FirstName LIKE '%'+@FirstName+'%'
			OR u.FirstNameEng LIKE '%'+@FirstName+'%'
	) and u.ID > 0
	END

DROP TABLE IF EXISTS #Status
CREATE TABLE #Status 
(
StatusId INT,
IsActive BIT,
AvailabilityStatusDescriptionHEB NVARCHAR(100) COLLATE Latin1_General_100_CI_AI_SC
)
INSERT #Status(StatusId,IsActive,AvailabilityStatusDescriptionHEB)
SELECT 
  s.StatusId,
  IIF(s.StatusDescriptionENG='Active',1,0) as IsActive,
  s.StatusDescriptionHEB
  FROM [dbo].[Statuses] as s
  JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'UserStatus'

DROP TABLE IF EXISTS #UserStatusesIds
CREATE TABLE #UserStatusesIds
(
UserId INT
)

INSERT #UserStatusesIds(UserId)
--Insert users filtered by provided @UserStatusIds
SELECT DISTINCT u.ID AS UserId 
FROM [dbo].[Users] as u
JOIN #Status as s ON u.IsActive = s.IsActive
JOIN dbo.ParseCSVToTable(@UserStatusIds) as v ON s.StatusId = v.Value

DROP TABLE IF EXISTS #DepartmentUserIds
CREATE TABLE #DepartmentUserIds
(
UserId INT
)

INSERT #DepartmentUserIds(UserId)
--Insert users filtered by provided @DepartmentIdsList
SELECT DISTINCT ud.UserId 
FROM dbo.ParseCSVToTable(@DepartmentIdsList) as v
JOIN dbo.UsersToDepartments as ud ON v.Value = ud.MainCategoryId
WHERE ud.IsDeleted = 0
--Insert users filtered by provided @CertificationAuthoritiesIdsList

DROP TABLE IF EXISTS #CertificationUserIds
CREATE TABLE #CertificationUserIds
(
UserId INT
)

INSERT #CertificationUserIds(UserId)
SELECT DISTINCT c.CalibratorId as UserId 
FROM dbo.ParseCSVToTable(@CertificationAuthoritiesIdsList) as v
JOIN [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as c ON v.Value = c.CalibratorCertificationAuthorityId
WHERE c.IsDeleted = 0

DECLARE @EventTypeId INT,
	    @StatusDescriptionHEB NVARCHAR(255),
	    @StatusDescriptionENG NVARCHAR(255)
IF @EventStartDate IS NOT NULL AND @EventEndDate IS NOT NULL
BEGIN
	DROP TABLE IF EXISTS #AssociatedCalendarEvents
	CREATE TABLE #AssociatedCalendarEvents
	(
	UserId INT,
	EventTypeId INT,
	StatusDescriptionHEB NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC,
	StatusDescriptionENG NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC
	)
	
	;WITH LastEvent
	AS
	(
	SELECT cetp.UserId, 
	       s.StatusId as EventTypeId,
		   s.StatusDescriptionHEB, 
		   s.StatusDescriptionENG,
		   ROW_NUMBER() OVER (PARTITION BY cetp.UserId ORDER BY ce.StartDate DESC ) AS rn
	FROM [dbo].[CalendarEvents] as ce
	JOIN [dbo].[CalendarEventsToParticipants] as cetp ON ce.CalendarEventId = cetp.CalendarEventId and cetp.IsDeleted = 0
	JOIN [dbo].[Statuses] as s ON ce.EventTypeId = s.StatusId
	WHERE ce.StartDate <= @EventEndDate AND  ce.EndDate >= @EventStartDate 
	AND ce.IsDeleted = 0
	)
	INSERT #AssociatedCalendarEvents(UserId,EventTypeId,StatusDescriptionHEB,StatusDescriptionENG)
	SELECT le.UserId,le.EventTypeId,le.StatusDescriptionHEB,le.StatusDescriptionENG
	FROM LastEvent as le
	WHERE le.rn = 1
END


DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT u.ID,
	   u.FirstName,
	   u.LastName,
	   u.FirstNameEng,
	   u.LastNameEng,
	   u.Phone,
	   u.Email,
	   u.UserAddress,
	   u.LocationArea,
	   ur.UserRoleDescriptionENG as UserRoleENG,	
	   ur.UserRoleDescriptionHEB as UserRoleHEB,
	   dep.DepartmentIds,
	   dep.DepartmentNames,
	   cc.CalibratorAuthorityNames,
	   ur.UserRoleId as UserRoleIds,
	   cc.CalibratorAuthorityIds,
	   u.Stamp,
	   u.Password,
	   u.IsActive,
	   ss.StatusId as AvailabilityStatusId,
	   ss.AvailabilityStatusDescriptionHEB,
	   '
	   ,IIF(@EventStartDate IS NOT NULL AND @EventEndDate IS NOT NULL,'ace.EventTypeId, ace.StatusDescriptionHEB , ace.StatusDescriptionENG,  ',' '),
	   '
	   u.PositionId,
	   ps.StatusDescriptionHEB as Position,
	   COUNT(1) OVER(PARTITION BY 1 ORDER BY u.ID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
FROM [dbo].[Users] as u
JOIN #Status as ss ON u.IsActive = ss.IsActive
LEFT JOIN [dbo].[Statuses] as ps ON u.PositionId = ps.StatusId
LEFT JOIN [dbo].[UserRoles] as ur ON u.UserRoleId = ur.UserRoleId
'
,IIF(@UserStatusIds IS NOT NULL,' JOIN #UserStatusesIds as uf2 ON u.ID =  uf2.UserId ',' ')
,IIF(@DepartmentIdsList IS NOT NULL,' JOIN #DepartmentUserIds as uf3 ON u.ID =  uf3.UserId ',' ')
,IIF(@CertificationAuthoritiesIdsList IS NOT NULL,' JOIN #CertificationUserIds as uf4 ON u.ID =  uf4.UserId ',' ')
,IIF(@FirstName IS NOT NULL OR @LastName IS NOT NULL,' JOIN #UserFullName  as f ON u.ID =  f.UserId ',' ')
,IIF(@EventStartDate IS NOT NULL AND @EventEndDate IS NOT NULL,' LEFT JOIN #AssociatedCalendarEvents as ace ON u.ID =  ace.UserId ',' '),
'LEFT JOIN
(
SELECT ctc.CalibratorId as UserId,
	   STRING_AGG(a.ID,'','') as CalibratorAuthorityIds,
	   STRING_AGG(a.AuthorityName,'','') as CalibratorAuthorityNames
FROM [dbo].[CalibratorsToCertificationAuthoritiesAuthorities] as ctc
JOIN [dbo].[CalibratorCertificationAuthorities] as a ON ctc.CalibratorCertificationAuthorityId = a.ID AND a.IsDeleted = 0
WHERE ctc.IsDeleted = 0
GROUP BY ctc.CalibratorId
) as cc ON u.ID = cc.UserId
LEFT JOIN
(
SELECT ud.UserId, 
STRING_AGG(ud.MainCategoryId,'','') as DepartmentIds,
STRING_AGG(d.MainCategoryName,'','') as DepartmentNames
FROM [dbo].[UsersToDepartments] as ud
LEFT JOIN [dbo].[MainCategories] as d ON ud.MainCategoryId = d.ID
WHERE ud.IsDeleted = 0
GROUP BY ud.UserId
) as dep ON u.ID = dep.UserId
WHERE u.ID > 0 
'
,CASE WHEN @Phone IS NOT NULL THEN ' AND u.Phone LIKE N''%'+ @Phone +'%'' 'ELSE ' ' END
,CASE WHEN @Address IS NOT NULL THEN ' AND u.UserAddress LIKE N''%'+ @Address +'%'' 'ELSE ' ' END
,CASE WHEN @LocationArea IS NOT NULL THEN ' AND u.LocationArea LIKE N''%'+ @LocationArea +'%'' 'ELSE ' ' END
,CASE WHEN @Email IS NOT NULL THEN ' AND u.Email LIKE N''%'+ @Email +'%'' 'ELSE ' ' END
,CASE WHEN @UserRoleId IS NOT NULL THEN ' AND u.UserRoleId = '+ CAST(@UserRoleId as NVARCHAR(20)) +' 'ELSE ' ' END
,CASE WHEN @PositionId IS NOT NULL THEN ' AND u.PositionId = '+ CAST(@PositionId as NVARCHAR(20)) +' 'ELSE ' ' END
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(u.FirstName,u.LastName,u.FirstNameEng,u.LastNameEng,u.Phone,u.Email,cc.CalibratorAuthorityNames,u.UserAddress,u.LocationArea,dep.DepartmentNames,ps.StatusDescriptionHEB,ur.UserRoleDescriptionHEB,ss.AvailabilityStatusDescriptionHEB) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT @sql
EXEC sp_executesql @sql


END