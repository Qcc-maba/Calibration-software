CREATE TABLE [dbo].[CustomerRemarks] (
    [CustomerId]           INT             IDENTITY (1, 1) NOT NULL,
    [CustomerRemark]       VARBINARY (MAX) NULL,
    [CustomerIdFromSource] INT             NULL,
    [SourceId]             TINYINT         NULL,
    [TextHash]             INT             NULL,
    [CreateDate]           DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]          DATETIME2 (0)   NULL,
    [UpdateUserID]         INT             NULL,
    [IsDeleted]            BIT             DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([CustomerId] ASC),
    CONSTRAINT [FK_CustomerRemarks_CustomerId] FOREIGN KEY ([CustomerId]) REFERENCES [dbo].[Customers] ([CustomerId]),
    CONSTRAINT [FK_CustomerRemarks_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId]),
    CONSTRAINT [FK_CustomerRemarks_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

