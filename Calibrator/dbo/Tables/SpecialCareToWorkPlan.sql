CREATE TABLE [dbo].[SpecialCareToWorkPlan] (
    [ID]            INT IDENTITY (1, 1) NOT NULL,
    [WorkPlanId]    INT NOT NULL,
    [SpecialCareId] INT NOT NULL,
    CONSTRAINT [PK_SpecialCareToWorkPlan] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SpecialCareToWorkPlan_SpecialCare_wp] FOREIGN KEY ([SpecialCareId]) REFERENCES [dbo].[SpecialCare_wp] ([ID]),
    CONSTRAINT [FK_SpecialCareToWorkPlan_WorkPlan] FOREIGN KEY ([WorkPlanId]) REFERENCES [dbo].[WorkPlan] ([Id])
);


GO
CREATE NONCLUSTERED INDEX [IX_SpecialCareToWorkPlan]
    ON [dbo].[SpecialCareToWorkPlan]([SpecialCareId] ASC, [WorkPlanId] ASC);

