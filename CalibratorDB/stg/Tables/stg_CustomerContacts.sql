CREATE TABLE [stg].[stg_CustomerContacts] (
    [CustomerContactIdFromSource]          INT           NULL,
    [CustomerContactName]                  NVARCHAR (50) NULL,
    [CustomerContactPersonRole]            NVARCHAR (50) NULL,
    [CustomerContactPhone]                 NVARCHAR (50) NULL,
    [CustomerContactAdditionalPhoneNumber] NVARCHAR (50) NULL,
    [CustomerContactEmail]                 NVARCHAR (50) NULL,
    [CustomerId]                           INT           NULL,
    [SourceSystem]                         NVARCHAR (20) NULL
);

