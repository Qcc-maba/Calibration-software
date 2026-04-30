CREATE TABLE [stg].[stg_CustomerSites] (
    [CustomerId]                 INT           NOT NULL,
    [CustomerSiteAddress]        NVARCHAR (80) NULL,
    [CustomerSiteState]          NVARCHAR (40) NULL,
    [CustomerSiteZIP]            NVARCHAR (10) NULL,
    [CustomerSitePhone]          NVARCHAR (30) NULL,
    [CustomerSiteDescription]    NVARCHAR (50) NULL,
    [CustomerSiteCode]           INT           NULL,
    [SourceSystem]               NVARCHAR (20) NULL,
    [CustomerSiteAddressENG]     NVARCHAR (80) NULL,
    [CustomerSiteStateENG]       NVARCHAR (40) NULL,
    [CustomerSiteDescriptionENG] NVARCHAR (50) NULL
);

