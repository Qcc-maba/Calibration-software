-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/03/2025
-- Description:	This SP should create a calendar event for the calendar. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-167
-- =============================================

CREATE   PROCEDURE [dbo].[CreateCalendarEvent]
@EventTypeId INT,
@StartDate DATETIME2(0),
@EndDate DATETIME2(0),
@ParticipantIDs NVARCHAR(300),
@Comments NVARCHAR(255) ='',
@LoggedInUserEmail NVARCHAR(50) = NULL

--exec dbo.CreateCalendarEvent @Title ='Test event4',@StartDate = '2025-03-15 12:30:54', @EndDate = '2025-03-15 12:30:54',@ParticipantIDs = '6,7', @Comments = N'test'

AS
BEGIN

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

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

/*
if EXISTS (
SELECT 1 FROM dbo.CalendarEvents as ce
WHERE ce.EventTypeId = @EventTypeId AND ce.StartDate = @StartDate AND ce.EndDate = @EndDate AND ce.IsDeleted = 0
)
THROW 51000, 'Event already exist.', 1;*/

DECLARE @CalendarEventId INT

BEGIN TRY
	BEGIN TRANSACTION

	INSERT dbo.CalendarEvents (EventTypeId,StartDate,EndDate,Comments,UpdateUserID)
	VALUES (@EventTypeId,@StartDate,@EndDate,@Comments,@LoggedInUserId)

	SELECT @CalendarEventId = SCOPE_IDENTITY()  

	INSERT dbo.CalendarEventsToParticipants (CalendarEventId,UserId,UpdateUserID)
	SELECT DISTINCT @CalendarEventId, ParticipantId,@LoggedInUserId
	FROM #ParticipantIDs


	COMMIT
END TRY

BEGIN CATCH
ROLLBACK
END CATCH
END