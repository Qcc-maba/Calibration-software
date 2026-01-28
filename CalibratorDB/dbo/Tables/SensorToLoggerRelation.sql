CREATE TABLE [dbo].[SensorToLoggerRelation] (
    [SensorMeasurementDeviceId] INT           NOT NULL,
    [LoggerMeasurementDeviceId] INT           NOT NULL,
    [CreateDate]                DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]               DATETIME2 (0) NULL,
    [UpdateUserID]              INT           NULL,
    [IsDeleted]                 BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_SensorToLoggerRelationId] PRIMARY KEY NONCLUSTERED ([LoggerMeasurementDeviceId] ASC, [SensorMeasurementDeviceId] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_SensorToLoggerRelation_LoggerMeasurementDeviceId] FOREIGN KEY ([LoggerMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_SensorToLoggerRelation_SensorMeasurementDeviceId] FOREIGN KEY ([SensorMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_SensorToLoggerRelation_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

