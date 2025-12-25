CREATE TABLE [stg].[stg_MeasurementDevicesCorrections] (
    [RangeStart]                            NUMERIC (18, 6) NULL,
    [RangeStop]                             NUMERIC (18, 6) NULL,
    [Value]                                 NVARCHAR (300)  NULL,
    [DateAdded]                             DATETIME        NULL,
    [CorVersion]                            INT             NULL,
    [MabaID]                                NVARCHAR (50)   NULL,
    [MeasurementNameEn]                     NVARCHAR (100)  NULL,
    [MeasurementNameHe]                     NVARCHAR (100)  NULL,
    [ShortNameEn]                           NVARCHAR (10)   NULL,
    [LongNameEn]                            NVARCHAR (100)  NULL,
    [ShortNameHe]                           NVARCHAR (50)   NULL,
    [LongNameHe]                            NVARCHAR (100)  NULL,
    [DepartmentHeb]                         NVARCHAR (50)   NULL,
    [MeasurementDevicesCorrectionsSourceId] INT             NULL
);

