/*
    MeasurmentPointsToOrderDetailsItems.PairId                                          MBA-802
    ---------------------------------------------------------------------------------------------
    A humidity device is calibrated for temperature and %RH at once, and the sensors table shows
    each measuring point as a pair of rows: Temperature, then RH. Until now the app paired the two
    rows by their channel, which the ticket never asked for: a pair added with an empty channel was
    saved on the placeholder channel 99, and after a reload every such pair on a device was matched
    again by row order - so one Temperature row could end up beside another pair's RH row.

    PairId records which two rows are one measuring point. The app generates it when "add" creates
    the pair, and both rows carry it. Everything else a row is tied to stays as it is:
    OrderDetailsItemId (the device on the order line), SensorMeasurementDeviceId (the master
    sensor), MbaReportNumber, SerialNumber.

    NULL on every row that is not part of a pair, which is every existing row (STAGE has one %RH
    row in the whole table, 2026-10-29). No index: the app reads a device's rows by
    OrderDetailsItemId and groups them in memory.

    Written by dbo.AssignMeasurmentPointsToOrderDetailsItemsV2, read by
    dbo.GetCalibrationValuesForOrderDetailItem.
*/
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems') AND name = 'PairId')
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD PairId UNIQUEIDENTIFIER NULL;
GO
