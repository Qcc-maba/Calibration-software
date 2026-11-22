/*
    OrderDetailsItems.SecondaryMeasurementUnitId / SecondaryMeasurementValueList          MBA-800
    ---------------------------------------------------------------------------------------------
    A chamber can be calibrated for two measured values at once: temperature plus RH, and later
    temperature plus CO2 or temperature plus pressure (Nofar, MBA-800). Each value has its own set
    points (Nofar, Jira 38328: "e.g. 20 °C for Temperature and 50 %RH for RH").

    The device row describes one value: MeasurementUnitId, MeasurementValueList (the set points,
    a comma-separated list), Accuracy (Guard Band), Tolerance and Resolution. Those keep holding the
    temperature value, so every existing device and every screen reading them is unchanged.

        SecondaryMeasurementUnitId    the unit of the second value. NULL = the chamber is calibrated
                                      for temperature only, which is every existing device. Its
                                      value says which pair it is: %RH = Temperature + RH.
        SecondaryMeasurementValueList the second value's set points, in that unit, comma-separated
                                      like MeasurementValueList.

    Why a unit and not a "pair" code: the pair's first value is always temperature, so the second
    value's unit is the whole of the choice, and the later phases need the unit anyway (the
    pressure unit is chosen per calibration: bar, mbar, Pa, kPa, hPa, atm, torr, psi, mmHg, inHg -
    all already rows of dbo.MeasurementDeviceUnits on STAGE, 2026-11-19).

    The second value's Guard Band, tolerance and resolution are the MBA-802 columns HumidityAccuracy,
    HumidityTolerance and HumidityResolution. They are named for humidity and hold %RH only, so
    dbo.AssignProductIdentificationData refuses any second unit other than %RH: CO2 and pressure
    must not be stored in a column called Humidity*. Those phases add their own storage.

    Both NULL on every existing row. Written by dbo.AssignProductIdentificationData, read by
    dbo.GetOrderDetailsDevices. The foreign key is
    database/constraints/FK_OrderDetailsItems_SecondaryMeasurementUnitId.sql.
*/
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'SecondaryMeasurementUnitId')
    ALTER TABLE dbo.OrderDetailsItems ADD SecondaryMeasurementUnitId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name = 'SecondaryMeasurementValueList')
    ALTER TABLE dbo.OrderDetailsItems ADD SecondaryMeasurementValueList NVARCHAR(MAX) NULL;
GO
