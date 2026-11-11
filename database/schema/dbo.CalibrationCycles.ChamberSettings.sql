/*
    CalibrationCycles - chamber settings per cycle                                      MBA-980
    ---------------------------------------------------------------------------------------------
    A chamber calibration has one or more cycles, and the calibrator sets per cycle the values the
    Summary screen evaluates against: the Tolerance (a middle value with a lower and an upper
    border; the graph screen edits the same tolerance), the set-value resolution, the uncertainty,
    and the stability and uniformity thresholds. None of this was stored. It lived in the browser
    only, so a reload or re-opening the order lost it, and the next calibration of the same device
    started from scratch (Nofar, MBA-980).

    Seven nullable columns, all DECIMAL(18,6) like TestedValue. NULL = "not set": the app fills in
    the starting value it calculates (the middle tolerance from TestedValue, the resolution from the
    set value's decimals) or the one carried over from the device's previous calibration.

    The Stability / Uniformity checkboxes are deliberately not stored (decided 2026-10-20): a
    threshold above 0 means its check is on.

    Sign rules: CHECK constraints in database/constraints/CK_CalibrationCycles_ChamberSettings.sql.
    Written by dbo.SaveCalibrationCycleSettings only (dbo.AddCalibrationCycle does not touch them,
    so a save from the graph screen cannot wipe them). Read by dbo.GetCalibrationCycles and
    dbo.GetPreviousCalibrationCycleSettings.

    Every existing row gets NULL in all seven (STAGE copy 2026-11-10: 242 rows, 111 live).
*/
IF COL_LENGTH('dbo.CalibrationCycles', 'ToleranceValue') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ToleranceValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'ToleranceStart') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ToleranceStart DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'ToleranceEnd') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ToleranceEnd DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'Resolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD Resolution DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'Uncertainty') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD Uncertainty DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'StabilityThreshold') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD StabilityThreshold DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'UniformityThreshold') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD UniformityThreshold DECIMAL(18,6) NULL;
GO
