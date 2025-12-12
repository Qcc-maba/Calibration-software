CREATE TABLE [dbo].[CustomerSites] (
    [CustomerId]              INT           NOT NULL,
    [CustomerSiteId]          INT           IDENTITY (1, 1) NOT NULL,
    [CustomerSiteAddress]     NVARCHAR (80) NULL,
    [CustomerSiteState]       NVARCHAR (40) NULL,
    [CustomerSiteZIP]         NVARCHAR (10) NULL,
    [CustomerSitePhone]       NVARCHAR (30) NULL,
    [CustomerSiteDescription] NVARCHAR (50) NULL,
    [CustomerSiteCode]        INT           NULL,
    [CreateDate]              DATETIME2 (0) CONSTRAINT [DF_CreateDate] DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]             DATETIME2 (0) NULL,
    [UpdateUserID]            INT           NULL,
    [IsDeleted]               BIT           CONSTRAINT [DF_IsDeleted] DEFAULT ((0)) NOT NULL,
    [SourceId]                TINYINT       NULL,
    CONSTRAINT [PK_CustomerSites] PRIMARY KEY CLUSTERED ([CustomerSiteId] ASC, [CustomerId] ASC),
    CONSTRAINT [FK_CustomerSites_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId])
);

