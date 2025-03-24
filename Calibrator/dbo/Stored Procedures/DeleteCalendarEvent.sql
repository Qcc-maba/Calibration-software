-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 21/03/2025
-- Description:	This SP should delete a calendar event.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-190
-- =============================================
CREATE   PROCEDURE dbo.DeleteCalendarEvent
@CalendarEventId INT
/*
EXEC dbo.DeleteCalendarEvent  @CalendarEventId = 1
*/

AS

BEGIN

IF NOT EXISTS
(
SELECT 1 
FROM [dbo].[CalendarEvents]
WHERE CalendarEventId = @CalendarEventId
)
THROW 51000, 'Calendar even don''t exist .', 1;

DELETE FROM [dbo].[CalendarEvents]
WHERE CalendarEventId = @CalendarEventId

END
