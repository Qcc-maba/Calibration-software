CREATE PROCEDURE [etl].[MergeCalendarEventsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEvents] AS dest
USING (
	SELECT [CalendarEventId]
		,[EventTypeId]
		,[StartDate]
		,[EndDate]
		,[Comments]
		,[CreatedDate]
		,[UpdatedDate]
		,[IsDeleted]
		,0 as [UpdateUserID]
		,[AWSCalendarEventId]
	FROM [etl].[CalendarEvents]
	) AS source
	ON dest.AWSCalendarEventId = source.CalendarEventId
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[EventTypeId] = source.[EventTypeId]
			,dest.[StartDate] = source.[StartDate]
			,dest.[EndDate] = source.[EndDate]
			,dest.[Comments] = source.[Comments]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [EventTypeId]
			,[StartDate]
			,[EndDate]
			,[Comments]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			,[AWSCalendarEventId]
			)
		VALUES (
			 source.[EventTypeId]
			,source.[StartDate]
			,source.[EndDate]
			,source.[Comments]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			,source.[CalendarEventId]
			);