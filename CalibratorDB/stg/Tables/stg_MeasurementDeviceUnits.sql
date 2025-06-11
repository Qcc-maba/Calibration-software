CREATE TABLE [stg].[stg_MeasurementDeviceUnits] (
    [ShortNameEn]                   NVARCHAR (10)  NOT NULL,
    [ShortNameEnAsc]                NVARCHAR (50)  NOT NULL,
    [LongNameEn]                    NVARCHAR (100) NOT NULL,
    [ShortNameHeAsc]                NVARCHAR (50)  NOT NULL,
    [ShortNameHe]                   NVARCHAR (50)  NOT NULL,
    [LongNameHe]                    NVARCHAR (100) NOT NULL,
    [MeasurementDeviceUnitGroupId]  INT            NOT NULL,
    [Note]                          NVARCHAR (500) NULL,
    [MeasurementDeviceUnitSourceId] INT            NULL
);

