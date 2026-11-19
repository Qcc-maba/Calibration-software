/*
    CalibrationCycles - the second measured value of a cycle                              MBA-800
    ---------------------------------------------------------------------------------------------
    A Temperature + RH chamber runs each cycle at a temperature set point and an RH set point at the
    same time, and Nofar's acceptance criteria say the cycle's markers cut the same time range for
    both, while each value keeps its own set point, tolerance, unit, results and conclusion.

    So the cycle row stays one row: its name, its start and end, its markers and its controller are
    shared. Its existing settings (UnitId, TestedValue and the MBA-980 Summary columns) keep holding
    the temperature value. The second value gets the same settings under a Secondary prefix:

        SecondaryUnitId                 the second value's unit (a dbo.MeasurementDeviceUnits row);
                                        NULL = this cycle has no second set point (a Temperature + RH
                                        chamber can run a cycle at a temperature only)
        SecondaryTestedValue            its set point
        SecondaryToleranceValue/Start/End, SecondaryResolution, SecondaryUncertainty,
        SecondaryStabilityThreshold, SecondaryUniformityThreshold, SecondaryDisplayValue,
        SecondaryDisplayResolution, SecondaryIsDisplayEnabled, SecondaryIsTargetValueEnabled,
        SecondaryCalculationResolution  the Summary screen settings, with exactly the meaning and
                                        the sign rules of their temperature siblings

    The controller (ControllerTypeStatusId, ControllerManufacturer, ControllerModel) is the
    chamber's and is not repeated.

    Why columns and not a child table keyed by the cycle: cycles have no id, and the app moves a
    cycle to a new start time by copying its row to the new key (devices.ts updateCalibrationCycle).
    Columns move with that copy once they are in its column list; a child table would need its own
    move step in every path that moves a cycle. There are only ever two values per cycle.
    Why not one cycle row per value: the key is (OrderDetailsItemId, CalibrationCycleStartDate), so
    two rows covering the same time range cannot exist.

    All NULL on every existing row. Written by dbo.SaveCalibrationCycleSecondarySettings only; read
    by dbo.GetCalibrationCycles and dbo.GetPreviousCalibrationCycleSettings. The sign rules and the
    unit's foreign key are database/constraints/CK_CalibrationCycles_SecondaryValue.sql.
*/
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryUnitId') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryUnitId INT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryTestedValue') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryTestedValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryToleranceValue') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryToleranceValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryToleranceStart') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryToleranceStart DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryToleranceEnd') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryToleranceEnd DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryResolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryResolution DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryUncertainty') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryUncertainty DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryStabilityThreshold') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryStabilityThreshold DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryUniformityThreshold') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryUniformityThreshold DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryDisplayValue') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryDisplayValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryDisplayResolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryDisplayResolution DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryIsDisplayEnabled') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryIsDisplayEnabled BIT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryIsTargetValueEnabled') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryIsTargetValueEnabled BIT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'SecondaryCalculationResolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD SecondaryCalculationResolution DECIMAL(18,6) NULL;
GO
