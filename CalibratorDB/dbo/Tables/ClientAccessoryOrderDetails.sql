CREATE TABLE [dbo].[ClientAccessoryOrderDetails] (
    [OrderDetailId]        INT            NOT NULL,
    [AccessorySourceId]    INT            NOT NULL,
    [SerialNumber]         NVARCHAR (30)  NULL,
    [ItemsCount]           INT            NULL,
    [AccessoryDescription] NVARCHAR (200) NULL,
    [CreateDate]           DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]          DATETIME2 (0)  NULL,
    [UpdateUserID]         INT            NULL,
    [IsDeleted]            BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_ClientAccessoryOrderDetails] PRIMARY KEY CLUSTERED ([OrderDetailId] ASC, [AccessorySourceId] ASC),
    CONSTRAINT [FK_ClientAccessoryOrderDetails_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

