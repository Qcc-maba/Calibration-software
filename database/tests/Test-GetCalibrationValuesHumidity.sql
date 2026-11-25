/*
    MBA-950: an RH row is compensated at its pair's compensated temperature.   Writes and rolls back.

    dbo.GetCalibrationValuesForOrderDetailItem compensates an RH row with
    dbo.fnHumidityAfterCorrection, whose temperature input is the other row of the pair (same
    PairId) compensated against THAT row's master. dbo.GetMasterValuesAfterCorrection must give the
    sensors table the same numbers before anything is saved.

    Fixture, all inside a rolled-back transaction, on a humidity device with no rows of its own:
      humidity master  a live device with no certificate, given one triangle of points
                         (15, 20) +0.5   (35, 20) +1.0   (25, 80) -1.0
                       plane: dev = a + 0.025*T + c*H, c = -1.75/60, a = 0.125 - 20c
      temperature master 31-77 (temperature certificate only)
      P91 RH 40.0 on the humidity master, paired with P92
      P92 °C 25.0 on 31-77
      P93 RH 40.0 on the humidity master, no pair        -> needs-temperature, a dash
      P94 RH 40.0 on 31-77, paired with P95               -> 31-77 has no humidity correction
      P95 °C 25.0 on 31-77
      P96 RH 40.0 on the humidity master, paired with P97, which is RH too - never a temperature input
      P97 RH 40.0 on the humidity master

    Expected:
      1  P92 compensated by 31-77's °C curve (curve), HasCorrection 1
      2  P91 at T = P92's compensated value: 40 - (a + 0.025*T + c*40), Source points,
         HumidityTemperatureInput = that T
      3  P93 no value, Method needs-temperature, HasCorrection 1
      4  P94 no value, HasCorrection 0 - the only case an uncompensated RH row should pass
      5  the live procedure returns the same compensated values for the same rows
      7  the humidity master, whose only certificate is points, counts as having a certificate
      8  an RH row paired with another RH row: needs-temperature, before and after the save
      9  the live procedure gives the same answers when every Key is missing or the same

    Run (local copy of STAGE, or STAGE):
        Invoke-CalibratorStageLocalSqlFile.ps1 -Path database\tests\Test-GetCalibrationValuesHumidity.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

DECLARE @ItemId INT, @DetailId INT;
SELECT TOP 1 @ItemId = i.OrderDetailsItemId, @DetailId = i.OrderDetailId
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
WHERE od.SecondaryCategoryId = 5
  AND ISNULL(i.IsDeleted, 0) = 0
  AND NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToOrderDetailsItems AS p
                  WHERE p.OrderDetailsItemId = i.OrderDetailsItemId AND p.IsDeleted = 0)
  AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationEnvironmentalConditions AS e
                  WHERE e.OrderDetailsItemId = i.OrderDetailsItemId AND e.IsDeleted = 0)
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @TMaster INT = (SELECT TOP 1 ID FROM dbo.MeasurementDevices WHERE LTRIM(RTRIM(MabaID)) = N'31-77' AND IsDeleted = 0);
DECLARE @HMaster INT, @HMaba NVARCHAR(50);
SELECT TOP (1) @HMaster = md.ID, @HMaba = LTRIM(RTRIM(md.MabaID))
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0
  AND NULLIF(LTRIM(RTRIM(md.MabaID)), N'') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c WHERE c.MeasurementDevicesId = md.ID)
  AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS h WHERE h.MeasurementDevicesId = md.ID)
  AND (SELECT COUNT(*) FROM dbo.MeasurementDevices AS o
       WHERE LTRIM(RTRIM(o.MabaID)) = LTRIM(RTRIM(md.MabaID)) AND o.IsDeleted = 0) = 1
ORDER BY md.ID;
DECLARE @TempUnit INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'°C' AND ISNULL(IsDeleted, 0) = 0);
DECLARE @RhUnit   INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'%RH' AND ISNULL(IsDeleted, 0) = 0);

IF @ItemId IS NULL OR @TMaster IS NULL OR @HMaster IS NULL OR @TempUnit IS NULL OR @RhUnit IS NULL
BEGIN
    SELECT N'all' AS Step, N'SKIP' AS Result,
           CONCAT(N'fixture missing: item ', @ItemId, N', 31-77 ', @TMaster, N', humidity master ', @HMaster,
                  N', °C ', @TempUnit, N', %RH ', @RhUnit) AS Detail;
    RETURN;
END;

DECLARE @TempMaba NVARCHAR(50) = N'31-77';
DECLARE @Results TABLE (Step NVARCHAR(120), Result NVARCHAR(10), Detail NVARCHAR(300));

CREATE TABLE #Result (Placeholder BIT NULL);
DECLARE @Columns NVARCHAR(MAX) = (
    SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(name) + N' ' + system_type_name + N' NULL'), N', ')
           WITHIN GROUP (ORDER BY column_ordinal)
    FROM sys.dm_exec_describe_first_result_set(
            N'EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 1, @OrderDetailsItemId = 1', NULL, 0));
EXEC (N'ALTER TABLE #Result ADD ' + @Columns + N';');
ALTER TABLE #Result DROP COLUMN Placeholder;

CREATE TABLE #Live ([Key] NVARCHAR(200), MeasurementDevicesId INT, IsHumidity BIT, Deviation DECIMAL(18,6),
                    MasterValueAfterCorrection DECIMAL(18,6), MasterValueAfterCorrectionExact DECIMAL(18,6),
                    BeyondCertificateRange BIT, DeviationExtrapolated BIT, MasterHasCorrectionForQuantity BIT,
                    CompensationSource NVARCHAR(20), CompensationMethod NVARCHAR(20), HumidityTemperatureInput DECIMAL(18,6));

DECLARE @P1 UNIQUEIDENTIFIER = NEWID(), @P2 UNIQUEIDENTIFIER = NEWID(), @P3 UNIQUEIDENTIFIER = NEWID();
DECLARE @Row NVARCHAR(200) = N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,';
DECLARE @Data NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    @Row, N'"SensorMeasurementDeviceId":', @HMaster, N',"MasterValue":40.0,"ChannelNumber":91,"MeasuredValueUnitId":', @RhUnit,   N',"PairId":"', @P1, N'"},',
    @Row, N'"SensorMeasurementDeviceId":', @TMaster, N',"MasterValue":25.0,"ChannelNumber":92,"MeasuredValueUnitId":', @TempUnit, N',"PairId":"', @P1, N'"},',
    @Row, N'"SensorMeasurementDeviceId":', @HMaster, N',"MasterValue":40.0,"ChannelNumber":93,"MeasuredValueUnitId":', @RhUnit,   N'},',
    @Row, N'"SensorMeasurementDeviceId":', @TMaster, N',"MasterValue":40.0,"ChannelNumber":94,"MeasuredValueUnitId":', @RhUnit,   N',"PairId":"', @P2, N'"},',
    @Row, N'"SensorMeasurementDeviceId":', @TMaster, N',"MasterValue":25.0,"ChannelNumber":95,"MeasuredValueUnitId":', @TempUnit, N',"PairId":"', @P2, N'"},',
    @Row, N'"SensorMeasurementDeviceId":', @HMaster, N',"MasterValue":40.0,"ChannelNumber":96,"MeasuredValueUnitId":', @RhUnit,   N',"PairId":"', @P3, N'"},',
    @Row, N'"SensorMeasurementDeviceId":', @HMaster, N',"MasterValue":40.0,"ChannelNumber":97,"MeasuredValueUnitId":', @RhUnit,   N',"PairId":"', @P3, N'"}]}]');
DECLARE @LiveData NVARCHAR(MAX) = CONCAT(N'[',
    N'{"Key":"P91","MabaID":"', @HMaba,    N'","UnitId":', @RhUnit,   N',"Reading":40.0,"PairId":"', @P1, N'"},',
    N'{"Key":"P92","MabaID":"', @TempMaba, N'","UnitId":', @TempUnit, N',"Reading":25.0,"PairId":"', @P1, N'"},',
    N'{"Key":"P93","MabaID":"', @HMaba,    N'","UnitId":', @RhUnit,   N',"Reading":40.0},',
    N'{"Key":"P94","MabaID":"', @TempMaba, N'","UnitId":', @RhUnit,   N',"Reading":40.0,"PairId":"', @P2, N'"},',
    N'{"Key":"P95","MabaID":"', @TempMaba, N'","UnitId":', @TempUnit, N',"Reading":25.0,"PairId":"', @P2, N'"},',
    N'{"Key":"P96","MabaID":"', @HMaba,    N'","UnitId":', @RhUnit,   N',"Reading":40.0,"PairId":"', @P3, N'"},',
    N'{"Key":"P97","MabaID":"', @HMaba,    N'","UnitId":', @RhUnit,   N',"Reading":40.0,"PairId":"', @P3, N'"}]');
/* the same rows with every Key the same: rows must still be matched to each other correctly */
DECLARE @SameKeys NVARCHAR(MAX) = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@LiveData,
    N'"P91"', N'"x"'), N'"P92"', N'"x"'), N'"P93"', N'"x"'), N'"P94"', N'"x"'), N'"P95"', N'"x"'),
    N'"P96"', N'"x"'), N'"P97"', N'"x"');

