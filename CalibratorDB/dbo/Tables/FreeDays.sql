CREATE TABLE [dbo].[FreeDays] (
    [ID]    INT           IDENTITY (1, 1) NOT NULL,
    [Date]  DATETIME2 (7) NOT NULL,
    [Title] NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_FreeDays] PRIMARY KEY CLUSTERED ([ID] ASC)
);

