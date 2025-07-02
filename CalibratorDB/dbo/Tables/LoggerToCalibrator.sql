CREATE TABLE [dbo].[LoggerToCalibrator] (
    [AssignedCalibratorId]      INT            NOT NULL,
    [LoggerToCalibratorId]      INT            IDENTITY (1, 1) NOT NULL,
    [FlowRate]                  NVARCHAR (20)  NOT NULL,
    [Interval]                  INT            NOT NULL,
    [LoggerMeasurementDeviceId] INT            NOT NULL,
    [CommunicationProtocol]     NVARCHAR (100) NOT NULL,
    [CommunicationDetails]      NVARCHAR (100) NOT NULL,
    [CreateDate]                DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]               DATETIME2 (0)  NULL,
    [UpdateUserID]              INT            NULL,
    [IsDeleted]                 BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_LoggerToCalibrator] PRIMARY KEY CLUSTERED ([AssignedCalibratorId] ASC, [LoggerToCalibratorId] ASC, [CreateDate] ASC),
    CONSTRAINT [FK_LoggerToCalibrator_LoggerMeasurementDeviceId] FOREIGN KEY ([LoggerMeasurementDeviceId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_LoggerToCalibrator_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_LoggerToCalibrator_UserId] FOREIGN KEY ([AssignedCalibratorId]) REFERENCES [dbo].[Users] ([ID])
);

