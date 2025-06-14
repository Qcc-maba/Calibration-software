CREATE TABLE [stg].[stg_MeasurementDevicesCorrections] (
    [Value1]                                NUMERIC (18, 6) NULL,
    [Value2]                                NUMERIC (18, 6) NULL,
    [Note]                                  NVARCHAR (300)  NULL,
    [MeasurementDevicesId]                  INT             NULL,
    [MeasurementId]                         INT             NULL,
    [UnitID]                                INT             NULL,
    [CorVersion]                            INT             NULL,
    [Department]                            NVARCHAR (50)   NULL,
    [Equation]                              NVARCHAR (300)  NULL,
    [MeasurementDevicesCorrectionsSourceId] INT             NULL
);

