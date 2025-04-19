CREATE TABLE [dbo].[CalendarEvents] (
    [CalendarEventId]    INT            IDENTITY (1, 1) NOT NULL,
    [Title]              NVARCHAR (300) NOT NULL,
    [StartDate]          DATETIME2 (0)  NOT NULL,
    [EndDate]            DATETIME2 (0)  NOT NULL,
    [Comments]           NVARCHAR (255) NULL,
    [CreatedDate]        DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]        DATETIME2 (0)  NULL,
    [IsDeleted]          BIT            DEFAULT ((0)) NOT NULL,
    [UpdateUserID]       INT            NULL,
    [AWSCalendarEventId] INT            NULL,
    PRIMARY KEY CLUSTERED ([CalendarEventId] ASC),
    CONSTRAINT [FK_CalendarEvents_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

