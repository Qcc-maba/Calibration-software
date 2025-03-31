CREATE TABLE [dbo].[MeasurementDevicesParents] (
    [ID]       INT IDENTITY (1, 1) NOT NULL,
    [DeviceId] INT NOT NULL,
    [ParentId] INT NULL,
    CONSTRAINT [PK_MeasurementDevicesParents] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (FILLFACTOR = 90)
);

