CREATE TABLE [dbo].[CalendarEvents] (
    [CalendarEventId] INT            IDENTITY (1, 1) NOT NULL,
    [Title]           NVARCHAR (300) NOT NULL,
    [StartDate]       DATETIME2 (0)  NOT NULL,
    [EndDate]         DATETIME2 (0)  NOT NULL,
    [Comments]        NVARCHAR (255) NULL,
    PRIMARY KEY CLUSTERED ([CalendarEventId] ASC)
);

