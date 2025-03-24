CREATE TABLE [dbo].[CalendarEventsToParticipants] (
    [CalendarEventId] INT NOT NULL,
    [UserId]          INT NOT NULL,
    CONSTRAINT [PK_CalendarEventsToParticipants] PRIMARY KEY CLUSTERED ([CalendarEventId] ASC, [UserId] ASC)
);

