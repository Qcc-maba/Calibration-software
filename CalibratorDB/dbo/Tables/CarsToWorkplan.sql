CREATE TABLE [dbo].[CarsToWorkplan] (
    [OrderWorkPlanId] INT           NOT NULL,
    [CarId]           INT           NOT NULL,
    [CreatedByUserId] INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_CarsToWorkplan] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] DESC, [CarId] ASC),
    CONSTRAINT [FK_CarsToWorkplan_CarId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsToWorkplan_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CarsToWorkplan_WorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId])
);

