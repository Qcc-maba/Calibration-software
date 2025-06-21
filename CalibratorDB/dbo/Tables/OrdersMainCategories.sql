CREATE TABLE [dbo].[OrdersMainCategories] (
    [OrdersMainCategoryId]   INT           IDENTITY (1, 1) NOT NULL,
    [OrdersMainCategoryName] NVARCHAR (50) NULL,
    [CreateDate]             DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]            DATETIME2 (0) NULL,
    [UpdateUserID]           INT           NULL,
    [IsDeleted]              BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrdersMainCategories] PRIMARY KEY CLUSTERED ([OrdersMainCategoryId] ASC)
);

