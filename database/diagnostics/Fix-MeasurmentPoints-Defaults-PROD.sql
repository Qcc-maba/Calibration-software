/*
    Why the calibration wizard cannot leave the calibration stage on PROD.

    devices.assignMeasurmentPointsToCalibrationCycle returns 500. Reproduced inside a rolled-back
    transaction on 07/09/2026 with the payload the wizard sends:

        CalibratorProd:  Cannot insert the value NULL into column 'CreateDate',
                         table 'CalibratorProd.dbo.MeasurmentPointsToCalibrationCycles';
                         column does not allow nulls. UPDATE fails.

    The procedure is byte-for-byte the same on STAGE and PROD (the only diff is a trailing blank
    line). The TABLE is not. Its MERGE inserts without naming CreateDate or IsDeleted and relies on
    their defaults, which exist on STAGE and are missing on PROD:

        column      Calibrator (STAGE)                 CalibratorProd (PROD)
        CreateDate  datetime2 NOT NULL DEFAULT getdate()   datetime2 NOT NULL, no default
        IsDeleted   bit       NOT NULL DEFAULT 0           bit       NOT NULL, no default

    Every other column matches. This is the STAGE-only schema drift CLAUDE.md warns about, and
    database\Compare-Schema.ps1 would have shown it.

    The fix is two default constraints. Adding a default does not touch existing rows and cannot
    fail on them. Run on CalibratorProd.
*/
USE [CalibratorProd];
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles'), 'CreateDate', 'ColumnId'))
BEGIN
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles
        ADD CONSTRAINT DF_MeasurmentPointsToCalibrationCycles_CreateDate DEFAULT (GETDATE()) FOR CreateDate;
    PRINT 'CreateDate default added';
END
ELSE
    PRINT 'CreateDate already has a default';
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE parent_object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles')
                 AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles'), 'IsDeleted', 'ColumnId'))
BEGIN
    ALTER TABLE dbo.MeasurmentPointsToCalibrationCycles
        ADD CONSTRAINT DF_MeasurmentPointsToCalibrationCycles_IsDeleted DEFAULT ((0)) FOR IsDeleted;
    PRINT 'IsDeleted default added';
END
ELSE
    PRINT 'IsDeleted already has a default';
GO

-- verify: both rows should now show a default, matching STAGE
SELECT c.name, DefaultDef = dc.definition
FROM sys.columns c
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
WHERE c.object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles')
  AND c.name IN ('CreateDate', 'IsDeleted');
GO
