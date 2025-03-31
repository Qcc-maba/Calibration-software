CREATE TABLE [dbo].[SyncVersionTable] (
    [TableName]       NVARCHAR (128) NOT NULL,
    [LastSyncVersion] BIGINT         NULL,
    PRIMARY KEY CLUSTERED ([TableName] ASC)
);

