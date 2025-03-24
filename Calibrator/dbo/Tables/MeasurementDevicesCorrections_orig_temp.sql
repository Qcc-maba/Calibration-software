CREATE TABLE [dbo].[MeasurementDevicesCorrections_orig_temp] (
    [ID]                   INT             IDENTITY (1, 1) NOT NULL,
    [Value]                NUMERIC (18, 6) NOT NULL,
    [Deviation]            NUMERIC (20, 6) NULL,
    [Note]                 VARCHAR (300)   NULL,
    [MeasurementDevicesId] INT             NOT NULL,
    [MeasurementId]        INT             NOT NULL,
    [UnitID]               INT             NOT NULL,
    [DateAdded]            DATETIME        CONSTRAINT [DF_MeasurementDevicesCorrections_DateAdded] DEFAULT (getdate()) NULL,
    [CorVersion]           INT             CONSTRAINT [DF_MeasurementDevicesCorrections_Version] DEFAULT ((1)) NOT NULL,
    [Department]           INT             NULL,
    [Equation]             VARCHAR (300)   NOT NULL
);

