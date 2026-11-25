/*
    Tests for dbo.fnHumidityAfterCorrection                                              MBA-950
    ---------------------------------------------------------------------------------------------
    Run where dbo.MeasurementDevicesHumidityCorrections and the function are deployed. Anything
    other than PASS is a failure. Fixture points are written inside a transaction that is rolled
    back; the result is captured in a table variable, which the ROLLBACK does not undo.

    The expectations are literals worked by hand, not computed the way the function computes them.

    A. One temperature, three humidities (a certificate taken at 23 °C) - the 'line' case
         (23, 10) dev +0.4     (23, 50) dev 0.0     (23, 90) dev -0.8
         at 30 %RH:  halfway from 10 to 50  -> +0.4 + (0 - 0.4) * 20/40 = +0.2  -> 29.8
         at 30 %RH, 30 °C: same, a one-temperature certificate cannot vary with temperature
         at 30 %RH, no temperature: same
         at 95 %RH:  past the top, last segment continued: slope -0.8/40 = -0.02 per %RH,
                     -0.8 - 0.02 * 5 = -0.9 -> 95.9, Extrapolated and OutOfRange
    B. One triangle (15, 20) +0.5   (35, 20) +1.0   (25, 80) -1.0
         its plane: dev = a + b*T + c*H with b = 0.5/20 = 0.025, c = -1.75/60, a = 0.125 - 20c
         at (25, 40): 0.708333 + 0.625 - 1.166667 = 0.166667 -> 39.833333, inside
                      shown to 3 decimals (the reading has none): 39.833
         at (40, 20): outside, the plane continued: 0.708333 + 1.0 - 0.583333 = 1.125 -> 18.875
         at (25, 40) with no temperature: Method 'needs-temperature', no Deviation
    C. A second version on device A, one point (23, 50) +0.3: only the newest version is read,
       so at (23, 30) the deviation is +0.3 everywhere, Method 'single', Extrapolated.
    D. A device with nothing: no row.
    E. A master with a one-axis %RH curve over HUMIDITY and no points: the curve's deviation at
       the humidity reading, subtracted from the humidity. Compared with
       dbo.fnMasterValueAfterCorrection asked directly. SKIP when no such master exists.
    F. 30-1187-2, the one %RH curve laid over TEMPERATURE: the deviation is the curve at the
       temperature input; without a temperature, 'needs-temperature'. SKIP when absent.

    Run (local copy of STAGE, or STAGE):
        Invoke-CalibratorStageLocalSqlFile.ps1 -Path database\tests\Test-fnHumidityAfterCorrection.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(10));

/* two live devices with no certificate of either kind */
DECLARE @A INT, @B INT, @Z INT;
WITH Bare AS
(
    SELECT md.ID, Rn = ROW_NUMBER() OVER (ORDER BY md.ID)
    FROM dbo.MeasurementDevices AS md
    WHERE md.IsDeleted = 0
      AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c WHERE c.MeasurementDevicesId = md.ID)
      AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS h WHERE h.MeasurementDevicesId = md.ID)
)
SELECT @A = MAX(CASE WHEN Rn = 1 THEN ID END), @B = MAX(CASE WHEN Rn = 2 THEN ID END),
       @Z = MAX(CASE WHEN Rn = 3 THEN ID END)
FROM Bare WHERE Rn <= 3;

DECLARE @RhId INT = (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'%RH' ORDER BY ID);

DECLARE @Got TABLE (Test NVARCHAR(30), TempUsed DECIMAL(18,6), Deviation DECIMAL(18,6), CorrectedExact DECIMAL(18,6), Corrected DECIMAL(18,6),
                    OutOfRange BIT, Extrapolated BIT, Source NVARCHAR(20), Method NVARCHAR(20), Rows_ INT);

BEGIN TRAN;

INSERT dbo.MeasurementDevicesHumidityCorrections (MeasurementDevicesId, CorVersion, Temperature, ReferenceHumidity, ReadingHumidity, Deviation)
VALUES (@A, 1, 23, 10, 10.4, 0.4), (@A, 1, 23, 50, 50.0, 0.0), (@A, 1, 23, 90, 89.2, -0.8),
       (@B, 1, 15, 20, 20.5, 0.5), (@B, 1, 35, 20, 21.0, 1.0), (@B, 1, 25, 80, 79.0, -1.0);

