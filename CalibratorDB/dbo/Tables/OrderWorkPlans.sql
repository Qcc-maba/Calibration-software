CREATE TABLE [dbo].[OrderWorkPlans] (
    [OrderWorkPlanId]  INT            IDENTITY (1, 1) NOT NULL,
    [OrderNumber]      NVARCHAR (20)  NULL,
    [WorkPlanOpenDate] DATETIME2 (0)  NOT NULL,
    [IsCancelled]      BIT            DEFAULT ((0)) NOT NULL,
    [CreatedDate]      DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]      DATETIME2 (0)  NULL,
    [CreatedByUserId]  INT            NULL,
    [UpdateUserID]     INT            NULL,
    [Notes]            NVARCHAR (255) NULL,
    CONSTRAINT [PK_OrderWorkPlans] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC),
    CONSTRAINT [FK_OrdersHeaders_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_OrdersHeaders_UpdatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [UQ_OrderNumber] UNIQUE NONCLUSTERED ([OrderNumber] ASC)
);

