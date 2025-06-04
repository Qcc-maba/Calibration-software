CREATE TABLE [dbo].[Source] (
    [SourceId]   TINYINT       IDENTITY (1, 1) NOT NULL,
    [SourceName] NVARCHAR (50) NULL,
    CONSTRAINT [PK_Source] PRIMARY KEY CLUSTERED ([SourceId] ASC)
);

