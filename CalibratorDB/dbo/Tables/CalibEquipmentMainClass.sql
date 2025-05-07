CREATE TABLE [dbo].[CalibEquipmentMainClass] (
    [ID]                        INT            IDENTITY (1, 1) NOT NULL,
    [EquipmentMainClassNameHEB] NVARCHAR (50)  NULL,
    [Description]               NVARCHAR (150) NULL,
    [EquipmentMainClassNameENG] NVARCHAR (50)  NULL,
    [CreateDate]                DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]               DATETIME2 (0)  NULL,
    [UpdateUserID]              INT            NULL,
    [IsDeleted]                 BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_EquipmentMainClass] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_EquipmentMainClass_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

