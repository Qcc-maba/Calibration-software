CREATE TABLE [dbo].[SpecificationReference] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [Name]         VARCHAR (50)  NOT NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT           NULL,
    CONSTRAINT [PK_SpecificationReference] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SpecificationReference_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

