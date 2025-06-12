CREATE TABLE [dbo].[MeasurementsToMeasurmentUnits] (
    [MeasurementId]           INT           NOT NULL,
    [MeasurementDeviceUnitId] INT           NOT NULL,
    [IsDefaultUnit]           BIT           NULL,
    [CreatedDate]             DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]             DATETIME2 (0) NULL,
    [IsDeleted]               BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]            INT           NULL,
    [SourceId]                INT           NULL,
    CONSTRAINT [PK_MeasurementsToMeasurmentUnits] PRIMARY KEY CLUSTERED ([MeasurementId] ASC, [MeasurementDeviceUnitId] ASC),
    CONSTRAINT [FK_MeasurementsToMeasurmentUnits_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

