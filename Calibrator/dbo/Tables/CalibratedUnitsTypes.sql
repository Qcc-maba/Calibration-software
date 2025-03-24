CREATE TABLE [dbo].[CalibratedUnitsTypes] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [Name]        NVARCHAR (50) NOT NULL,
    [Description] VARCHAR (50)  NULL,
    [DateAdd]     DATETIME      CONSTRAINT [DF_CalibratedUnitsTypes_DateAdd] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_CalibratedUnitsTypes] PRIMARY KEY CLUSTERED ([ID] ASC)
);

