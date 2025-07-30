CREATE TABLE [dbo].[MeasurmentDeviceToOrderDetailsItems] (
    [MeasurmentDeviceToOrderDetailsItemId] INT           IDENTITY (1, 1) NOT NULL,
    [OrderDetailsItemId]                   INT           NULL,
    [LoggerMeasurementDeviceId]            INT           NOT NULL,
    [SensorMeasurementDeviceId]            INT           NOT NULL,
    [PrimaryMeasurmentUnitId]              INT           NULL,
    [SecondaryMeasurmentUnitId]            INT           NULL,
    [CreateDate]                           DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                          DATETIME2 (0) NULL,
    [UpdateUserID]                         INT           NULL,
    [IsDeleted]                            BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [FK_MeasurmentDeviceToOrderDetailsItems_LoggerMeasurementDeviceId] FOREIGN KEY ([LoggerMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_MeasurmentDeviceToOrderDetailsItems_PrimaryMeasurmentUnitId] FOREIGN KEY ([PrimaryMeasurmentUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_MeasurmentDeviceToOrderDetailsItems_SecondaryMeasurmentUnitId] FOREIGN KEY ([SecondaryMeasurmentUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_MeasurmentDeviceToOrderDetailsItems_SensorMeasurementDeviceId] FOREIGN KEY ([SensorMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_MeasurmentDeviceToOrderDetailsItems_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

