CREATE TABLE [dbo].[CalibratorsToWorkPlan] (
    [OrderWorkPlanId]             INT            NOT NULL,
    [CalibratorId]                INT            NOT NULL,
    [UpdateUserID]                INT            NULL,
    [CreatedDate]                 DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [IsDeleted]                   BIT            DEFAULT ((0)) NOT NULL,
    [UpdatedDate]                 DATETIME2 (0)  NULL,
    [AssigmentDate]               DATETIME2 (0)  NULL,
    [OrderDetailsMbaReportNumber] NVARCHAR (100) NULL,
    [CarId]                       INT            NOT NULL,
    CONSTRAINT [PK_CalibratorsToWorkPlan] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC, [CalibratorId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_CalibratorsToWorkPlan] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_Calibrators] FOREIGN KEY ([CalibratorId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CalibratorsToWorkPlan_WorkPlan] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId])
);




















GO
