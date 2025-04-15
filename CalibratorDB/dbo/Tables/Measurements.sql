CREATE TABLE [dbo].[Measurements] (
    [ID]           INT           IDENTITY (1, 1) NOT NULL,
    [NameEn]       NVARCHAR (50) NOT NULL,
    [NameHe]       NVARCHAR (50) NOT NULL,
    [NoteEn]       NVARCHAR (50) NULL,
    [NoteHe]       NVARCHAR (50) NULL,
    [DepartmentId] INT           NOT NULL,
    [CreatedDate]  DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0) NULL,
    [IsDeleted]    BIT           DEFAULT ((0)) NOT NULL,
    [UpdateUserID] INT           NULL,
    CONSTRAINT [PK_Measurements] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Department] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID]),
    CONSTRAINT [FK_Measurements_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

