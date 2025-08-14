CREATE TABLE [dbo].[SpecificationReference] (
    [ID]                  INT           IDENTITY (1, 1) NOT NULL,
    [Name]                NVARCHAR (50)  NOT NULL,
    [CreatedDate]         DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]         DATETIME2 (0) NULL,
    [IsDeleted]           BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]        INT           NULL,
    [SecondaryCategoryId] INT           NULL,
    CONSTRAINT [PK_SpecificationReference] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SpecificationReference_SecondaryCategoryId] FOREIGN KEY ([SecondaryCategoryId]) REFERENCES [dbo].[SecondaryCategories] ([ID]),
    CONSTRAINT [FK_SpecificationReference_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

