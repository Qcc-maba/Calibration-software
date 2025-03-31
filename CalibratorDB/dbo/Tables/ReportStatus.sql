CREATE TABLE [dbo].[ReportStatus] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [Code]        NCHAR (10)    NOT NULL,
    [Description] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_ReportStatus] PRIMARY KEY CLUSTERED ([ID] ASC)
);

