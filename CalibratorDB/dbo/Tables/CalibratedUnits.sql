CREATE TABLE [dbo].[CalibratedUnits] (
    [Id]                     INT            IDENTITY (1, 1) NOT NULL,
    [OrderId]                INT            NOT NULL,
    [MainRange]              NVARCHAR (50)  NOT NULL,
    [SubRange]               NVARCHAR (50)  NOT NULL,
    [DeviceTypeId]           INT            NOT NULL,
    [CalibrationPoints]      INT            NOT NULL,
    [ManufacturerNumber]     NVARCHAR (50)  NULL,
    [ManufacturerName]       NVARCHAR (50)  NULL,
    [ProfessionalComments]   NVARCHAR (250) NULL,
    [LastDateForCalibration] DATETIME2 (7)  NULL,
    [LastCalibrationDate]    DATETIME2 (7)  NULL,
    [Notes]                  NVARCHAR (255) NULL,
    [CalibrationStatusId]    INT            NULL,
    [StatusDescriptionId]    INT            NULL,
    [MbaNumber]              NCHAR (15)     NOT NULL,
    CONSTRAINT [PK_DevicesToCalibrate] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_CalibratedUnits_CalibratedUnitsWorkStatus] FOREIGN KEY ([CalibrationStatusId]) REFERENCES [dbo].[CalibratedUnitsWorkStatus] ([Id]),
    CONSTRAINT [FK_CalibratedUnits_DeviceTypes] FOREIGN KEY ([DeviceTypeId]) REFERENCES [dbo].[DeviceTypes] ([ID]),
    CONSTRAINT [FK_CalibratedUnits_Orders] FOREIGN KEY ([OrderId]) REFERENCES [dbo].[Orders_] ([ID])
);

