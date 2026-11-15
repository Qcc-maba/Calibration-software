/*
    CK_CalibrationCycles_DisplayResolution / _CalculationResolution                        MBA-980
    ---------------------------------------------------------------------------------------------
    The sign rule of the two Summary resolutions (dbo.CalibrationCycles.SummarySettings.sql):

        DisplayResolution      >= 0
        CalculationResolution  >= 0

    A negative resolution has no meaning. 0 is allowed because the Summary screen starts both at 0.
    NULL passes (= not set). dbo.SaveCalibrationCycleSettings checks the same rule first and refuses
    with a readable message; these constraints make sure no other writer gets past it.

    WITH CHECK: the columns are new and every row is NULL.
    Run after database/schema/dbo.CalibrationCycles.SummarySettings.sql.
*/
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_DisplayResolution')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_DisplayResolution CHECK (DisplayResolution >= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_CalculationResolution')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_CalculationResolution CHECK (CalculationResolution >= 0);
GO

SELECT ConstraintName = c.name, IsNotTrusted = c.is_not_trusted, Definition = c.definition
FROM sys.check_constraints AS c
WHERE c.parent_object_id = OBJECT_ID('dbo.CalibrationCycles')
  AND c.name IN ('CK_CalibrationCycles_DisplayResolution', 'CK_CalibrationCycles_CalculationResolution')
ORDER BY c.name;
GO
