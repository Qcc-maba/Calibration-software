CREATE TABLE [dbo].[MabaComments] (
    [MabaCommentId] INT             IDENTITY (1, 1) NOT NULL,
    [MabaComment]   VARBINARY (MAX) NULL,
    [PART]          INT             NULL,
    [SourceId]      TINYINT         NULL,
    [TextHash]      INT             NULL,
    [CreateDate]    DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]   DATETIME2 (0)   NULL,
    [UpdateUserID]  INT             NULL,
    [IsDeleted]     BIT             DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_MabaComments] PRIMARY KEY CLUSTERED ([MabaCommentId] ASC),
    CONSTRAINT [FK_MabaComments_SourceId] FOREIGN KEY ([SourceId]) REFERENCES [dbo].[Source] ([SourceId]),
    CONSTRAINT [FK_MabaComments_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);






GO
