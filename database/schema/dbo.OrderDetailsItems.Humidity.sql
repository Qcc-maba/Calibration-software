/*
    OrderDetailsItems.HumidityAccuracy / HumidityTolerance / HumidityResolution        MBA-802
    ---------------------------------------------------------------------------------------------
    A device whose secondary category is "Humidity" is calibrated for two quantities at once:
    temperature and relative humidity. Page 1 of the calibration wizard now asks for two sets of
    Guard Band, tolerance and resolution, one per quantity.

    The device row had room for one set only: Accuracy (the Guard Band, TINYINT), Tolerance and
    Resolution (DECIMAL(18,6)), with MeasurementUnitId as their unit. Those keep holding the
    temperature set, so every existing device and every screen reading them is unchanged.

    The humidity set gets its own three columns, typed exactly like their temperature siblings.
    There is no humidity unit column: the humidity unit is always %RH (MeasurementDeviceUnits 30),
    so a column would only ever hold one value.

    All three are NULL, and stay NULL on every device that is not a humidity calibration.
    Written by dbo.AssignProductIdentificationData, read by dbo.GetOrderDetailsDevices.
*/
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'HumidityAccuracy')
    ALTER TABLE dbo.OrderDetailsItems ADD HumidityAccuracy TINYINT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'HumidityTolerance')
    ALTER TABLE dbo.OrderDetailsItems ADD HumidityTolerance DECIMAL(18,6) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'HumidityResolution')
    ALTER TABLE dbo.OrderDetailsItems ADD HumidityResolution DECIMAL(18,6) NULL;
GO
