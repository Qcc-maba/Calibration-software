CREATE TABLE [dbo].[MeasurementDevicesModels] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [Model]       NVARCHAR (50) NOT NULL,
    [Description] NVARCHAR (50) NULL,
    [DateAdd]     DATETIME      CONSTRAINT [DF_MeasurementDevicesModels_DateAdd] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_MeasurementDevicesModels] PRIMARY KEY CLUSTERED ([ID] ASC)
);

