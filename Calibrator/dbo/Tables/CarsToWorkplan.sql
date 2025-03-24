CREATE TABLE [dbo].[CarsToWorkplan] (
    [WorkPlanId]  INT           NOT NULL,
    [CarId]       INT           NOT NULL,
    [CreatedDate] DATETIME2 (0) DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_CarsToWorkplan] PRIMARY KEY CLUSTERED ([WorkPlanId] DESC, [CarId] ASC),
    CONSTRAINT [FK_CarsToWorkplan_CarId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsToWorkplan_WorkPlanId] FOREIGN KEY ([WorkPlanId]) REFERENCES [dbo].[WorkPlan] ([Id])
);

