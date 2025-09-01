CREATE TABLE [dbo].[CalibratorCertificationAuthorities] (
    [ID]             INT           IDENTITY (1, 1) NOT NULL,
    [AuthorityName]  NVARCHAR (50) NOT NULL,
    [MainCategoryId] INT           NOT NULL,
    [CreatedDate]    DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]    DATETIME2 (0) NULL,
    [IsDeleted]      BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID]   INT           NULL,
    CONSTRAINT [PK_CalibratorCertificationAuthorities] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_CalibratorCertificationAuthorities_MainCategoryId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_CalibratorCertificationAuthorities_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

