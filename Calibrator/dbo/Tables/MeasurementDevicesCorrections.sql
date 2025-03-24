CREATE TABLE [dbo].[MeasurementDevicesCorrections] (
    [ID]                   INT              IDENTITY (1, 1) NOT NULL,
    [Value1]               DECIMAL (25, 15) NOT NULL,
    [Value2]               DECIMAL (25, 15) NULL,
    [Deviation]            DECIMAL (35, 15) NULL,
    [Note]                 VARCHAR (300)    NULL,
    [MeasurementDevicesId] INT              NOT NULL,
    [MeasurementId]        INT              NOT NULL,
    [UnitID]               INT              NOT NULL,
    [DateAdded]            DATETIME         CONSTRAINT [DF_MeasurementDevicesCorrections_DateAdded_1] DEFAULT (getdate()) NULL,
    [CorVersion]           INT              CONSTRAINT [DF_MeasurementDevicesCorrections_CorVersion] DEFAULT ((1)) NOT NULL,
    [DepartmentId]         INT              NULL,
    [Equation]             VARCHAR (300)    NOT NULL,
    CONSTRAINT [PK_tblInstrCorrections] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (FILLFACTOR = 90),
    CONSTRAINT [FK_MeasurementDevicesCorrections_Department] FOREIGN KEY ([DepartmentId]) REFERENCES [dbo].[Departments] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesCorrections_MeasurementDevicesId] FOREIGN KEY ([MeasurementDevicesId]) REFERENCES [dbo].[MeasurementDevices] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesCorrections_MeasurementId] FOREIGN KEY ([MeasurementId]) REFERENCES [dbo].[Measurements] ([ID]),
    CONSTRAINT [FK_MeasurementDevicesCorrections_UnitID] FOREIGN KEY ([UnitID]) REFERENCES [dbo].[Units] ([ID])
);

