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
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH('dbo.ConversionParameters', 'MeasurementDevicesId') IS NULL
   AND EXISTS (SELECT 1 FROM dbo.ConversionParameters)
    THROW 51000, 'dbo.ConversionParameters has rows but no MeasurementDevicesId - each row needs its sensor assigned by hand before this can run.', 1;
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
