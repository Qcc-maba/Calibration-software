/*
    Putting sensor 21-214's ITS-90 coefficients on file                                 MBA-831
    ---------------------------------------------------------------------------------------------
    Until MBA-831 the station converted every precision sensor's resistance to temperature with
    21-214's coefficients, hard-coded in HydraCalculations.CalcResistanceToTemperatureITS90. The
    station now reads each master's own set through dbo.GetSensorCoefficients and refuses a master
    with none on file, rather than giving it 21-214's numbers.

    dbo.ConversionParameters had 0 rows on STAGE and PROD on 2026-10-25, and there is no screen to
    enter coefficients yet. Without this script, 21-214 - the sensor the hard-coded values were
    measured for - would stop converting the day the new station build is installed. These are
    exactly the values that were in the code, so 21-214 converts as it did before.

    Run it on a server only after dbo.ConversionParameters' MBA-816 columns and
    dbo.SaveSensorCoefficients are there (PROD did not have them on 2026-10-25), and before the
    station build that reads them.

    ADDRESSED BY MabaID, NOT BY MeasurementDevicesId: 21-214 is device 749 on STAGE and 331 on
    PROD. dbo.SaveSensorCoefficients resolves the MabaID and refuses one held by two live devices.

    @Apply = 0 (default) reports what would be saved and writes nothing. Re-running after an apply
    reports NoChange: the procedure adds a row only when the values differ from 21-214's newest set.
*/
DECLARE @Apply BIT = 0;
DECLARE @LoggedInUserEmail NVARCHAR(255) = N'ezequiel_lo@mba.co.il';

EXEC dbo.SaveSensorCoefficients
    @LoggedInUserEmail = @LoggedInUserEmail,
    @MabaID            = N'21-214',
    @RTP               = 100.0018614,
    @A4                = -0.0188349,
    @B4                = 0.00064590173677,
    @A7                = -0.01943119,
    @B7                = -0.00032928408,
    @C7                = 0.00022327774,
    @Apply             = @Apply;
