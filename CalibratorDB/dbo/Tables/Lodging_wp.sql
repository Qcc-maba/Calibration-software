CREATE TABLE [dbo].[Lodging_wp] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [WorkId]       INT           NOT NULL,
    [CalibratorId] INT           NOT NULL,
    [DateFrom]     DATETIME2 (7) NULL,
    [DateTo]       DATETIME2 (7) NULL,
    CONSTRAINT [PK_Lodging_wp] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Lodging_wp_WorkPlan] FOREIGN KEY ([WorkId]) REFERENCES [dbo].[WorkPlan] ([Id])
);

