CREATE TABLE [dbo].[OrderWorkPlans] (
    [OrderWorkPlanId]            INT            IDENTITY (1, 1) NOT NULL,
    [OrderNumber]                NVARCHAR (20)  NULL,
    [WorkPlanOpenDate]           DATETIME2 (0)  NOT NULL,
    [IsCancelled]                BIT            DEFAULT ((0)) NOT NULL,
    [CreatedDate]                DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                DATETIME2 (0)  NULL,
    [CreatedByUserId]            INT            NULL,
    [UpdateUserID]               INT            NULL,
    [Notes]                      NVARCHAR (255) NULL,
    [SourceId]                   TINYINT        NULL,
    [OrderStatusId]              INT            NULL,
    [CustomerId]                 INT            NULL,
    [OrderOverallStatusId]       INT            NULL,
    [ClientConfirmationStatusId] INT            NULL,
    [ShipTypeDesc]               NVARCHAR (100) NULL,
    [CustomerComment]            NVARCHAR (200) NULL,
    [BK_DOC_N]                   INT            NULL,
    [BK_KLINE]                   INT            NULL,
    [BK_PART]                    INT            NULL,
    [OrderSourceId]              INT            NULL,
    CONSTRAINT [PK_OrderWorkPlans] PRIMARY KEY CLUSTERED ([OrderWorkPlanId] ASC),
    CONSTRAINT [FK_OrdersHeaders_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_OrdersHeaders_UpdatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_OrderWorkPlans_ClientConfirmationStatusId] FOREIGN KEY ([ClientConfirmationStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_OrderWorkPlans_CustomerId] FOREIGN KEY ([CustomerId]) REFERENCES [dbo].[Customers] ([CustomerId]),
    CONSTRAINT [FK_OrderWorkPlans_OrderOverallStatusId] FOREIGN KEY ([OrderOverallStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_OrderWorkPlans_OrderStatusId] FOREIGN KEY ([OrderStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_OrderWorkPlans_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId])
);






GO
CREATE NONCLUSTERED INDEX [NC_IDX_BK_OrderWorkPlans]
    ON [dbo].[OrderWorkPlans]([BK_DOC_N] ASC, [BK_PART] ASC, [BK_KLINE] ASC) WHERE ([BK_DOC_N] IS NOT NULL AND [BK_PART] IS NOT NULL AND [BK_KLINE] IS NOT NULL);

