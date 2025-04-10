CREATE TABLE [dbo].[CarsToOrder] (
    [CarId]           INT           NOT NULL,
    [AssignDate]      DATETIME2 (0) NOT NULL,
    [AssignQuater0]   BIT           NULL,
    [AssignQuater1]   BIT           NULL,
    [AssignQuater2]   BIT           NULL,
    [AssignQuater3]   BIT           NULL,
    [OrderWorkPlanId] INT           NOT NULL,
    [CreatedByUserId] INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]     DATETIME2 (0) NULL,
    [IsDeleted]       BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_CarsToOrder] PRIMARY KEY CLUSTERED ([AssignDate] ASC, [OrderWorkPlanId] ASC, [CarId] ASC),
    CONSTRAINT [FK_CarsToOrder] FOREIGN KEY ([CarId]) REFERENCES [dbo].[Cars] ([CarId]),
    CONSTRAINT [FK_CarsToOrder_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_CarsToOrder_OrderWorkPlanId] FOREIGN KEY ([OrderWorkPlanId]) REFERENCES [dbo].[OrderWorkPlans] ([OrderWorkPlanId])
);

