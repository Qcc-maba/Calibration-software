CREATE TABLE [dbo].[OrderItemsStatusesHistory] (
    [OrderDetailsItemId] INT           NOT NULL,
    [StatusId]           INT           NOT NULL,
    [StatusCategoryId]   INT           NOT NULL,
    [UpdateUserID]       INT           NOT NULL,
    [CreatedDate]        DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [IsDeleted]          BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrderItemsStatusesHistory] PRIMARY KEY CLUSTERED ([OrderDetailsItemId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_OrderItemsStatusesHistory_StatusCategoryId] FOREIGN KEY ([StatusCategoryId]) REFERENCES [dbo].[StatusesCategories] ([StatusCategoryId]),
    CONSTRAINT [FK_OrderItemsStatusesHistory_StatusId] FOREIGN KEY ([StatusId]) REFERENCES [dbo].[Statuses] ([StatusId]),
    CONSTRAINT [FK_OrderItemsStatusesHistory_UserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

