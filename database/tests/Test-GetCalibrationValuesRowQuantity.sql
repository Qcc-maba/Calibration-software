/*
    MBA-802: the master compensation uses the row's own quantity.          Writes and rolls back.

    dbo.GetCalibrationValuesForOrderDetailItem picks the compensation curve from the row's
    MasterValueUnitId, and now from its MeasuredValueUnitId when the master unit is empty. Without
    that, the RH row of a sensors-table pair (measured unit %RH, no master unit) was compensated with
    the master's best-covered curve - a temperature curve on a humidity reading.

    Three rows on one humidity device, all against master 31-77 (temperature certificates only) and
    a reading of 23.0:
      RH row, measured unit only           -> no compensation (NULL): the master has no RH curve
      Temperature row, measured unit only  -> compensated
      older row, neither unit              -> compensated, as before (best-covered curve)
    Rows are written through dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 and read back through
    the procedure itself. Everything is rolled back.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-GetCalibrationValuesRowQuantity.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = N'ezequiel_lo@mba.co.il';

DECLARE @ItemId INT, @DetailId INT;
SELECT TOP 1 @ItemId = i.OrderDetailsItemId, @DetailId = i.OrderDetailId
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
WHERE od.SecondaryCategoryId = 5 AND od.OrderWorkPlanId IS NOT NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @MasterId INT = (SELECT TOP 1 ID FROM dbo.MeasurementDevices WHERE LTRIM(RTRIM(MabaID)) = N'31-77');
DECLARE @TempUnit INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'°C' AND ISNULL(IsDeleted, 0) = 0);
DECLARE @RhUnit   INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'%RH' AND ISNULL(IsDeleted, 0) = 0);

DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(200));

INSERT INTO @Results
SELECT N'0. master 31-77 is temperature-only',
       IIF(SUM(CASE WHEN m.NameEn = N'%RH' THEN 1 ELSE 0 END) = 0 AND SUM(CASE WHEN m.NameEn = N'°C' THEN 1 ELSE 0 END) > 0,
           N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' correction rows')
FROM dbo.MeasurementDevicesCorrections AS c
JOIN dbo.Measurements AS m ON m.ID = c.MeasurementId
WHERE c.MeasurementDevicesId = @MasterId AND ISNULL(c.IsDeleted, 0) = 0;

/* The procedure's result set, as a table to capture it into (its ~45 columns, as SQL describes them). */
CREATE TABLE #Result (Placeholder BIT NULL);
DECLARE @Columns NVARCHAR(MAX) = (
    SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(name) + N' ' + system_type_name + N' NULL'), N', ')
           WITHIN GROUP (ORDER BY column_ordinal)
    FROM sys.dm_exec_describe_first_result_set(
            N'EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 1, @OrderDetailsItemId = 1', NULL, 0));
EXEC (N'ALTER TABLE #Result ADD ' + @Columns + N';');
ALTER TABLE #Result DROP COLUMN Placeholder;

BEGIN TRAN;

DECLARE @RowStart NVARCHAR(300) = CONCAT(N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,',
                                         N'"SensorMeasurementDeviceId":', @MasterId, N',"MasterValue":23.0,"NominalValue":23,');
DECLARE @Data NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    @RowStart, N'"ChannelNumber":91,"MeasuredValueUnitId":', @RhUnit, N'},',
    @RowStart, N'"ChannelNumber":92,"MeasuredValueUnitId":', @TempUnit, N'},',
    @RowStart, N'"ChannelNumber":93}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Data;

INSERT INTO #Result
EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId;

/* A temp table's rows are undone by the ROLLBACK; a table variable's are not. */
DECLARE @Captured TABLE (ChannelNumber NVARCHAR(40), Corrected DECIMAL(38, 10));
INSERT INTO @Captured
SELECT ChannelNumber, MasterValueAfterCorrectionExact FROM #Result WHERE ChannelNumber IN (N'P91', N'P92', N'P93');

ROLLBACK;

INSERT INTO @Results
SELECT N'1. RH row, measured unit only: not compensated',
       IIF(COUNT(*) = 1 AND MAX(Corrected) IS NULL, N'PASS', N'FAIL'),
       CONCAT(N'after compensation: [', MAX(Corrected), N']')
FROM @Captured WHERE ChannelNumber = N'P91';

INSERT INTO @Results
SELECT N'2. temperature row, measured unit only: compensated',
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
       CONCAT(COUNT(*), N' test rows left')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND ChannelNumber IN (91, 92, 93);

DROP TABLE #Result;
SELECT Step, Result, Detail FROM @Results;
