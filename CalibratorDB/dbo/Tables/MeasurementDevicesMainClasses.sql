CREATE TABLE [dbo].[MeasurementDevicesMainClasses] (
    [Id]                                  INT            IDENTITY (1, 1) NOT NULL,
    [NameHebrew]                          NVARCHAR (255) NULL,
    [NameEnglish]                         NVARCHAR (255) NULL,
    [CreatedTime]                         DATETIME2 (0)  CONSTRAINT [df_CreatedTime] DEFAULT (getdate()) NULL,
    [UpdatedTime]                         DATETIME2 (0)  NULL,
    [UpdateUserID]                        INT            NULL,
    [IsDeleted]                           BIT            DEFAULT ((0)) NOT NULL,
    [MeasurementDevicesMainClassSourceId] INT            NULL,
    CONSTRAINT [PK_MeasurementDevicesMainClasses] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_MeasurementDevicesMainClasses_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

