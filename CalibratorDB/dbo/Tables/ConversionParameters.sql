CREATE TABLE [dbo].[ConversionParameters] (
    [ConversionParameterId] INT              IDENTITY (1, 1) NOT NULL,
    [RTP]                   DECIMAL (35, 15) NULL,
    [A4]                    DECIMAL (35, 15) NULL,
    [B4]                    DECIMAL (35, 15) NULL,
    [A7]                    DECIMAL (35, 15) NULL,
    [B7]                    DECIMAL (35, 15) NULL,
    [C7]                    DECIMAL (35, 15) NULL,
    [CreatedDate]           DATETIME2 (0)    DEFAULT (getdate()) NOT NULL,
    [UpdatedDate]           DATETIME2 (0)    NULL,
    [IsDeleted]             BIT              DEFAULT ((0)) NOT NULL,
    [UpdateUserID]          INT              NULL,
    PRIMARY KEY CLUSTERED ([ConversionParameterId] ASC),
    CONSTRAINT [FK_ConversionParameters_UpdateUserID] FOREIGN KEY ([UpdateUserID]) REFERENCES [dbo].[Users] ([ID])
);

