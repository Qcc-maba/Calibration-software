CREATE TABLE [dbo].[CalibratedUnitsToWorkPlan] (
    [Id]                INT IDENTITY (1, 1) NOT NULL,
    [WorkplanID]        INT NOT NULL,
    [CalibratedUnitsID] INT NOT NULL,
    CONSTRAINT [PK_CalibratedUnitsToWorkPlan] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_CalibratedUnitsToWorkPlan_CalibratedUnits] FOREIGN KEY ([CalibratedUnitsID]) REFERENCES [dbo].[CalibratedUnits] ([Id]),
    CONSTRAINT [FK_CalibratedUnitsToWorkPlan_WorkPlan] FOREIGN KEY ([WorkplanID]) REFERENCES [dbo].[WorkPlan] ([Id])
);

