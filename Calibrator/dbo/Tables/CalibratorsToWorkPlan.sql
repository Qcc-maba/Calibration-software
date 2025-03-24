CREATE TABLE [dbo].[CalibratorsToWorkPlan] (
    [ID]            INT IDENTITY (1, 1) NOT NULL,
    [WorkPlanId]    INT NOT NULL,
    [CalibratorsId] INT NOT NULL,
    CONSTRAINT [PK_CalibratorsToWorkPlan] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_CalibratorsToWorkPlan_Calibrators] FOREIGN KEY ([CalibratorsId]) REFERENCES [dbo].[Calibrators] ([ID]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_WorkPlan] FOREIGN KEY ([WorkPlanId]) REFERENCES [dbo].[WorkPlan] ([Id])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_CalibratorsToWorkPlan]
    ON [dbo].[CalibratorsToWorkPlan]([CalibratorsId] ASC, [WorkPlanId] ASC);

