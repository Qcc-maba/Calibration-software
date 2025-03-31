CREATE TABLE [dbo].[MeasurementDevicesSubClass] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [Name]        NVARCHAR (50) NOT NULL,
    [Description] NCHAR (10)    NULL,
    [DateAdd]     DATETIME      CONSTRAINT [DF_MeasurementDevicesFunction_DateAdd] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_MeasurementDevicesFunction] PRIMARY KEY CLUSTERED ([ID] ASC)
);

