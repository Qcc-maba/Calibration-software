CREATE TABLE [dbo].[CalibEquipmentsToWorkplan] (
    [Id]          INT IDENTITY (1, 1) NOT NULL,
    [EquipmentID] INT NOT NULL,
    [WorkplanID]  INT NOT NULL,
    CONSTRAINT [PK_EquipmentsToWorkplan] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_EquipmentsToWorkplan_Equipment] FOREIGN KEY ([EquipmentID]) REFERENCES [dbo].[CalibEquipments] ([ID]),
    CONSTRAINT [FK_EquipmentsToWorkplan_WorkPlan] FOREIGN KEY ([WorkplanID]) REFERENCES [dbo].[WorkPlan] ([Id])
);

