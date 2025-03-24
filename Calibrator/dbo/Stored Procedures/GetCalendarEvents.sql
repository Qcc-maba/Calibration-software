-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-183
-- =============================================
CREATE   PROCEDURE dbo.GetCalendarEvents
@StartDate DATE,
@EndDate DATE,
@RowsPerPage INT = 50,
@PageNumber INT = 1,
@OrderBy NVARCHAR(9) = N'StartDate',-- Only this list of valid values for parameter Title|StartDate|EndDate
@OrderByAsc BIT = 1

/*
EXEC  dbo.GetCalendarEvents
@StartDate ='2025-03-13 14:00:28.230',
@EndDate ='2025-03-16 14:00:37.017',
@RowsPerPage  = 100,
@PageNumber = 1,
@OrderBy  = N'Title',-- Only this list of valid values for parameter Title|StartDate|EndDate
@OrderByAsc  = 1
*/

AS

IF @OrderBy NOT IN (N'Title',N'StartDate',N'EndDate')
THROW 51000, 'Incorrect value for parameter @OrderBy.', 1;

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
' SELECT ce.CalendarEventId, ce.Title, ce.StartDate, ce.EndDate, ce.Comments,
    STRING_AGG(p.UserId,'', '') as ParticipantsIds/*, STRING_AGG(CONCAT(u.FirstName,'' '',u.LastName),'', '') as ParticipantsFullNames */
    FROM dbo.CalendarEvents AS ce
	JOIN dbo.CalendarEventsToParticipants as p ON ce.CalendarEventId = p.CalendarEventId
	/*JOIN dbo.Users as u ON p.UserId = u.ID*/
    WHERE ce.StartDate >= ''',@StartDate,''' AND ce.StartDate <= ''',@EndDate,'''
	GROUP BY ce.CalendarEventId,ce.Title, ce.StartDate, ce.EndDate, ce.Comments
    ORDER BY ' + QUOTENAME(@OrderBy) + CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END + '
    OFFSET ',(@PageNumber -1) * @RowsPerPage,' ROWS FETCH NEXT ', @RowsPerPage ,'ROWS ONLY; ')
PRINT @sql
EXEC sp_executesql @sql

