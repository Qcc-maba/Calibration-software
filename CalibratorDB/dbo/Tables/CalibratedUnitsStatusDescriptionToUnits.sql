CREATE TABLE [dbo].[CalibratedUnitsStatusDescriptionToUnits] (
    [Id]                                 INT IDENTITY (1, 1) NOT NULL,
    [CalibratedUnitsStatusDescriptionId] INT NOT NULL,
    [CalibratedUnitsId]                  INT NOT NULL,
    CONSTRAINT [PK_CalibratedUnitsStatusDescriptionToUnits] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_CalibratedUnitsStatusDescriptionToUnits_CalibratedUnits] FOREIGN KEY ([CalibratedUnitsId]) REFERENCES [dbo].[CalibratedUnits] ([Id]),
    CONSTRAINT [FK_CalibratedUnitsStatusDescriptionToUnits_CalibratedUnitsStatusDescription] FOREIGN KEY ([CalibratedUnitsStatusDescriptionId]) REFERENCES [dbo].[CalibratedUnitsStatusDescription] ([Id])
);

