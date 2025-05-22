-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-183
-- =============================================
CREATE   PROCEDURE [dbo].[GetCalendarEvents]
@StartDate DATE,
@EndDate DATE,
@RowsPerPage INT = 50,
@PageNumber INT = 1,
@OrderBy NVARCHAR(255) = N'StartDate',-- Only this list of valid values for parameter Title|StartDate|EndDate
@OrderByAsc BIT = 1,
@LoggedInUserEmail NVARCHAR(50) = NULL

/*
EXEC  dbo.GetCalendarEvents
@StartDate ='2020-04-18 14:00:28.230',
@EndDate ='2026-04-19 14:00:37.017',
@RowsPerPage  = 100,
@PageNumber = 1,
@OrderBy  = N'StartDate',-- Only this list of valid values for parameter Title|StartDate|EndDate
@OrderByAsc  = 1
*/

AS

DECLARE @Userid INT = 0

IF @LoggedInUserEmail IS NOT NULL
BEGIN
	SELECT TOP 1 @Userid = ID FROM dbo.Users as u
	JOIN [dbo].[UsersToDepartments] as d ON u.ID = d.UserId
	WHERE u.Email = @LoggedInUserEmail

	DROP TABLE IF EXISTS #CalendarEventFilteredByDepartment
	CREATE TABLE #CalendarEventFilteredByDepartment
	(
	CalendarEventId INT
	)
	INSERT #CalendarEventFilteredByDepartment(CalendarEventId)
	SELECT DISTINCT ce.CalendarEventId
	FROM [dbo].[CalendarEvents] as ce
	JOIN [dbo].[CalendarEventsToParticipants] as cetp ON ce.CalendarEventId = cetp.CalendarEventId and cetp.IsDeleted = 0
	JOIN [dbo].[Users] as u ON cetp.UserId = u.ID AND u.IsActive = 1
	JOIN [dbo].[UsersToDepartments] as ud ON u.ID = ud.UserId and cetp.IsDeleted = 0
	WHERE ce.IsDeleted = 0 AND ud.DepartmentId IN
	(
	SELECT d.DepartmentId FROM [dbo].[UsersToDepartments] as d
	WHERE d.UserId = @Userid
	)
END


IF @OrderBy NOT IN (N'EventTypeId',N'StartDate',N'EndDate')
THROW 51000, 'Incorrect value for parameter @OrderBy.', 1;

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
' SELECT ce.CalendarEventId, ce.EventTypeId, ss.StatusDescriptionENG AS TitleENG, ss.StatusDescriptionHEB as TitleHEB, ce.StartDate, ce.EndDate, ce.Comments,
    COALESCE(STRING_AGG(p.UserId,'', ''),'''') as ParticipantsIds, 
	ce.UpdateUserID as CreatedByUserId
    FROM dbo.CalendarEvents AS ce
	JOIN [dbo].[Statuses] as ss ON ce.EventTypeId = ss.StatusId
	LEFT JOIN dbo.CalendarEventsToParticipants as p ON ce.CalendarEventId = p.CalendarEventId and p.IsDeleted = 0'
     ,CASE WHEN @Userid <> 0 THEN ' JOIN #CalendarEventFilteredByDepartment as f ON ce.CalendarEventId = f.CalendarEventId ' ELSE ' ' END,
    'WHERE ce.IsDeleted = 0 AND
	ce.StartDate >= ''',@StartDate,''' AND ce.StartDate <= ''',@EndDate,'''
	GROUP BY ce.CalendarEventId,ce.EventTypeId, ss.StatusDescriptionENG , ss.StatusDescriptionHEB ,ce.StartDate, ce.EndDate, ce.Comments,ce.UpdateUserID
    ORDER BY ' + QUOTENAME(@OrderBy) + CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END + '
    OFFSET ',(@PageNumber -1) * @RowsPerPage,' ROWS FETCH NEXT ', @RowsPerPage ,'ROWS ONLY; ')
PRINT @sql
EXEC sp_executesql @sql