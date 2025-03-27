CREATE TABLE [dbo].[UsersToUserRoles] (
    [UserId]          INT           NOT NULL,
    [UserRoleId]      INT           NOT NULL,
    [CreatedByUserId] INT           NULL,
    [CreatedDate]     DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_UsersToUserRoles] PRIMARY KEY CLUSTERED ([UserId] ASC, [UserRoleId] ASC),
    CONSTRAINT [FK_UsersToUserRoles] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToUserRoles_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToUserRoles_UserRoleId] FOREIGN KEY ([UserRoleId]) REFERENCES [dbo].[Users] ([ID])
);

