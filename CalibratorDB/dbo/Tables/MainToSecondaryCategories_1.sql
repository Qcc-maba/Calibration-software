CREATE TABLE [dbo].[MainToSecondaryCategories] (
    [ID]                  INT           IDENTITY (1, 1) NOT NULL,
    [SecondaryCategoryId] INT           NOT NULL,
    [MainCategoryId]      INT           NOT NULL,
    [AddedByUserId]       INT           DEFAULT ((0)) NOT NULL,
    [CreatedAt]           DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedAt]           DATETIME2 (0) NULL,
    [IsDeleted]           BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_MainToSecondaryCategories] PRIMARY KEY CLUSTERED ([MainCategoryId] ASC, [SecondaryCategoryId] ASC, [ID] ASC),
    CONSTRAINT [FK_MainToSecondaryCategories_AddedByUserId] FOREIGN KEY ([AddedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_MainToSecondaryCategories_MainCategoryId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_MainToSecondaryCategories_SecondaryCategoryId] FOREIGN KEY ([SecondaryCategoryId]) REFERENCES [dbo].[SecondaryCategories] ([ID])
);

