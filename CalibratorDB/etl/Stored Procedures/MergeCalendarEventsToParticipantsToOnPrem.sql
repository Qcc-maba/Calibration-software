CREATE PROCEDURE [etl].[MergeCalendarEventsToParticipantsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEventsToParticipants] AS dest
USING (
	SELECT 
	     ce.[CalendarEventId]
		,u1.ID as [UserId]
		,ctp.[CreatedDate]
		,ctp.[UpdatedDate]
		,ctp.[IsDeleted]
		,u2.ID as [UpdateUserID]
	FROM [etl].[CalendarEventsToParticipants] as ctp
	JOIN [dbo].[CalendarEvents] as ce ON ce.AWSCalendarEventId = ctp.[CalendarEventId]
	LEFT JOIN [dbo].[Users] as u1 ON u1.AWSID = ctp.[UserId]
	LEFT JOIN [dbo].[Users] as u2 ON u2.AWSID = ctp.[UpdateUserID]
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