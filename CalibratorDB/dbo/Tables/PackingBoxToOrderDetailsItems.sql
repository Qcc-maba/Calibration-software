CREATE TABLE [dbo].[PackingBoxToOrderDetailsItems] (
    [OrderDetailsItemId] INT           NOT NULL,
    [PackingBoxId]       INT           NOT NULL,
    [CreateDate]         DATETIME2 (0) DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]        DATETIME2 (0) NULL,
    [UpdateUserID]       INT           NULL,
    [IsDeleted]          BIT           DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([OrderDetailsItemId] DESC, [PackingBoxId] ASC, [CreateDate] ASC)
);

