CREATE TABLE [dbo].[CalibrationProcessComments] (
    [OrderDetailsItemId]        INT             NOT NULL,
    [CalibrationProcessComment] VARBINARY (MAX) NULL,
    [TextHash]                  INT             NULL,
    [CreateDate]                DATETIME2 (0)   DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]               DATETIME2 (0)   NULL,
    [UpdateUserID]              INT             NULL,
    [IsDeleted]                 BIT             DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([OrderDetailsItemId] ASC),
    CONSTRAINT [FK_CalibrationProcessComments_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

