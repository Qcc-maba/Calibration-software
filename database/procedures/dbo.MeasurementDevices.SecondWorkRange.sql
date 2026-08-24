/*
    dbo.MeasurementDevices - second work range                                         MBA-902
    ---------------------------------------------------------------------------------------------
    Some sensors measure two things at once - a temperature range and a relative-humidity range -
    and the row could only hold one. WorkRangeMin/Max/UnitId stayed NULL for all of them, so the
    calibration popup showed 0 under תחום תחתון and תחום עליון.

    Adds a second, optional set of the same three columns. Two, not N, because the registry has
    never held more than two and a child table would force every existing consumer of
    WorkRangeMin/Max to change for a case that does not occur.

    Slot 1 is always the temperature range where there is one, so the primary slot means the same
    thing across the whole fleet regardless of the order the text happened to be written in
    ('0÷100%RH;-40÷60°C' and '-40÷60°C;0÷100RH' are the same sensor spec written two ways).

    Nullable and with no default, so the SSIS packages that write this table by named column are
    unaffected.
*/
IF COL_LENGTH('dbo.MeasurementDevices', 'WorkRangeMin2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMin2 NUMERIC(18, 6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices', 'WorkRangeMax2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeMax2 NUMERIC(18, 6) NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices', 'WorkRangeUnitId2') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD WorkRangeUnitId2 INT NULL;
GO
