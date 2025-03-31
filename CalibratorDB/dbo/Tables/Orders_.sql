CREATE TABLE [dbo].[Orders_] (
    [ID]                   INT            IDENTITY (1, 1) NOT NULL,
    [OrderNumber]          NCHAR (12)     NOT NULL,
    [OpenDate]             DATETIME       NOT NULL,
    [CustomerId]           INT            NOT NULL,
    [CustomerName]         NVARCHAR (255) NULL,
    [CustomerPhone]        NVARCHAR (25)  NULL,
    [CustomerContactName]  NVARCHAR (50)  NULL,
    [CustomerCity]         NVARCHAR (50)  NULL,
    [CustomerAddress]      NVARCHAR (255) NULL,
    [CustomerContactPhone] NVARCHAR (25)  NULL,
    [MBAContactName]       NVARCHAR (50)  NULL,
    [MBAContactPhone]      NVARCHAR (25)  NULL,
    [MBAContactMobile]     NVARCHAR (25)  NULL,
    [ClientRemarks]        NVARCHAR (MAX) NULL,
    CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED ([ID] ASC)
);

