CREATE TABLE [etl].[CalibGetDataLog] (
    [TableName]         NVARCHAR (255) NOT NULL,
    [LastExecutionDate] DATETIME2 (0)  NULL,
    PRIMARY KEY CLUSTERED ([TableName] ASC)
);

