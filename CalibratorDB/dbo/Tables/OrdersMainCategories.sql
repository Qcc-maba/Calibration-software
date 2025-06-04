CREATE TABLE [dbo].[OrdersMainCategories] (
    [OrdersMainCategoryId]           INT           IDENTITY (1, 1) NOT NULL,
    [OrdersMainCategoryName]         NVARCHAR (50) NULL,
    [OrdersMainCategoryIdFromSource] INT           NULL,
    [SourceId]                       TINYINT       NULL,
    [CreateDate]                     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                    DATETIME2 (0) NULL,
    [UpdateUserID]                   INT           NULL,
    [IsDeleted]                      BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrdersMainCategories] PRIMARY KEY CLUSTERED ([OrdersMainCategoryId] ASC),
    CONSTRAINT [FK_OrdersMainCategories_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId])
);

