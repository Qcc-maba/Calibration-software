CREATE TABLE [dbo].[CalibEquipmentSubClass] (
    [ID]           INT            IDENTITY (1, 1) NOT NULL,
    [Name]         NVARCHAR (50)  NOT NULL,
    [Description]  NVARCHAR (150) NULL,
    [CreateDate]   DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0)  NULL,
    [UpdateUserID] INT            NULL,
    [IsDeleted]    BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_EquipmentSubClass] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_EquipmentSubClass_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

