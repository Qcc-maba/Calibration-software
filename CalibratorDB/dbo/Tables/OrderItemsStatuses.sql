CREATE TABLE [dbo].[OrderItemsStatuses] (
    [MbaReportNumber]     NVARCHAR (20) NOT NULL,
    [OrderItemStatusId]   INT           NOT NULL,
    [OrderItemStatusDate] DATETIME2 (0) NOT NULL,
    [UserId]              INT           NOT NULL,
    [CreatedDate]         DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [IsDeleted]           BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrderItemsStatuses] PRIMARY KEY CLUSTERED ([MbaReportNumber] ASC, [OrderItemStatusDate] ASC),
    CONSTRAINT [FK_OrderItemsStatuses_OrderItemsStatusId] FOREIGN KEY ([OrderItemStatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_OrderItemsStatuses_UserId] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