INSERT @Got SELECT N'A 23/30', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@A, 23, 30);
INSERT @Got SELECT N'A 30/30', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@A, 30, 30);
INSERT @Got SELECT N'A -/30',  TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@A, NULL, 30);
INSERT @Got SELECT N'A 23/95', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@A, 23, 95);
INSERT @Got SELECT N'B 25/40', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@B, 25, 40);
INSERT @Got SELECT N'B 40/20', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@B, 40, 20);
INSERT @Got SELECT N'B -/40',  TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@B, NULL, 40);

INSERT dbo.MeasurementDevicesHumidityCorrections (MeasurementDevicesId, CorVersion, Temperature, ReferenceHumidity, ReadingHumidity, Deviation)
VALUES (@A, 2, 23, 50, 50.3, 0.3);
INSERT @Got SELECT N'C 23/30', TemperatureUsed, Deviation, CorrectedExact, Corrected, OutOfRange, Extrapolated, Source, Method, 1 FROM dbo.fnHumidityAfterCorrection(@A, 23, 30);

INSERT @Got SELECT N'D', NULL, NULL, NULL, NULL, NULL, NULL, N'-', N'-', (SELECT COUNT(*) FROM dbo.fnHumidityAfterCorrection(@Z, 23, 30));

ROLLBACK;

