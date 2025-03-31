CREATE TABLE [dbo].[Units] (
    [ID]             INT            IDENTITY (1, 1) NOT NULL,
    [ShortNameEn]    NVARCHAR (10)  COLLATE Hebrew_CI_AS NOT NULL,
    [ShortNameEnAsc] VARCHAR (50)   COLLATE Hebrew_CI_AS NOT NULL,
    [LongNameEn]     NVARCHAR (100) COLLATE Hebrew_CI_AS NOT NULL,
    [ShortNameHeAsc] VARCHAR (50)   COLLATE Hebrew_CI_AS NOT NULL,
    [ShortNameHe]    NVARCHAR (50)  COLLATE Hebrew_CI_AS NOT NULL,
    [LongNameHe]     NVARCHAR (100) COLLATE Hebrew_CI_AS NOT NULL,
    [GroupID]        INT            NOT NULL,
    [Note]           NVARCHAR (500) COLLATE Hebrew_CI_AS NULL,
    CONSTRAINT [PK_Units] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Units_UnitGroups] FOREIGN KEY ([GroupID]) REFERENCES [dbo].[UnitGroups] ([ID])
);

