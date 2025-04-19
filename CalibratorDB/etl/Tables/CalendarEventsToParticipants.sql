CREATE TABLE [etl].[CalendarEventsToParticipants] (
    [CalendarEventId] INT           NOT NULL,
    [UserId]          INT           NOT NULL,
    [CreatedDate]     DATETIME2 (0) NOT NULL,
    [UpdatedDate]     DATETIME2 (0) NULL,
    [IsDeleted]       BIT           NOT NULL,
    [UpdateUserID]    INT           NULL
);

