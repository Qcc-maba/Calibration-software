CREATE TABLE [stg].[stg_ClientAccessoryOrderDetails] (
    [SerialNumber]         NVARCHAR (30)  NULL,
    [KLINE]                INT            NULL,
    [ItemsCount]           INT            NULL,
    [AccessoryDescription] NVARCHAR (200) NULL,
    [SourceOrderId]        INT            NULL,
    [AccessorySourceId]    INT            NULL,
    [SourceSystem]         NVARCHAR (50)  NULL
);

