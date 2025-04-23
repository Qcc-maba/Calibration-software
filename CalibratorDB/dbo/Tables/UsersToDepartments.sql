CREATE TABLE [dbo].[UsersToDepartments] (
    [UserId]       INT           NOT NULL,
    [DepartmentId] INT           NOT NULL,
    [UpdateUserID] INT           NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_UsersToDepartments] PRIMARY KEY CLUSTERED ([UserId] ASC, [DepartmentId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_UsersToDepartments] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToDepartments_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToDepartments_DepartmentId] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID])
);

