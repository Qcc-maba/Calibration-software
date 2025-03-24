CREATE TABLE [dbo].[MeasurementDevicesMainClasses] (
    [Id]            INT            IDENTITY (1, 1) NOT NULL,
    [NameHebrew]    NVARCHAR (255) NULL,
    [NameEnglish]   NVARCHAR (255) NULL,
    [CreatedTime]   DATETIME       NULL,
    [UpdatedTime]   DATETIME       NULL,
    [CreatedUserId] INT            NULL,
    [UpdatedUserId] INT            NULL,
    CONSTRAINT [PK_MeasurementDevicesMainClasses] PRIMARY KEY CLUSTERED ([Id] ASC)
);