DECLARE @Captured TABLE (Ch NVARCHAR(40), Exact DECIMAL(38,10), Src NVARCHAR(20), Method NVARCHAR(20),
                         HasCorr BIT, TempIn DECIMAL(18,6), HasCert BIT);
DECLARE @CapturedLive TABLE (Ch NVARCHAR(40), Exact DECIMAL(38,10), Src NVARCHAR(20), HasCorr BIT, Method NVARCHAR(20));
DECLARE @CapturedSame TABLE (Seq INT IDENTITY, Exact DECIMAL(38,10), Src NVARCHAR(20));

BEGIN TRAN;

INSERT dbo.MeasurementDevicesHumidityCorrections (MeasurementDevicesId, CorVersion, Temperature, ReferenceHumidity, ReadingHumidity, Deviation)
VALUES (@HMaster, 1, 15, 20, 20.5, 0.5), (@HMaster, 1, 35, 20, 21.0, 1.0), (@HMaster, 1, 25, 80, 79.0, -1.0);

EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Data;

INSERT INTO #Result
EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId;
INSERT INTO @Captured
SELECT ChannelNumber, MasterValueAfterCorrectionExact, CompensationSource, CompensationMethod,
       MasterHasCorrectionForQuantity, HumidityTemperatureInput, MasterHasCertificate
