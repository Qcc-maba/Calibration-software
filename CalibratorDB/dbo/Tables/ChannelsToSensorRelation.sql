CREATE TABLE [dbo].[ChannelsToSensorRelation] (
    [SensorMeasurementDeviceId] INT             NOT NULL,
    [LoggerMeasurementDeviceId] INT             NOT NULL,
    [ChannelNumber]             INT             NOT NULL,
    [MeasurmentPointName]       NVARCHAR (50)   NULL,
    [MeasurmentPointCoordX]     DECIMAL (10, 4) NULL,
    [MeasurmentPointCoordY]     DECIMAL (10, 4) NULL,
    [CreateDate]                DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]               DATETIME2 (0)   NULL,
    [UpdateUserID]              INT             NULL,
    [IsDeleted]                 BIT             DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_ChannelsToSensorRelation] PRIMARY KEY CLUSTERED ([SensorMeasurementDeviceId] ASC, [LoggerMeasurementDeviceId] ASC, [ChannelNumber] ASC),
    CONSTRAINT [FK_ChannelsToSensorRelation_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

