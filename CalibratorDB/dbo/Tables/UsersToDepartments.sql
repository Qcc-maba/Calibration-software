CREATE TABLE [dbo].[UsersToDepartments] (
    [ID]           INT IDENTITY (1, 1) NOT NULL,
    [UserId]       INT NOT NULL,
    [DepartmentId] INT NOT NULL,
    CONSTRAINT [PK_UsertToDepartments_1] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_UsertToDepartments_Departments] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID]),
    CONSTRAINT [FK_UsertToDepartments_Users] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

