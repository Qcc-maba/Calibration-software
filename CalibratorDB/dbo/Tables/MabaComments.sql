CREATE TABLE [dbo].[MabaComments] (
    [OrderDetailId] INT             NOT NULL,
    [MabaComment]   VARBINARY (MAX) NULL,
    [TextHash]      INT             NULL,
    [CreateDate]    DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]   DATETIME2 (0)   NULL,
    [UpdateUserID]  INT             NULL,
    [IsDeleted]     BIT             DEFAULT ((0)) NOT NULL,
    CONSTRAINT [FK_MabaComments_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);


GO
CREATE UNIQUE CLUSTERED INDEX [IDX_OrderDetailId]
    ON [dbo].[MabaComments]([OrderDetailId] ASC);

