CREATE TABLE [dbo].[MeasurementDeviceUnits] (
    [MeasurementDeviceUnitId]       INT            IDENTITY (1, 1) NOT NULL,
    [ShortNameEn]                   NVARCHAR (10)  NOT NULL,
    [ShortNameEnAsc]                NVARCHAR (50)  NOT NULL,
    [LongNameEn]                    NVARCHAR (100) NOT NULL,
    [ShortNameHeAsc]                NVARCHAR (50)  NOT NULL,
    [ShortNameHe]                   NVARCHAR (50)  NOT NULL,
    [LongNameHe]                    NVARCHAR (100) NOT NULL,
    [MeasurementDeviceUnitGroupId]  INT            NOT NULL,
    [Note]                          NVARCHAR (500) NULL,
    [MeasurementDeviceUnitSourceId] INT            NULL,
    [CreatedDate]                   DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                   DATETIME2 (0)  NULL,
    [IsDeleted]                     BIT            DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                  INT            NULL,
    [MainCategoryId]                INT            NULL,
    CONSTRAINT [PK_MeasurementDeviceUnits] PRIMARY KEY CLUSTERED ([MeasurementDeviceUnitId] ASC),
    CONSTRAINT [FK_MeasurementDeviceUnits_MainCategoryId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_MeasurementDeviceUnits_MeasurementDeviceUnitGroups] FOREIGN KEY ([MeasurementDeviceUnitGroupId]) REFERENCES [dbo].[MeasurementDeviceUnitGroups] ([MeasurementDeviceUnitGroupId]),
    CONSTRAINT [FK_MeasurementDeviceUnits_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

