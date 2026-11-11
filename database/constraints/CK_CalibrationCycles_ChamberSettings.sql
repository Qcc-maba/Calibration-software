/*
    CK_CalibrationCycles_ToleranceStart / _ToleranceEnd / _StabilityThreshold /
    CK_CalibrationCycles_UniformityThreshold                                            MBA-980
    ---------------------------------------------------------------------------------------------
    The sign rules of a cycle's chamber settings (dbo.CalibrationCycles.ChamberSettings.sql):

        ToleranceStart       <= 0   the lower border is an offset below the middle value
        ToleranceEnd         >= 0   the upper border is an offset above it
        StabilityThreshold   >= 0   a threshold above 0 is what turns its check on;
        UniformityThreshold  >= 0   a negative one has no meaning (user, 2026-10-20)

    NULL passes every rule (= not set). dbo.SaveCalibrationCycleSettings checks the same rules first
    and refuses with a readable message; these constraints make sure no other writer gets past them.

    WITH CHECK: the columns are new and every row is NULL, so there is nothing to grandfather.
    Run after dbo.CalibrationCycles.ChamberSettings.sql.
*/
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_ToleranceStart')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_ToleranceStart CHECK (ToleranceStart <= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_ToleranceEnd')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_ToleranceEnd CHECK (ToleranceEnd >= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_StabilityThreshold')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_StabilityThreshold CHECK (StabilityThreshold >= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_CalibrationCycles_UniformityThreshold')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT CK_CalibrationCycles_UniformityThreshold CHECK (UniformityThreshold >= 0);
GO

SELECT ConstraintName = c.name, IsNotTrusted = c.is_not_trusted, Definition = c.definition
FROM sys.check_constraints AS c
WHERE c.parent_object_id = OBJECT_ID('dbo.CalibrationCycles')
ORDER BY c.name;
GO
