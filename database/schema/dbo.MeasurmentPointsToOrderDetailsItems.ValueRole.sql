/*
    MeasurmentPointsToOrderDetailsItems.ValueRole                                         MBA-800
    ---------------------------------------------------------------------------------------------
    In a Temperature + RH chamber each value has its own measurement positions: "a chamber can
    have 9 temperature sensors and only 1 that also measures RH. When setting up the logger, the
    calibrator defines per channel, according to the sensor connected to the logger, whether it
    measures Temperature only or Temperature and RH" (Nofar, Jira 38328).

    A T/RH sensor reports its two readings on two logger channels, and a point row is wired to one
    channel. So a Temperature + RH position is two point rows of the same sensor:

        ValueRole   1 = the row reads the chamber's first value (temperature)
                    2 = the row reads the second value (RH)
                    NULL = not stated: every existing row, and every row of the sensors flow,
                           which tells T from RH by the row's unit (MBA-802)
        PairId      the two rows of one position share it. The column is MBA-802's
                    (dbo.MeasurmentPointsToOrderDetailsItems.PairId.sql), where the sensors flow
                    uses it the same way. NULL on a temperature-only position.

    Until now the app told a T channel from an RH channel only by the unit the logger reports at
    run time, which defaults to °C when it is missing - so an RH channel could be counted as
    temperature on the Summary page. The role is now saved with the point.

    The cycle-level table gets the same two columns
    (dbo.MeasurmentPointsToCalibrationCycles.PairIdValueRole.sql).
    Written by dbo.AssignMeasurmentPointsToOrderDetailsItems, read by
    dbo.GetMeasurmentPointsForOrderDetail. No index: read per order line.
*/
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems') AND name = 'ValueRole')
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD ValueRole TINYINT NULL;
GO
IF OBJECT_ID('dbo.CK_MeasurmentPointsToOrderDetailsItems_ValueRole', 'C') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems ADD CONSTRAINT CK_MeasurmentPointsToOrderDetailsItems_ValueRole
        CHECK (ValueRole IN (1, 2));
GO
