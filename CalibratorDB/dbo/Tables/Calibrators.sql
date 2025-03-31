CREATE TABLE [dbo].[Calibrators] (
    [ID]                  INT           IDENTITY (1, 1) NOT NULL,
    [UserId]              INT           NOT NULL,
    [Availability]        INT           NULL,
    [AvailbilityDateFrom] DATETIME2 (7) NULL,
    [AvailbilityDateTo]   DATETIME2 (7) NULL,
    [RankId]              INT           NULL,
    [Signature]           VARCHAR (MAX) NULL,
    [StampNo]             INT           NULL,
    CONSTRAINT [PK_Calibrators_1] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_Calibrators_Users] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users] ([ID])
);


GO
CREATE NONCLUSTERED INDEX [IX_Calibrators]
    ON [dbo].[Calibrators]([ID] ASC, [UserId] ASC);

