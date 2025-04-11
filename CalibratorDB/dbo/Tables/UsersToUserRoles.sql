CREATE TABLE [dbo].[UsersToUserRoles] (
    [UserId]       INT           NOT NULL,
    [UserRoleId]   INT           NOT NULL,
    [UpdateUserID] INT           NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_UsersToUserRoles] PRIMARY KEY CLUSTERED ([UserId] ASC, [UserRoleId] ASC, [CreatedDate] ASC),
    CONSTRAINT [FK_UsersToUserRoles] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToUserRoles_CreatedByUserId] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_UsersToUserRoles_UserRoleId] FOREIGN KEY ([UserRoleId]) REFERENCES [dbo].[UserRoles] ([UserRoleId])
);

