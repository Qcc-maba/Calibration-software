CREATE TABLE [dbo].[CalibrationEnvironmentalConditions] (
    [OrderDetailsItemId]      INT             NOT NULL,
    [MeasurementDeviceUnitId] INT             NOT NULL,
    [NominalValue]            DECIMAL (18, 6) NULL,
    [Tolerance]               DECIMAL (18, 6) NULL,
    [CreateDate]              DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]             DATETIME2 (0)   NULL,
    [UpdateUserID]            INT             NULL,
    [IsDeleted]               BIT             DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([OrderDetailsItemId] DESC, [MeasurementDeviceUnitId] ASC),
    CONSTRAINT [FK_CalibrationEnvironmentalConditions_MeasurementDeviceUnitId] FOREIGN KEY ([MeasurementDeviceUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId])
);

