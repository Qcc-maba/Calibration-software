CREATE TABLE [etl].[CalendarEvents] (
    [CalendarEventId]    INT            NOT NULL,
    [EventTypeId]        INT            NOT NULL,
    [StartDate]          DATETIME2 (0)  NOT NULL,
    [EndDate]            DATETIME2 (0)  NOT NULL,
    [Comments]           NVARCHAR (255) NULL,
    [CreatedDate]        DATETIME2 (0)  NOT NULL,
    [UpdatedDate]        DATETIME2 (0)  NULL,
    [IsDeleted]          BIT            NOT NULL,
    [UpdateUserID]       INT            NULL,
    [AWSCalendarEventId] INT            NULL
);

