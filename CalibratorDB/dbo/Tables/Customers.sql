CREATE TABLE [dbo].[Customers] (
    [CustomerId]           INT           IDENTITY (1, 1) NOT NULL,
    [CustomerName]         NVARCHAR (50) NULL,
    [CustomerPhone]        NVARCHAR (50) NULL,
    [CustomerCity]         NVARCHAR (50) NULL,
    [CustomerAddress]      NVARCHAR (80) NULL,
    [CustomerIdFromSource] INT           NULL,
    [SourceId]             TINYINT       NULL,
    [CreateDate]           DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]          DATETIME2 (0) NULL,
    [UpdateUserID]         INT           NULL,
    [IsDeleted]            BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([CustomerId] ASC),
    CONSTRAINT [FK_Customers_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId]),
    CONSTRAINT [FK_Customers_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);


GO
CREATE NONCLUSTERED INDEX [IDX_Customers_CustomerIdFromSource_SourceId]
    ON [dbo].[Customers]([CustomerIdFromSource] ASC, [SourceId] ASC);

