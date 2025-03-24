CREATE TABLE [dbo].[UsersToRoles] (
    [ID]     INT IDENTITY (1, 1) NOT NULL,
    [UserId] INT NOT NULL,
    [RoleId] INT NOT NULL,
    CONSTRAINT [PK_UsersToRoles] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_UsersToRoles_Roles] FOREIGN KEY ([RoleId]) REFERENCES [dbo].[Roles] ([ID]),
    CONSTRAINT [FK_UsersToRoles_Users] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);

