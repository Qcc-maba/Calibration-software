CREATE TABLE [dbo].[OrdersSecondaryCategories] (
    [OrdersSecondaryCategoryId]   INT            IDENTITY (1, 1) NOT NULL,
    [OrdersSecondaryCategoryName] NVARCHAR (100) NULL,
    [SourceId]                    TINYINT        NULL,
    [CreateDate]                  DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                 DATETIME2 (0)  NULL,
    [UpdateUserID]                INT            NULL,
    [IsDeleted]                   BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrdersSecondaryCategories] PRIMARY KEY CLUSTERED ([OrdersSecondaryCategoryId] ASC),
    CONSTRAINT [FK_OrdersSecondaryCategories_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId])
);

