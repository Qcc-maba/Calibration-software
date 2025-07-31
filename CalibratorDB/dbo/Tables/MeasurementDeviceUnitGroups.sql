CREATE TABLE [dbo].[MeasurementDeviceUnitGroups] (
    [MeasurementDeviceUnitGroupId]        INT            IDENTITY (1, 1) NOT NULL,
    [NameEn]                              NVARCHAR (50)  NOT NULL,
    [NameHe]                              NVARCHAR (50)  NOT NULL,
    [Description]                         NVARCHAR (500) NULL,
    [Symbol]                              NVARCHAR (5)   NOT NULL,
    [HelpLink]                            NVARCHAR (150) NULL,
    [CreatedDate]                         DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                         DATETIME2 (0)  NULL,
    [IsDeleted]                           BIT            DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                        INT            NULL,
    [MeasurementDevicesUnitGroupSourceId] INT            NULL,
    [MainCategoryId]                      INT            NULL,
    CONSTRAINT [PK_MeasurementDeviceUnitGroups] PRIMARY KEY CLUSTERED ([MeasurementDeviceUnitGroupId] ASC),
    CONSTRAINT [FK_MeasurementDeviceUnitGroups_MainCategoryId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_MeasurementDeviceUnitGroups_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

