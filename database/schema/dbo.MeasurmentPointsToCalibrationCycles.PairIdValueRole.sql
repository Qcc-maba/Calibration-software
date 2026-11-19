/*
    MeasurmentPointsToCalibrationCycles.PairId / ValueRole                                MBA-800
    ---------------------------------------------------------------------------------------------
    The cycle's copy of a point carries the same two facts as the order line's point
    (dbo.MeasurmentPointsToOrderDetailsItems.ValueRole.sql has the why):

        ValueRole   1 = temperature, 2 = the chamber's second value (RH), NULL = not stated
                    (every existing row)
        PairId      the two rows of one Temperature + RH position share it; NULL otherwise

    The Summary page filters a cycle's points by ValueRole, so the temperature view never counts
    an RH channel and the RH view never counts a temperature one.

    Written by dbo.AssignMeasurmentPointsToCalibrationCycle. Read by
    dbo.GetMeasurmentPointsForCalibrationCycle, which is SELECT * and needs no change.
    No index: read per cycle.
*/
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles') AND name = 'PairId')
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles ADD PairId UNIQUEIDENTIFIER NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles') AND name = 'ValueRole')
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles ADD ValueRole TINYINT NULL;
GO
IF OBJECT_ID('dbo.CK_MeasurmentPointsToCalibrationCycles_ValueRole', 'C') IS NULL
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles ADD CONSTRAINT CK_MeasurmentPointsToCalibrationCycles_ValueRole
        CHECK (ValueRole IN (1, 2));
GO
