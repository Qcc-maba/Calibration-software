CREATE   PROCEDURE dbo.EditCalendarEvent
@ID INT,
@Title NVARCHAR(300),
@StartDate DATETIME2(0),
@EndDate DATETIME2(0),
@ParticipantIDs NVARCHAR(300),
@Comments NVARCHAR(255)
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
SELECT * FROM #ParticipantIDs as u
LEFT JOIN [dbo].[Users] as ul ON u.ParticipantId = ul.ID
WHERE ul.ID IS NULL OR ul.IsActive = 0
)
THROW 51000, 'Incorrect or inactive user were found in list.', 1;

if NOT EXISTS (
SELECT 1 FROM dbo.CalendarEvents as ce
WHERE ce.CalendarEventId = @ID
)
THROW 51000, 'Event not exist.', 1;

DECLARE @CalendarEventId INT

BEGIN TRANSACTION

UPDATE dbo.CalendarEvents 
SET Title = @Title,StartDate = @StartDate,EndDate = @EndDate , Comments = @Comments
WHERE CalendarEventId = @ID

DELETE dbo.CalendarEventsToParticipants 
WHERE CalendarEventId = @ID

INSERT dbo.CalendarEventsToParticipants (CalendarEventId,UserId)
SELECT DISTINCT @ID, ParticipantId
FROM #ParticipantIDs

COMMIT

END