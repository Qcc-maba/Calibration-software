CREATE TABLE [dbo].[Measurements] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [NameEn]       NVARCHAR (50) NOT NULL,
    [NameHe]       NVARCHAR (50) NOT NULL,
    [NoteEn]       NVARCHAR (50) NULL,
    [NoteHe]       NVARCHAR (50) NULL,
    [DepartmentId] INT           NOT NULL,
    CONSTRAINT [PK_Measurements] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Department] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID])
);

