CREATE TABLE [stg].[stg_CustomerRemarks] (
    [CUST]          INT             NULL,
    [CompresedText] VARBINARY (MAX) NULL,
    [HashText]      INT             NULL,
    [SourceSystem]  NVARCHAR (7)    NULL
);

