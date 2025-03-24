CREATE TABLE [dbo].[Translate] (
    [ID]      INT            IDENTITY (1, 1) NOT NULL,
    [Hebrew]  NVARCHAR (MAX) NOT NULL,
    [English] NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_Translate] PRIMARY KEY CLUSTERED ([ID] ASC)
);

