CREATE TABLE [dbo].[SecondaryCategories] (
    [ID]                    INT           IDENTITY (1, 1) NOT NULL,
    [SecondaryCategoryName] NVARCHAR (50) NOT NULL,
    [AddedByUserId]         INT           DEFAULT ((0)) NOT NULL,
    [CreatedAt]             DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedAt]             DATETIME2 (0) NULL,
    [IsDeleted]             BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_SecondaryCategories] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SecondaryCategories_AddedByUserId] FOREIGN KEY ([AddedByUserId]) REFERENCES [dbo].[Users] ([ID])
);

