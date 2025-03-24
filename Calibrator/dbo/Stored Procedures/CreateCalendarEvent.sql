-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/03/2025
-- Description:	This SP should create a calendar event for the calendar. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-167
-- =============================================

CREATE   PROCEDURE dbo.CreateCalendarEvent
@Title NVARCHAR(300),
@StartDate DATETIME2(0),
@EndDate DATETIME2(0),
@ParticipantIDs NVARCHAR(300),
@Comments NVARCHAR(255) =''

--exec dbo.CreateCalendarEvent @Title ='Test event4',@StartDate = '2025-03-15 12:30:54', @EndDate = '2025-03-15 12:30:54',@ParticipantIDs = '6,7', @Comments = N'test'

AS
BEGIN

DROP TABLE IF EXISTS #ParticipantIDs
CREATE TABLE #ParticipantIDs
(
ParticipantId INT
)

INSERT #ParticipantIDs(ParticipantId)
SELECT Value FROM dbo.ParseCSVToTable(@ParticipantIDs)

--- Check if all users are valid
if EXISTS (
SELECT 1 FROM #ParticipantIDs as u
LEFT JOIN [dbo].[Users] as ul ON u.ParticipantId = ul.ID
WHERE ul.ID IS NULL OR ul.IsActive = 0
)
THROW 51000, 'Incorrect or inactive user were found in list.', 1;


if EXISTS (
SELECT 1 FROM dbo.CalendarEvents as ce
WHERE ce.Title	= @Title AND ce.StartDate = @StartDate AND ce.EndDate = @EndDate
)
THROW 51000, 'Event already exist.', 1;

DECLARE @CalendarEventId INT

BEGIN TRANSACTION

INSERT dbo.CalendarEvents (Title,StartDate,EndDate,Comments)
VALUES (@Title,@StartDate,@EndDate,@Comments)

SELECT @CalendarEventId = SCOPE_IDENTITY()  

INSERT dbo.CalendarEventsToParticipants (CalendarEventId,UserId)
SELECT DISTINCT @CalendarEventId, ParticipantId
FROM #ParticipantIDs


COMMIT

END


