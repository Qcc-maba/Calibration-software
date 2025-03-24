CREATE TABLE [dbo].[ConversionParameters] (
    [ConversionParameterId] INT              IDENTITY (1, 1) NOT NULL,
    [RTP]                   DECIMAL (35, 15) NULL,
    [A4]                    DECIMAL (35, 15) NULL,
    [B4]                    DECIMAL (35, 15) NULL,
    [A7]                    DECIMAL (35, 15) NULL,
    [B7]                    DECIMAL (35, 15) NULL,
    [C7]                    DECIMAL (35, 15) NULL,
    PRIMARY KEY CLUSTERED ([ConversionParameterId] ASC)
);

