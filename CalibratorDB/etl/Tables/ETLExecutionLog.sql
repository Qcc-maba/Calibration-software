CREATE TABLE [etl].[ETLExecutionLog] (
    [ETLPackageName]    NVARCHAR (255) NOT NULL,
    [LastExecutionDate] DATETIME2 (0)  NULL,
    PRIMARY KEY CLUSTERED ([ETLPackageName] ASC)
);

