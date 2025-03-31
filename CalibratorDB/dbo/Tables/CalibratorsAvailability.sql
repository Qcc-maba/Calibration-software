CREATE TABLE [dbo].[CalibratorsAvailability] (
    [ID]     INT           IDENTITY (1, 1) NOT NULL,
    [Status] NVARCHAR (25) NOT NULL,
    CONSTRAINT [PK_CalibratorsAvailability] PRIMARY KEY CLUSTERED ([ID] ASC)
);

