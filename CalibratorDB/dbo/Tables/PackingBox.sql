CREATE TABLE [dbo].[PackingBox] (
    [PackingBoxId] INT            IDENTITY (1, 1) NOT NULL,
    [BarCode]      NVARCHAR (100) NULL,
    [Comment]      NVARCHAR (200) NULL,
    [CreateDate]   DATETIME2 (0)  DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]  DATETIME2 (0)  NULL,
    [UpdateUserID] INT            NULL,
    [IsDeleted]    BIT            DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([PackingBoxId] ASC),
    CONSTRAINT [FK_PackingBox_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_PackingBoxToOrderDetailsItems] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID]),
    CONSTRAINT [FK_PackingBoxToOrderDetailsItems_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [IDX_U_PackingBox]
    ON [dbo].[PackingBox]([BarCode] ASC);

