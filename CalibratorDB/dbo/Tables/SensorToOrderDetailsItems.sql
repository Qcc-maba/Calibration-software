CREATE TABLE [dbo].[SensorToOrderDetailsItems] (
    [SensorToOrderDetailsItemsId] INT             IDENTITY (1, 1) NOT NULL,
    [OrderDetailsItemId]          INT             NULL,
    [LoggerMeasurementDeviceId]   INT             NOT NULL,
    [SensorMeasurementDeviceId]   INT             NOT NULL,
    [MeasurmentPointName]         NVARCHAR (100)  NOT NULL,
    [MeasurmentPointCoordX]       DECIMAL (10, 4) NOT NULL,
    [MeasurmentPointCoordY]       DECIMAL (10, 4) NOT NULL,
    [ChannelNumber]               INT             NOT NULL,
    [PrimaryMeasurmentUnitId]     INT             NULL,
    [SecondaryMeasurmentUnitId]   INT             NULL,
    [CreateDate]                  DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                 DATETIME2 (0)   NULL,
    [UpdateUserID]                INT             NULL,
    [IsDeleted]                   BIT             DEFAULT ((0)) NOT NULL,
    CONSTRAINT [FK_SensorToOrderDetailsItems_LoggerMeasurementDeviceId] FOREIGN KEY ([LoggerMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_SensorToOrderDetailsItems_PrimaryMeasurmentUnitId] FOREIGN KEY ([PrimaryMeasurmentUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_SensorToOrderDetailsItems_SecondaryMeasurmentUnitId] FOREIGN KEY ([SecondaryMeasurmentUnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_SensorToOrderDetailsItems_SensorMeasurementDeviceId] FOREIGN KEY ([SensorMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_SensorToOrderDetailsItems_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);


GO
CREATE UNIQUE CLUSTERED INDEX [CI_SensorToOrderDetailsItems]
    ON [dbo].[SensorToOrderDetailsItems]([OrderDetailsItemId] ASC, [SensorToOrderDetailsItemsId] ASC);

