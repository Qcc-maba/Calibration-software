CREATE TABLE [dbo].[CalibratedUnitsStatusDescription] (
    [Id]          INT           IDENTITY (1, 1) NOT NULL,
    [Description] NVARCHAR (50) NOT NULL,
    CONSTRAINT [PK_CalibratedUnitsStatusDescription] PRIMARY KEY CLUSTERED ([Id] ASC)
);

