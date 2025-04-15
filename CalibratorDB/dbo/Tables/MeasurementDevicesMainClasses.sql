CREATE TABLE [dbo].[MeasurementDevicesMainClasses] (
    [Id]            INT            IDENTITY (1, 1) NOT NULL,
    [NameHebrew]    NVARCHAR (255) NULL,
    [NameEnglish]   NVARCHAR (255) NULL,
    [CreatedTime]   DATETIME       NULL,
    [UpdatedTime]   DATETIME       NULL,
    [UpdatedUserId] INT            NULL,
    [IsDeleted]     BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_MeasurementDevicesMainClasses] PRIMARY KEY CLUSTERED ([Id] ASC)
);

