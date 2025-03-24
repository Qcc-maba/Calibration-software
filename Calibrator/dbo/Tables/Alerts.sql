CREATE TABLE [dbo].[Alerts] (
    [ID]        INT           IDENTITY (1, 1) NOT NULL,
    [AlertName] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_Alerts] PRIMARY KEY CLUSTERED ([ID] ASC)
);

