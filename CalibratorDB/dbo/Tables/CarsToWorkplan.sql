CREATE TABLE [dbo].[CarsToWorkplan] (
    [OrderWorkPlanId] INT           NOT NULL,
    [CarId]           INT           NOT NULL,
    [UpdateUserID]    INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [IsDeleted]       BIT           DEFAULT ((0)) NOT NULL,
    [UpdatedDate]     DATETIME2 (0) NULL,
    CONSTRAINT [PK_CarsToWorkplan] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] DESC, [CarId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_CarsToWorkplan_CarId] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsToWorkplan_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CarsToWorkplan_WorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId])
);

