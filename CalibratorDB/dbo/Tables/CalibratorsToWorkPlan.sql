CREATE TABLE [dbo].[CalibratorsToWorkPlan] (
    [OrderWorkPlanId] INT           NOT NULL,
    [CalibratorId]    INT           NOT NULL,
    [CreatedByUserId] INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_CalibratorsToWorkPlan] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC, [CalibratorId] ASC),
    CONSTRAINT [FK_CalibratorsToWorkPlan_Calibrators] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_WorkPlan] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId])
);






GO
