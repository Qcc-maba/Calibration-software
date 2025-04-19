CREATE PROCEDURE etl.MergeCalendarEventsToParticipantsToOnPrem
AS
MERGE INTO [dbo].[CalendarEventsToParticipants] AS dest
USING (
	SELECT [CalendarEventId]
		,[UserId]
		,[CreatedDate]
		,[UpdatedDate]
		,[IsDeleted]
		,[UpdateUserID]
	FROM [etl].[CalendarEventsToParticipants]
	) AS source
	ON dest.[CalendarEventId] = source.[CalendarEventId] AND
	   dest.[UserId] = source.[UserId] AND
	   dest.[CreatedDate] = source.[CreatedDate] 
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[CalendarEventId]
			,[UserId]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			)
		VALUES (
			source.[CalendarEventId]
			,source.[UserId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			);