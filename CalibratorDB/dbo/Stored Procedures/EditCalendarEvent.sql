CREATE   PROCEDURE [dbo].[EditCalendarEvent]
@ID INT,
@Title NVARCHAR(300),
@StartDate DATETIME2(0),
@EndDate DATETIME2(0),
@ParticipantIDs NVARCHAR(MAX),
@Comments NVARCHAR(255)
AS
BEGIN

DROP TABLE IF EXISTS #ParticipantIDs
CREATE TABLE #ParticipantIDs
(
ParticipantId INT,
CalendarEventId INT
)

INSERT #ParticipantIDs(ParticipantId,CalendarEventId)
SELECT Value, @ID FROM dbo.ParseCSVToTable(@ParticipantIDs)
WHERE LEN(Value) > 0
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


BEGIN TRANSACTION

UPDATE dbo.CalendarEvents 
SET Title = @Title,StartDate = @StartDate,EndDate = @EndDate , Comments = @Comments,
    UpdatedDate = GETDATE()
WHERE CalendarEventId = @ID

UPDATE ctp 
SET IsDeleted = 1
FROM dbo.CalendarEventsToParticipants as ctp
LEFT JOIN #ParticipantIDs as p ON ctp.UserId = p.ParticipantId
WHERE ctp.CalendarEventId = @ID AND p.ParticipantId IS NULL and ctp.IsDeleted = 0

INSERT dbo.CalendarEventsToParticipants (CalendarEventId,UserId)
SELECT DISTINCT p.CalendarEventId, p.ParticipantId 
FROM #ParticipantIDs as p 
LEFT JOIN dbo.CalendarEventsToParticipants as ctp ON ctp.UserId = p.ParticipantId 
												  AND p.CalendarEventId = ctp.CalendarEventId
												  AND ctp.IsDeleted = 0
WHERE ctp.UserId IS NULL

COMMIT

END