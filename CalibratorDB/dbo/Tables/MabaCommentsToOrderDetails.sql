CREATE TABLE [dbo].[MabaCommentsToOrderDetails] (
    [MabaCommentId] INT           NULL,
    [OrderDetailId] INT           NULL,
    [CreateDate]    DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]   DATETIME2 (0) NULL,
    [UpdateUserID]  INT           NULL,
    [IsDeleted]     BIT           DEFAULT ((0)) NOT NULL,
    CONSTRAINT [FK_MabaCommentsToOrderDetails_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

