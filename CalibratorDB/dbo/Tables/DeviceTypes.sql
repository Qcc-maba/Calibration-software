CREATE TABLE [dbo].[DeviceTypes] (
    [ID]          INT           IDENTITY (1, 1) NOT NULL,
    [NameHe]      VARCHAR (50)  NULL,
    [NameEn]      NVARCHAR (50) NULL,
    [Description] VARCHAR (50)  NULL,
    [DateAdd]     DATETIME      CONSTRAINT [DF_MeasurementDevicesType_DateAdd] DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_MeasurementDevicesType] PRIMARY KEY CLUSTERED ([ID] ASC)
);

