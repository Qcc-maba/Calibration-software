CREATE TABLE [dbo].[CalibratedUnitsWorkStatus] (
    [Id]     INT           IDENTITY (1, 1) NOT NULL,
    [Status] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_CalibratedUnitsWorkStatus] PRIMARY KEY CLUSTERED ([Id] ASC)
);

