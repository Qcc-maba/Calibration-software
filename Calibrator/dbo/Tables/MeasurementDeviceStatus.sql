CREATE TABLE [dbo].[MeasurementDeviceStatus] (
    [Id]        INT           IDENTITY (1, 1) NOT NULL,
    [Status]    NVARCHAR (25) NOT NULL,
    [StartDate] DATETIME2 (7) NULL,
    [EndDate]   DATETIME2 (7) NULL,
    CONSTRAINT [PK_MeasurementDeviceStatus] PRIMARY KEY CLUSTERED ([Id] ASC)
);

