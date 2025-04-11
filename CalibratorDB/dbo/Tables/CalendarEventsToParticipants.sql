CREATE TABLE [dbo].[CalendarEventsToParticipants] (
    [CalendarEventId] INT           NOT NULL,
    [UserId]          INT           NOT NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]     DATETIME2 (0) NULL,
    [IsDeleted]       BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]    INT           NULL,
    CONSTRAINT [PK_CalendarEventsToParticipants] PRIMARY KEY CLUSTERED ([CalendarEventId] ASC, [UserId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_CalendarEventsToParticipants_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

