/*
    CalibrationCycles - the rest of the Summary screen, per cycle                       MBA-980
    ---------------------------------------------------------------------------------------------
    The first round (dbo.CalibrationCycles.ChamberSettings.sql) stored the Tolerance, resolution,
    uncertainty and the two thresholds. The Summary screen has more per-cycle inputs, and they were
    lost on a refresh: a regenerated report showed the set value as the chamber's Display reading,
    so Display Correction changed with it (Kate, MBA-980 13/11). Nofar, 15/11, Jira 38258: save
    all of these with the cycle, and carry them over from the device's previous calibration like
    the Tolerance.

        DisplayValue            the reading copied from the chamber's own display
        DisplayResolution       the resolution next to it
        IsDisplayEnabled        0 = the chamber has no display for this cycle: the report leaves
                                out Display and Display Correction
        IsTargetValueEnabled    the Target Value checkbox
        ControllerTypeStatusId  Digital / Analog: a dbo.Statuses row of category 'ControllerType'
                                (database/data/Seed-ControllerTypeStatuses.sql), so the labels come
                                in both languages from dbo.GetStatusByCategory
        ControllerManufacturer  the controller's manufacturer and model; the app starts them from
        ControllerModel         the device's, which is why they have the same size (100)
        CalculationResolution   the Calculation Resolution

    All nullable; NULL = not set, and the app shows its usual starting value. Display Correction
    and Controller Correction are calculated, not stored.

    Stability and Uniformity need no column of their own: Nofar 15/11 - an unchecked box saves no
    value and stays unchecked when the order is reopened. So a saved threshold (0 included) means
    checked and NULL means unchecked; both boxes also start unchecked (Nofar 20/10), so "never
    saved" and "unchecked" are the same thing.

    Written by dbo.SaveCalibrationCycleSettings only. Every existing row gets NULL.
    The foreign key is database/constraints/FK_CalibrationCycles_ControllerTypeStatusId.sql, the
    resolutions' sign rule (>= 0) database/constraints/CK_CalibrationCycles_SummarySettings.sql.
*/
IF COL_LENGTH('dbo.CalibrationCycles', 'DisplayValue') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD DisplayValue DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'DisplayResolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD DisplayResolution DECIMAL(18,6) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'IsDisplayEnabled') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD IsDisplayEnabled BIT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'IsTargetValueEnabled') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD IsTargetValueEnabled BIT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'ControllerTypeStatusId') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ControllerTypeStatusId INT NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'ControllerManufacturer') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ControllerManufacturer NVARCHAR(100) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'ControllerModel') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD ControllerModel NVARCHAR(100) NULL;
GO
IF COL_LENGTH('dbo.CalibrationCycles', 'CalculationResolution') IS NULL
    ALTER TABLE dbo.CalibrationCycles ADD CalculationResolution DECIMAL(18,6) NULL;
GO
