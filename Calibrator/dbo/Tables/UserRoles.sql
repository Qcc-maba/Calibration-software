CREATE TABLE [dbo].[UserRoles] (
    [UserRoleId]             INT            IDENTITY (1, 1) NOT NULL,
    [UserRoleDescriptionENG] NVARCHAR (255) NOT NULL,
    [UserRoleDescriptionHEB] NVARCHAR (255) NULL,
    [UserRoleName]           NVARCHAR (255) DEFAULT ('') NOT NULL,
    PRIMARY KEY CLUSTERED ([UserRoleId] ASC)
);

