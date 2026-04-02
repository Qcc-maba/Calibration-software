CREATE TABLE [stg].[stg_Customers] (
    [CustomerID]         INT           NULL,
    [CustomerName]       NVARCHAR (48) NULL,
    [CustomerPhone]      NVARCHAR (20) NULL,
    [CustomerCity]       NVARCHAR (40) NULL,
    [CustomerAddress]    NVARCHAR (80) NULL,
    [SourceSystem]       NVARCHAR (7)  NULL,
    [SignatureAmount]    TINYINT       NULL,
    [ShipTypeDescr]      NVARCHAR (50) NULL,
    [ReportRequired]     NVARCHAR (50) NULL,
    [CustomerCode]       NVARCHAR (50) NULL,
    [AgentUserEmail]     NVARCHAR (50) NULL,
    [CustomerNameENG]    NVARCHAR (48) NULL,
    [CustomerCityENG]    NVARCHAR (40) NULL,
    [CustomerAddressENG] NVARCHAR (80) NULL
);

