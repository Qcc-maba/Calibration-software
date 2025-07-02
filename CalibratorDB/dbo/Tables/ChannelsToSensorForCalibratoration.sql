CREATE TABLE [dbo].[ChannelsToSensorForCalibratoration] (
    [SensorToLoggerToCalibratorId] INT             NOT NULL,
    [ChannelNumber]                INT             NOT NULL,
    [OrderDetailsItemId]           INT             NULL,
    [MeasurmentPointName]          NVARCHAR (50)   NULL,
    [MeasurmentPointCoordX]        DECIMAL (10, 4) NULL,
    [MeasurmentPointCoordY]        DECIMAL (10, 4) NULL,
    [CreateDate]                   DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                  DATETIME2 (0)   NULL,
    [UpdateUserID]                 INT             NULL,
    [IsDeleted]                    BIT             DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_ChannelsToSensorForCalibratoration] PRIMARY KEY CLUSTERED ([SensorToLoggerToCalibratorId] ASC, [ChannelNumber] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_ChannelsToSensorForCalibratoration_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