FROM #Result WHERE ChannelNumber IN (N'P91', N'P92', N'P93', N'P94', N'P95', N'P96', N'P97');

INSERT INTO #Live EXEC dbo.GetMasterValuesAfterCorrection @Data = @LiveData;
INSERT INTO @CapturedLive SELECT [Key], MasterValueAfterCorrectionExact, CompensationSource, MasterHasCorrectionForQuantity, CompensationMethod FROM #Live;
DELETE #Live;
INSERT INTO #Live EXEC dbo.GetMasterValuesAfterCorrection @Data = @SameKeys;
/* the procedure returns rows in array order, so the n-th row is the n-th entry */
INSERT INTO @CapturedSame (Exact, Src) SELECT MasterValueAfterCorrectionExact, CompensationSource FROM #Live;

ROLLBACK;

DECLARE @T DECIMAL(38,10) = (SELECT Exact FROM @Captured WHERE Ch = N'P92');
/* E0 makes it FLOAT arithmetic: -1.75 / 60.0 is DECIMAL and truncates to -0.029166 */
DECLARE @C FLOAT = -1.75E0 / 60E0;
DECLARE @Expected FLOAT = 40 - ((0.125 - 20 * @C) + 0.025 * CAST(@T AS FLOAT) + @C * 40);

INSERT INTO @Results
SELECT N'1. temperature row of the pair: compensated by its own master',
       IIF(COUNT(*) = 1 AND MAX(Exact) IS NOT NULL AND MAX(Src) = N'curve' AND MAX(CAST(HasCorr AS INT)) = 1, N'PASS', N'FAIL'),
       CONCAT(N'after compensation [', MAX(Exact), N'] source ', MAX(Src))