DECLARE @T NVARCHAR(30);
/* A */
INSERT @Out SELECT N'A line: 23 °C / 30 %RH deviation', N'0.200000', CAST(Deviation AS NVARCHAR(60)),
       IIF(Deviation = 0.2 AND CorrectedExact = 29.8 AND Method = N'line' AND Extrapolated = 0 AND OutOfRange = 0, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A 23/30';
INSERT @Out SELECT N'A line: another temperature changes nothing', N'0.200000 OutOfRange 0', CONCAT(Deviation, N' OutOfRange ', CAST(OutOfRange AS INT)),
       IIF(Deviation = 0.2 AND OutOfRange = 0, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A 30/30';
INSERT @Out SELECT N'A line: no temperature needed at one temperature', N'0.200000 line', CONCAT(Deviation, N' ', Method),
       IIF(Deviation = 0.2 AND Method = N'line', N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A -/30';
INSERT @Out SELECT N'A no temperature passed: TemperatureUsed stays NULL', N'NULL', ISNULL(CAST(TempUsed AS NVARCHAR(60)), N'NULL'),
       IIF(TempUsed IS NULL, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A -/30';
INSERT @Out SELECT N'A temperature passed: TemperatureUsed is it', N'30.000000', CAST(TempUsed AS NVARCHAR(60)),
       IIF(TempUsed = 30, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A 30/30';
INSERT @Out SELECT N'A line: past the top, last segment continued', N'-0.900000 95.900000 1/1', CONCAT(Deviation, N' ', CorrectedExact, N' ', CAST(Extrapolated AS INT), N'/', CAST(OutOfRange AS INT)),
       IIF(Deviation = -0.9 AND CorrectedExact = 95.9 AND Extrapolated = 1 AND OutOfRange = 1, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'A 23/95';
/* B */
INSERT @Out SELECT N'B triangle: inside, plane of the three points', N'0.166667 39.833333', CONCAT(Deviation, N' ', CorrectedExact),
       IIF(ABS(Deviation - 0.166667) <= 0.000001 AND ABS(CorrectedExact - 39.833333) <= 0.000001
           AND Method = N'triangle' AND Extrapolated = 0 AND OutOfRange = 0, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'B 25/40';
INSERT @Out SELECT N'B shown to 3 decimals for a whole-number reading', N'39.833000', CAST(Corrected AS NVARCHAR(60)),
       IIF(Corrected = 39.833, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'B 25/40';
INSERT @Out SELECT N'B triangle: outside, plane continued', N'1.125000 18.875000 1/1', CONCAT(Deviation, N' ', CorrectedExact, N' ', CAST(Extrapolated AS INT), N'/', CAST(OutOfRange AS INT)),
       IIF(ABS(Deviation - 1.125) <= 0.000001 AND ABS(CorrectedExact - 18.875) <= 0.000001
           AND Extrapolated = 1 AND OutOfRange = 1, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'B 40/20';
INSERT @Out SELECT N'B no temperature: needs-temperature, no value', N'needs-temperature NULL', CONCAT(Method, N' ', ISNULL(CAST(Deviation AS NVARCHAR(30)), N'NULL')),
       IIF(Method = N'needs-temperature' AND Deviation IS NULL AND Corrected IS NULL, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'B -/40';
/* C, D */
INSERT @Out SELECT N'C newest version only: one point', N'0.300000 single 1', CONCAT(Deviation, N' ', Method, N' ', CAST(Extrapolated AS INT)),
       IIF(Deviation = 0.3 AND Method = N'single' AND Extrapolated = 1, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'C 23/30';
INSERT @Out SELECT N'D no certificate: no row', N'0', CAST(Rows_ AS NVARCHAR(60)), IIF(Rows_ = 0, N'PASS', N'FAIL')
FROM @Got WHERE Test = N'D';

/* E: a one-axis %RH curve over humidity, newest version, no points */
DECLARE @E INT;
WITH Newest AS
(
    SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value1,
           Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    JOIN dbo.MeasurementDevices AS md ON md.ID = c.MeasurementDevicesId AND md.IsDeleted = 0
    WHERE ISNULL(c.IsDeleted, 0) = 0 AND c.Equation IS NOT NULL
)
SELECT TOP (1) @E = MeasurementDevicesId
FROM Newest
WHERE Rnk = 1 AND MeasurementId = @RhId
  AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS h WHERE h.MeasurementDevicesId = Newest.MeasurementDevicesId)
GROUP BY MeasurementDevicesId HAVING MIN(Value1) >= 0
ORDER BY MeasurementDevicesId;

IF @E IS NULL
    INSERT @Out VALUES (N'E curve over humidity', N'-', N'-', N'SKIP');
ELSE
    INSERT @Out
    SELECT N'E curve over humidity: deviation at the humidity', CONCAT(f.Deviation, N' ', 50 - f.Deviation),
           CONCAT(h.Deviation, N' ', h.CorrectedExact, N' ', h.Source),
           IIF(h.Deviation = f.Deviation AND h.CorrectedExact = 50 - f.Deviation AND h.Source = N'curve-humidity', N'PASS', N'FAIL')
    FROM dbo.fnMasterValueAfterCorrection(@E, 50, @RhId) AS f
    OUTER APPLY dbo.fnHumidityAfterCorrection(@E, 23, 50) AS h;

/* F: 30-1187-2, the curve laid over temperature */
DECLARE @F INT = (SELECT CASE WHEN COUNT(*) = 1 THEN MIN(ID) END FROM dbo.MeasurementDevices
                  WHERE LTRIM(RTRIM(MabaID)) = N'30-1187-2' AND IsDeleted = 0);
IF @F IS NULL OR EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @F)
    INSERT @Out VALUES (N'F curve over temperature (30-1187-2)', N'-', N'-', N'SKIP');
ELSE
BEGIN
    INSERT @Out
    SELECT N'F curve over temperature: deviation at the temperature', CONCAT(f.Deviation, N' ', 50 - f.Deviation),
           CONCAT(h.Deviation, N' ', h.CorrectedExact, N' ', h.Source),
           IIF(h.Deviation = f.Deviation AND h.CorrectedExact = 50 - f.Deviation AND h.Source = N'curve-temperature', N'PASS', N'FAIL')
    FROM dbo.fnMasterValueAfterCorrection(@F, 0, @RhId) AS f
    OUTER APPLY dbo.fnHumidityAfterCorrection(@F, 0, 50) AS h;

    INSERT @Out
    SELECT N'F curve over temperature, no temperature', N'needs-temperature', ISNULL(h.Method, N'(no row)'),
           IIF(h.Method = N'needs-temperature' AND h.Deviation IS NULL, N'PASS', N'FAIL')
    FROM (SELECT 1 AS One) AS x
    OUTER APPLY dbo.fnHumidityAfterCorrection(@F, NULL, 50) AS h;
END;

IF @A IS NULL OR @B IS NULL OR @Z IS NULL
    INSERT @Out VALUES (N'fixture: three devices with no certificate', N'3', N'fewer', N'FAIL');

SELECT Seq, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
