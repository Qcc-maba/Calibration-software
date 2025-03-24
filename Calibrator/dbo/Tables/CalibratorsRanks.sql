CREATE TABLE [dbo].[CalibratorsRanks] (
    [ID]   INT           IDENTITY (1, 1) NOT NULL,
    [Rank] NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_CalibratorsRanks] PRIMARY KEY CLUSTERED ([ID] ASC)
);

