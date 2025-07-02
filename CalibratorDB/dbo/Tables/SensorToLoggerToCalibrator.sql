CREATE TABLE [dbo].[SensorToLoggerToCalibrator] (
    [SensorToLoggerToCalibratorId] INT           IDENTITY (1, 1) NOT NULL,
    [LoggerToCalibratorId]         INT           NOT NULL,
    [SensorMeasurementDeviceId]    INT           NOT NULL,
    [UnitId]                       INT           NULL,
    [WorkRangeUnitId]              INT           NULL,
    [CreateDate]                   DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                  DATETIME2 (0) NULL,
    [UpdateUserID]                 INT           NULL,
    [IsDeleted]                    BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_SensorToLoggerToCalibratorId] PRIMARY KEY NONCLUSTERED ([SensorToLoggerToCalibratorId] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_SensorToLoggerToCalibrator_UnitId] FOREIGN KEY ([UnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_SensorToLoggerToCalibrator_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_SensorToLoggerToCalibrator_WorkRangeUnitId] FOREIGN KEY ([WorkRangeUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId])
);


GO
CREATE UNIQUE CLUSTERED INDEX [IDX_NC_SensorToLoggerToCalibrator]
    ON [dbo].[SensorToLoggerToCalibrator]([LoggerToCalibratorId] ASC, [SensorMeasurementDeviceId] ASC);

