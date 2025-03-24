CREATE TABLE [dbo].[UnitGroups] (
    [ID]          INT            IDENTITY (1, 1) NOT NULL,
    [NameEn]      NVARCHAR (50)  NOT NULL,
    [NameHe]      NVARCHAR (50)  NOT NULL,
    [Description] NVARCHAR (500) NULL,
    [Simbol]      NCHAR (5)      NOT NULL,
    [HelpLink]    VARCHAR (150)  NULL,
    CONSTRAINT [PK_UnitGroups] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_UnitGroups_UnitGroups] FOREIGN KEY ([ID]) REFERENCES [dbo].[UnitGroups] ([ID])
);

