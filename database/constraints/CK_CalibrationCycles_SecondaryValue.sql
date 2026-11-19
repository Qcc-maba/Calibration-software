/*
    CalibrationCycles - sign rules and unit key of the second measured value              MBA-800
    The same rules as the temperature value's (CK_CalibrationCycles_ChamberSettings.sql,
    CK_CalibrationCycles_SummarySettings.sql), so a direct UPDATE cannot store what
    dbo.SaveCalibrationCycleSecondarySettings refuses. The columns are new and NULL everywhere, so
    nothing can violate these when they are added.
*/
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryToleranceStart', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryToleranceStart
        CHECK (SecondaryToleranceStart <= 0);
GO
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryToleranceEnd', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryToleranceEnd
        CHECK (SecondaryToleranceEnd >= 0);
GO
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryStabilityThreshold', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryStabilityThreshold
        CHECK (SecondaryStabilityThreshold >= 0);
GO
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryUniformityThreshold', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryUniformityThreshold
        CHECK (SecondaryUniformityThreshold >= 0);
GO
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryDisplayResolution', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryDisplayResolution
        CHECK (SecondaryDisplayResolution >= 0);
GO
IF OBJECT_ID('dbo.CK_CalibrationCycles_SecondaryCalculationResolution', 'C') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT CK_CalibrationCycles_SecondaryCalculationResolution
        CHECK (SecondaryCalculationResolution >= 0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = 'FK_CalibrationCycles_SecondaryUnitId'
                 AND parent_object_id = OBJECT_ID('dbo.CalibrationCycles'))
    ALTER TABLE dbo.CalibrationCycles ADD CONSTRAINT FK_CalibrationCycles_SecondaryUnitId
        FOREIGN KEY (SecondaryUnitId) REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId);
GO
