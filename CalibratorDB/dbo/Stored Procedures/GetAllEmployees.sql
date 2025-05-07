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
    @UserRoleIds NVARCHAR(500)  = NULL,
	@UserStatusIds NVARCHAR(50) = NULL,
	@DepartmentIdsList nvarchar(max) = NULL,
	@CertificationIds NVARCHAR(MAX) = NULL,
	@EventStartDate DATETIME2(0) = NULL,
    @EventEndDate DATETIME2(0) = NULL
AS
BEGIN

	IF @OrderBy NOT IN 
	(N'FirstName', N'LastName', N'FirstNameEng', N'LastNameEng', N'Phone', N'Email', N'UserAddress', N'LocationArea', N'UserRoleENG', N'UserRoleHEB', N'DepartmentNames', N'Certification',N'Stamp')
	THROW 51000, 'Incorrect value for parameter @OrderBy. Available values FirstName|LastName|FirstNameEng|LastNameEng|Phone|Email|UserAddress|LocationArea|UserRoleENG|UserRoleHEB|DepartmentNames|Certification|Stamp', 1;


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
IsActive BIT
)
INSERT #Status(StatusId,IsActive)
SELECT 
  s.StatusId,
  IIF(s.StatusDescriptionENG='Active',1,0) as IsActive
  FROM [dbo].[Statuses] as s
  JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG = 'UserStatus'

DROP TABLE IF EXISTS #UserRoleIds
CREATE TABLE #UserRoleIds
(
UserId INT
)

INSERT #UserRoleIds(UserId)
--Insert users filtered by provided @UserRoleIds
SELECT DISTINCT ur.UserId 
FROM dbo.ParseCSVToTable(@UserRoleIds) as v
JOIN [dbo].[UsersToUserRoles] as ur ON v.Value = ur.UserRoleId
WHERE ur.IsDeleted = 0

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
JOIN dbo.UsersToDepartments as ud ON v.Value = ud.DepartmentId
WHERE ud.IsDeleted = 0
--Insert users filtered by provided @CertificationIds

DROP TABLE IF EXISTS #CertificationUserIds
CREATE TABLE #CertificationUserIds
(
UserId INT
)

INSERT #CertificationUserIds(UserId)
SELECT DISTINCT c.CalibratorId as UserId 
FROM dbo.ParseCSVToTable(@CertificationIds) as v
JOIN dbo.CalibratorsToCertification as c ON v.Value = c.CertificationId
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
	StatusDescriptionHEB NVARCHAR(255),
	StatusDescriptionENG NVARCHAR(255)
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
	JOIN [dbo].[CalendarEventsToParticipants] as cetp ON ce.CalendarEventId = cetp.CalendarEventId
	JOIN [dbo].[Statuses] as s ON ce.EventTypeId = s.StatusId
	WHERE ce.StartDate >= @EventStartDate AND ce.EndDate <= @EventEndDate
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
	   ur.UserRoleENG,	
	   ur.UserRoleHEB,
	   dep.DepartmentIds,
	   dep.DepartmentNames,
	   cc.Certification,
	   ur.UserRoleIds,
	   cc.CertificationIds,
	   u.Stamp,
	   u.Password,
	   u.IsActive,
	   ss.StatusId,
	   '
	   ,IIF(@EventStartDate IS NOT NULL AND @EventEndDate IS NOT NULL,'ace.EventTypeId, ace.StatusDescriptionHEB , ace.StatusDescriptionENG,  ',' '),
	   '
	   COUNT(1) OVER(PARTITION BY 1 ORDER BY u.ID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
FROM [dbo].[Users] as u
JOIN #Status as ss ON u.IsActive = ss.IsActive
'
,IIF(@UserRoleIds IS NOT NULL,' JOIN #UserRoleIds as uf1 ON u.ID =  uf1.UserId ',' ')
,IIF(@UserStatusIds IS NOT NULL,' JOIN #UserStatusesIds as uf2 ON u.ID =  uf2.UserId ',' ')
,IIF(@DepartmentIdsList IS NOT NULL,' JOIN #DepartmentUserIds as uf3 ON u.ID =  uf3.UserId ',' ')
,IIF(@CertificationIds IS NOT NULL,' JOIN #CertificationUserIds as uf4 ON u.ID =  uf4.UserId ',' ')
,IIF(@FirstName IS NOT NULL OR @LastName IS NOT NULL,' JOIN #UserFullName  as f ON u.ID =  f.UserId ',' ')
,IIF(@EventStartDate IS NOT NULL AND @EventEndDate IS NOT NULL,' LEFT JOIN #AssociatedCalendarEvents as ace ON u.ID =  ace.UserId ',' '),
'LEFT JOIN
(
SELECT utr.UserId, 
       STRING_AGG(ur.UserRoleId,'','') as UserRoleIds,
	   STRING_AGG(LTRIM(RTRIM(ur.UserRoleDescriptionENG)),'', '') AS UserRoleENG,	
	   STRING_AGG(LTRIM(RTRIM(ur.UserRoleDescriptionHEB)),'', '') AS UserRoleHEB
FROM [dbo].[UsersToUserRoles] as utr 
JOIN [dbo].[UserRoles] as ur ON utr.UserRoleId = ur.UserRoleId
WHERE utr.IsDeleted = 0 
GROUP BY utr.UserId
) AS ur ON u.ID = ur.UserId
LEFT JOIN
(
SELECT ctc.CalibratorId as UserId,
	   STRING_AGG(cc.ID,'','') as CertificationIds,
	   STRING_AGG(cc.Certificate,'','') as Certification
FROM [dbo].[CalibratorsToCertification] as ctc
JOIN [dbo].[CalibratorsCertifications] as cc ON ctc.CertificationId = cc.ID AND cc.IsDeleted = 0
WHERE ctc.IsDeleted = 0
GROUP BY ctc.CalibratorId
) as cc ON u.ID = cc.UserId
LEFT JOIN
(
SELECT ud.UserId, 
STRING_AGG(ud.DepartmentId,'','') as DepartmentIds,
STRING_AGG(d.DepartmentName,'','') as DepartmentNames
FROM [dbo].[UsersToDepartments] as ud
LEFT JOIN [dbo].[Departments] as d ON ud.DepartmentId = d.ID
WHERE ud.IsDeleted = 0
GROUP BY ud.UserId
) as dep ON u.ID = dep.UserId
WHERE u.ID > 0 
'
,CASE WHEN @Phone IS NOT NULL THEN ' AND u.Phone LIKE N''%'+ @Phone +'%'' 'ELSE ' ' END
,CASE WHEN @Address IS NOT NULL THEN ' AND u.UserAddress LIKE N''%'+ @Address +'%'' 'ELSE ' ' END
,CASE WHEN @LocationArea IS NOT NULL THEN ' AND u.LocationArea LIKE N''%'+ @LocationArea +'%'' 'ELSE ' ' END
,CASE WHEN @Email IS NOT NULL THEN ' AND u.Email LIKE N''%'+ @Email +'%'' 'ELSE ' ' END
,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT @sql
EXEC sp_executesql @sql


END