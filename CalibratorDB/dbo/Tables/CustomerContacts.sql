CREATE TABLE [dbo].[CustomerContacts] (
    [CustomerContactId]                    INT           IDENTITY (1, 1) NOT NULL,
    [CustomerId]                           INT           NOT NULL,
    [CustomerContactName]                  NVARCHAR (50) NULL,
    [CustomerContactPersonRole]            NVARCHAR (50) NULL,
    [CustomerContactPhone]                 NVARCHAR (50) NULL,
    [CustomerContactAdditionalPhoneNumber] NVARCHAR (50) NULL,
    [CustomerContactEmail]                 NVARCHAR (50) NULL,
    [CustomerContactIdFromSource]          INT           NULL,
    [SourceId]                             TINYINT       NULL,
    [CreateDate]                           DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                          DATETIME2 (0) NULL,
    [UpdateUserID]                         INT           NULL,
    [IsDeleted]                            BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_CustomerContacts] PRIMARY KEY CLUSTERED ([CustomerId] ASC),
    CONSTRAINT [FK_CustomerContacts_CustomerId] FOREIGN KEY ([CustomerId]) REFERENCES [dbo].[Customers] ([CustomerId]),
    CONSTRAINT [FK_CustomerContacts_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId]),
    CONSTRAINT [FK_CustomerContacts_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

