CREATE TABLE [dbo].[CalibrationCycles] (
    [OrderDetailsItemId]           INT             NOT NULL,
    [CalibrationCycleStartDate]    DATETIME2 (0)   NOT NULL,
    [CalibrationCycleEndDate]      DATETIME2 (0)   NOT NULL,
    [CalibrationCycleStatusId]     INT             NULL,
    [CreatedUserID]                INT             NOT NULL,
    [CreatedDate]                  DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                  DATETIME2 (0)   NULL,
    [IsDeleted]                    BIT             DEFAULT ((0)) NOT NULL,
    [UpdateUserID]                 INT             NULL,
    [CalibrationCycleName]         NVARCHAR (200)  NULL,
    [UnitId]                       INT             NULL,
    [TestedValue]                  DECIMAL (18, 6) NULL,
    [SpecificationReferenceIds]    NVARCHAR (100)  NULL,
    [CalibrationCycleNameStatusId] INT             NULL,
    CONSTRAINT [PK_CalibrationCycles] PRIMARY KEY CLUSTERED ([OrderDetailsItemId] ASC, [CalibrationCycleStartDate] ASC),
    CONSTRAINT [FK_CalibrationCycles_CalibrationCycleStatusId] FOREIGN KEY ([CalibrationCycleStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_CalibrationCycles_CreatedUserID] FOREIGN KEY ([CreatedUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibrationCycles_UnitId] FOREIGN KEY ([UnitId]) REFERENCES [dbo].[MeasurementDeviceUnits] ([MeasurementDeviceUnitId]),
    CONSTRAINT [FK_CalibrationCycles_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