FROM @Captured WHERE Ch = N'P92';

INSERT INTO @Results
SELECT N'2. RH row: points, at the pair''s compensated temperature',
       IIF(COUNT(*) = 1 AND ABS(MAX(Exact) - @Expected) <= 0.000001 AND MAX(Src) = N'points'
           AND MAX(Method) = N'triangle' AND MAX(TempIn) = CAST(@T AS DECIMAL(18,6)), N'PASS', N'FAIL'),
       CONCAT(N'expected ', CAST(@Expected AS DECIMAL(18,6)), N' got [', MAX(Exact), N'] at T ', MAX(TempIn))
FROM @Captured WHERE Ch = N'P91';

INSERT INTO @Results
SELECT N'3. RH row with no pair: needs-temperature, a dash',
       IIF(COUNT(*) = 1 AND MAX(Exact) IS NULL AND MAX(Method) = N'needs-temperature' AND MAX(CAST(HasCorr AS INT)) = 1, N'PASS', N'FAIL'),
       CONCAT(N'after compensation [', MAX(Exact), N'] method ', MAX(Method))
FROM @Captured WHERE Ch = N'P93';

INSERT INTO @Results
SELECT N'4. RH row on a temperature-only master: HasCorrection 0',
       IIF(COUNT(*) = 1 AND MAX(Exact) IS NULL AND MAX(CAST(HasCorr AS INT)) = 0, N'PASS', N'FAIL'),
       CONCAT(N'after compensation [', MAX(Exact), N'] has correction ', MAX(CAST(HasCorr AS INT)))
FROM @Captured WHERE Ch = N'P94';

INSERT INTO @Results
SELECT N'5. live procedure = read procedure, row ' + s.Ch,
       IIF(l.Ch IS NOT NULL
           AND (s.Exact = l.Exact OR (s.Exact IS NULL AND l.Exact IS NULL))
           AND ISNULL(s.Src, N'') = ISNULL(l.Src, N'')
           AND s.HasCorr = l.HasCorr, N'PASS', N'FAIL'),
       CONCAT(N'read [', s.Exact, N' ', s.Src, N'] live [', l.Exact, N' ', l.Src, N']')
FROM @Captured AS s
LEFT JOIN @CapturedLive AS l ON l.Ch = s.Ch;

INSERT INTO @Results
SELECT N'7. humidity master with points only: MasterHasCertificate 1',
       IIF(COUNT(*) = 1 AND MAX(CAST(HasCert AS INT)) = 1, N'PASS', N'FAIL'),
       CONCAT(N'has certificate ', MAX(CAST(HasCert AS INT)))
FROM @Captured WHERE Ch = N'P91';

INSERT INTO @Results
SELECT N'8. RH row paired with an RH row: needs-temperature before and after save',
       IIF(s.Exact IS NULL AND s.Method = N'needs-temperature' AND l.Exact IS NULL AND l.Method = N'needs-temperature', N'PASS', N'FAIL'),
       CONCAT(N'read ', s.Method, N' / live ', l.Method)
FROM @Captured AS s JOIN @CapturedLive AS l ON l.Ch = s.Ch
WHERE s.Ch = N'P96';

INSERT INTO @Results
SELECT N'9. live, every Key the same: same answers in array order',
       IIF(COUNT(*) = 7 AND SUM(CASE WHEN (x.Exact = l.Exact OR (x.Exact IS NULL AND l.Exact IS NULL))
                                 AND ISNULL(x.Src, N'') = ISNULL(l.Src, N'') THEN 1 ELSE 0 END) = 7, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows')
FROM @CapturedSame AS x
JOIN @CapturedLive AS l ON l.Ch = CONCAT(N'P', 90 + x.Seq);

INSERT INTO @Results
SELECT N'6. rolled back', IIF(COUNT(*) = 0, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' rows left on item ', @ItemId)
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0;

DROP TABLE #Result;
DROP TABLE #Live;
SELECT Step, Result, Detail FROM @Results;
