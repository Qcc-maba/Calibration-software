/*
    MBA-802: the master compensation uses the row's own quantity.          Writes and rolls back.

    dbo.GetCalibrationValuesForOrderDetailItem (and its Many twin) picks the compensation curve
    from the row's MasterValueUnitId, and now from its MeasuredValueUnitId when the master unit is
    empty. Without that, the RH row of a sensors-table pair (measured unit %RH, no master unit) was
    compensated with the master's best-covered curve - a temperature curve on a humidity reading.

    Three rows on one humidity device with no other rows or environmental conditions, all against
    master 31-77 (temperature certificates only) and a reading of 23.0:
      P91 RH row of a pair, measured unit only          -> no compensation (NULL)
      P92 Temperature row of the same pair, measured unit -> compensated
      P93 older row, neither unit                         -> compensated, as before (best-covered)
    Rows are written through dbo.AssignMeasurmentPointsToOrderDetailsItemsV2, as the app sends them
    (pair id, placeholder-free channels), and read back through the procedure itself. Everything
    is rolled back. A missing fixture (device, master, unit) reports SKIP instead of failing.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-GetCalibrationValuesRowQuantity.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = N'ezequiel_lo@mba.co.il';

/* A live humidity device on a work plan with no measurement rows and no environmental conditions,
   so the procedure's row-number pairing with CalibrationEnvironmentalConditions cannot interfere. */
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

DECLARE @MasterId INT = (SELECT TOP 1 ID FROM dbo.MeasurementDevices WHERE LTRIM(RTRIM(MabaID)) = N'31-77');
DECLARE @TempUnit INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'°C' AND ISNULL(IsDeleted, 0) = 0);
DECLARE @RhUnit   INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'%RH' AND ISNULL(IsDeleted, 0) = 0);

IF @ItemId IS NULL OR @MasterId IS NULL OR @TempUnit IS NULL OR @RhUnit IS NULL
BEGIN
    SELECT N'all' AS Step, N'SKIP' AS Result,
           CONCAT(N'fixture missing: item ', @ItemId, N', master 31-77 ', @MasterId,
                  N', °C ', @TempUnit, N', %RH ', @RhUnit) AS Detail;
    RETURN;
END;

DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(200));

/* 0. What fnMasterValueAfterCorrection uses: the master's newest CorVersion among rows with an
      equation. It must hold a °C curve and no %RH curve, or steps 1-3 test nothing. */
WITH Ranked AS
(
    SELECT c.MeasurementId, Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    WHERE c.MeasurementDevicesId = @MasterId AND ISNULL(c.IsDeleted, 0) = 0 AND c.Equation IS NOT NULL
)
INSERT INTO @Results
SELECT N'0. master 31-77 (newest version) is temperature-only',
       IIF(SUM(CASE WHEN LTRIM(RTRIM(m.NameEn)) = N'%RH' THEN 1 ELSE 0 END) = 0
           AND SUM(CASE WHEN LTRIM(RTRIM(m.NameEn)) = N'°C' THEN 1 ELSE 0 END) > 0, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' curve segments in the newest version')
FROM Ranked AS r
JOIN dbo.Measurements AS m ON m.ID = r.MeasurementId
WHERE r.Rnk = 1;

/* The procedure's result set, as a table to capture it into (its columns, as SQL describes them). */
CREATE TABLE #Result (Placeholder BIT NULL);
DECLARE @Columns NVARCHAR(MAX) = (
    SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(name) + N' ' + system_type_name + N' NULL'), N', ')
           WITHIN GROUP (ORDER BY column_ordinal)
    FROM sys.dm_exec_describe_first_result_set(
            N'EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 1, @OrderDetailsItemId = 1', NULL, 0));
EXEC (N'ALTER TABLE #Result ADD ' + @Columns + N';');
ALTER TABLE #Result DROP COLUMN Placeholder;

DECLARE @PairId UNIQUEIDENTIFIER = NEWID();
DECLARE @RowStart NVARCHAR(300) = CONCAT(N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,',
                                         N'"SensorMeasurementDeviceId":', @MasterId, N',"MasterValue":23.0,"NominalValue":23,');
DECLARE @Data NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    @RowStart, N'"ChannelNumber":91,"MeasuredValueUnitId":', @RhUnit, N',"PairId":"', @PairId, N'"},',
    @RowStart, N'"ChannelNumber":92,"MeasuredValueUnitId":', @TempUnit, N',"PairId":"', @PairId, N'"},',
    @RowStart, N'"ChannelNumber":93}]}]');

/* A temp table's rows are undone by the ROLLBACK; a table variable's are not. */
DECLARE @Captured TABLE (ChannelNumber NVARCHAR(40), Corrected DECIMAL(38, 10));

BEGIN TRAN;

EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Data;

INSERT INTO #Result
EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId;

INSERT INTO @Captured
SELECT ChannelNumber, MasterValueAfterCorrectionExact FROM #Result WHERE ChannelNumber IN (N'P91', N'P92', N'P93');

ROLLBACK;

INSERT INTO @Results
SELECT N'1. RH row of a pair, measured unit only: not compensated',
       IIF(COUNT(*) = 1 AND MAX(Corrected) IS NULL, N'PASS', N'FAIL'),
       CONCAT(N'after compensation: [', MAX(Corrected), N']')
FROM @Captured WHERE ChannelNumber = N'P91';

INSERT INTO @Results
SELECT N'2. temperature row of the pair, measured unit only: compensated',
       IIF(COUNT(*) = 1 AND MAX(Corrected) IS NOT NULL, N'PASS', N'FAIL'),
       CONCAT(N'after compensation: [', MAX(Corrected), N']')
FROM @Captured WHERE ChannelNumber = N'P92';

INSERT INTO @Results
SELECT N'3. row with neither unit: compensated, as before',
       IIF(COUNT(*) = 1 AND MAX(Corrected) IS NOT NULL, N'PASS', N'FAIL'),
       CONCAT(N'after compensation: [', MAX(Corrected), N']')
FROM @Captured WHERE ChannelNumber = N'P93';

INSERT INTO @Results
SELECT N'4. rolled back',
       IIF(COUNT(*) = 0, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows left on item ', @ItemId)
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0;

DROP TABLE #Result;
SELECT Step, Result, Detail FROM @Results;
