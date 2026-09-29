/*
    dbo.ConversionParameters - tie each coefficient set to its sensor                  MBA-816
    ---------------------------------------------------------------------------------------------
    A precision resistance thermometer is converted from ohms to degrees with ITS-90 plus its own
    coefficients: RTP (resistance at the triple point of water), A4/B4 (below 0 degC) and A7/B7/C7
    (above it). Every sensor has its own set, and the lab needs them stored per sensor, by MabaID
    (Nofar, MBA-816, 24/09).

    The table for them has existed on STAGE and PROD since about March 2025, with exactly those six
    columns - but no column saying WHICH sensor a row belongs to, so a stored set could never be
    found again. It has 0 rows on both servers, and nothing in either repo reads or writes it.

    This file finishes it:
      MeasurementDevicesId  NOT NULL - the sensor (dbo.MeasurementDevices), found by MabaID
      OrderDetailsItemId    NULL     - the calibration the coefficients came from, when there was one;
                                       they can also be entered by hand (MBA-831)
      RTP .. C7             NOT NULL - all six are required (Nofar, 29/09). A sensor used in one range
                                       only gets zeros for the other range's coefficients.

    Adding a NOT NULL column with no default is only possible on an EMPTY table, which is also the
    only state in which it is honest: an existing row would need a sensor nobody recorded. So the
    file refuses to run if rows have appeared, rather than inventing one.

    Replayable on either server: every step checks whether it has already been done.

    The guards below stop the WHOLE file, not just their own batch. A THROW ends only the batch it
    is in; SSMS, and sqlcmd without -b, carry on after GO - so the file could add OrderDetailsItemId
    and then fail on MeasurementDevicesId, leaving the table half-changed. SET NOEXEC ON makes every
    later batch compile but not run, whichever tool runs the file. The last line turns it off again.
*/
SET NOCOUNT ON;

/* rows have appeared: a required sensor column cannot be invented for them */
IF COL_LENGTH('dbo.ConversionParameters', 'MeasurementDevicesId') IS NULL
   AND EXISTS (SELECT 1 FROM dbo.ConversionParameters)
BEGIN
    RAISERROR('dbo.ConversionParameters has rows but no MeasurementDevicesId - each row needs its sensor assigned by hand before this can run. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;

/* the ALTER COLUMNs below restate the type as DECIMAL(35,15) - true on STAGE and PROD (checked
   29/09). If a server declares them differently, stop rather than silently change the type. */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.ConversionParameters')
             AND name IN ('RTP', 'A4', 'B4', 'A7', 'B7', 'C7')
             AND NOT (TYPE_NAME(user_type_id) = 'decimal' AND precision = 35 AND scale = 15))
BEGIN
    RAISERROR('A dbo.ConversionParameters coefficient column is not DECIMAL(35,15) here - check the type before running this. Nothing was changed.', 16, 1);
    SET NOEXEC ON;
END;
GO

IF COL_LENGTH('dbo.ConversionParameters', 'MeasurementDevicesId') IS NULL
    ALTER TABLE dbo.ConversionParameters ADD MeasurementDevicesId INT NOT NULL;
GO

IF COL_LENGTH('dbo.ConversionParameters', 'OrderDetailsItemId') IS NULL
    ALTER TABLE dbo.ConversionParameters ADD OrderDetailsItemId INT NULL;
GO

/* the six coefficients: required. Only possible while no row holds a NULL - true of an empty table. */
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.ConversionParameters')
             AND name IN ('RTP', 'A4', 'B4', 'A7', 'B7', 'C7') AND is_nullable = 1)
BEGIN
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN RTP DECIMAL(35,15) NOT NULL;
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN A4  DECIMAL(35,15) NOT NULL;
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN B4  DECIMAL(35,15) NOT NULL;
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN A7  DECIMAL(35,15) NOT NULL;
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN B7  DECIMAL(35,15) NOT NULL;
    ALTER TABLE dbo.ConversionParameters ALTER COLUMN C7  DECIMAL(35,15) NOT NULL;
END;
GO

SET NOEXEC OFF;
GO
