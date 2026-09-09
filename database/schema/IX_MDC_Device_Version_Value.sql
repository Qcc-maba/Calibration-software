/*
    IX_MDC_Device_Version_Value                                                        MBA-811
    ---------------------------------------------------------------------------------------------
    dbo.MeasurementDevicesCorrections had ONE index: the clustered primary key on ID. Every read of
    it asks the same question - "this device, its newest certificate, the points either side of a
    reading" - and none of that is served by a key on ID, so each lookup scanned all 30,520 rows.

    That was tolerable while the table was only read occasionally. It stopped being tolerable when
    GetCalibrationValuesForManyOrderDetailItems began calling dbo.fnMasterValueAfterCorrection per
    row, and it will be called after every save now that the wizard refetches on each one.

    Measured on STAGE, 118 items / 432 rows returned:

        without the compensation call   113 ms
        with it, no index             2,122 ms
        with it, this index             269 ms

    The DESC on CorVersion matches how the function reads it - newest first. Deviation,
    MeasurementId, IsDeleted and Value2 are included so the lookup never leaves the index.

    dbo.GetSensorByName asks the same question for the Hydra C# and benefits too.
*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MDC_Device_Version_Value')
CREATE NONCLUSTERED INDEX IX_MDC_Device_Version_Value
    ON dbo.MeasurementDevicesCorrections (MeasurementDevicesId, CorVersion DESC, Value1)
    INCLUDE (Deviation, MeasurementId, IsDeleted, Value2);
GO
