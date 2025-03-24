CREATE TABLE [dbo].[CalibrationHistory] (
    [Id]                 INT           IDENTITY (1, 1) NOT NULL,
    [CalibratedUnitID]   INT           NOT NULL,
    [CalibrationHistory] DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_CalibrationHistory] PRIMARY KEY CLUSTERED ([Id] ASC)
);

