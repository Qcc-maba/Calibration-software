CREATE TABLE [dbo].[UsersToDepartments] (
    [UserId]       INT           NOT NULL,
    [DepartmentId] INT           NOT NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT           NULL,
    CONSTRAINT [PK_UsertToDepartments_1] PRIMARY KEY CLUSTERED ([UserId] ASC, [DepartmentId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_UsersToDepartments_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsertToDepartments_Departments] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID]),
    CONSTRAINT [FK_UsertToDepartments_Users] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

