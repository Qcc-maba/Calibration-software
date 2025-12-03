CREATE TABLE [dbo].[ClientAccessoryOrderDetailsItems] (
    [OrderDetailsItemId]                INT            NOT NULL,
    [ClientAccessoryOrderDetailsItemId] INT            IDENTITY (1, 1) NOT NULL,
    [ItemsCount]                        INT            NULL,
    [AccessoryDescription]              NVARCHAR (200) NULL,
    [CreateDate]                        DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]                       DATETIME2 (0)  NULL,
    [UpdateUserID]                      INT            NULL,
    [IsDeleted]                         BIT            DEFAULT ((0)) NOT NULL,
    [AccessoryLocation]                 NVARCHAR (100) NULL,
    [SourceId]                          TINYINT        NULL,
    CONSTRAINT [PK_ClientAccessoryOrderDetails] PRIMARY KEY CLUSTERED ([OrderDetailsItemId] ASC, [ClientAccessoryOrderDetailsItemId] ASC),
    CONSTRAINT [FK_ClientAccessoryOrderDetailsItems_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId]),
    CONSTRAINT [FK_ClientAccessoryOrderDetailsItems_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

