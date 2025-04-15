CREATE TABLE [dbo].[Departments] (
    [ID]             INT           IDENTITY (1, 1) NOT NULL,
    [DepartmentName] NVARCHAR (50) NOT NULL,
    [AddedByUserId]  INT           DEFAULT ((0)) NOT NULL,
    [CreatedAt]      DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedAt]      DATETIME2 (0) NULL,
    [IsDeleted]      BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_Departments] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Departments_AddedByUserId] FOREIGN KEY ([AddedByUserId]) REFERENCES [dbo].[Users] ([ID])
);

