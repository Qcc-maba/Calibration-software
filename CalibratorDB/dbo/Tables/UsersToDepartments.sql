CREATE TABLE [dbo].[UsersToDepartments] (
    [UserId]         INT           NOT NULL,
    [MainCategoryId] INT           NOT NULL,
    [UpdateUserID]   INT           NULL,
    [CreatedDate]    DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]    DATETIME2 (0) NULL,
    [IsDeleted]      BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_UsersToDepartments] PRIMARY KEY CLUSTERED ([UserId] ASC, [MainCategoryId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_UsersToDepartments_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToDepartments_DepartmentId] FOREIGN KEY ([MainCategoryId]) REFERENCES [dbo].[MainCategories] ([ID]),
    CONSTRAINT [FK_UsersToMainCategories] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

