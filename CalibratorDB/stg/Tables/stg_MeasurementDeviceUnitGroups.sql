CREATE TABLE [stg].[stg_MeasurementDeviceUnitGroups] (
    [NameEn]                              NVARCHAR (50)  NOT NULL,
    [NameHe]                              NVARCHAR (50)  NOT NULL,
    [Description]                         NVARCHAR (500) NULL,
    [Symbol]                              NVARCHAR (5)   NOT NULL,
    [HelpLink]                            NVARCHAR (150) NULL,
    [MeasurementDevicesUnitGroupSourceId] INT            NULL
);

