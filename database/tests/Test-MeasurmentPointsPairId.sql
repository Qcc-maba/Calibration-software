/*
    MBA-802: a Temperature/RH pair keeps its PairId through save, update and read.   Writes and rolls back.

    Saves two new rows with one PairId on a humidity device through
    dbo.AssignMeasurmentPointsToOrderDetailsItemsV2, updates them once with the PairId and once
    without it (the way an app build without pairs saves), checks that a PairId that is not a GUID
    is stored as no pair, and that dbo.GetCalibrationValuesForOrderDetailItem returns the column.
    Then checks the two refusals (each in its own rolled-back transaction): a third row on a pair,
    and a pair row without a channel. Everything is rolled back.

    Unit ids are looked up by name, so the same file runs on PROD after the deploy (lookup ids are
    not guaranteed to match between the servers).

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-MeasurmentPointsPairId.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = N'ezequiel_lo@mba.co.il';

/* Any humidity device (secondary category 5) on a work plan. */
DECLARE @ItemId INT, @DetailId INT;
SELECT TOP 1 @ItemId = i.OrderDetailsItemId, @DetailId = i.OrderDetailId
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
WHERE od.SecondaryCategoryId = 5 AND od.OrderWorkPlanId IS NOT NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @TempUnit INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'°C' AND ISNULL(IsDeleted, 0) = 0);
DECLARE @RhUnit   INT = (SELECT TOP 1 MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                         WHERE LTRIM(RTRIM(ShortNameEn)) = N'%RH' AND ISNULL(IsDeleted, 0) = 0);

DECLARE @PairId UNIQUEIDENTIFIER = NEWID();
DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(200));

/* One row of the payload: no stored id, channel 99 (= none, as the app sends), the given unit and pair. */
DECLARE @RowStart NVARCHAR(200) = N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,';

DECLARE @Before INT = (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems
                       WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0);

BEGIN TRAN;

/* 1. Insert a Temperature row and an RH row with one PairId. */
DECLARE @Insert NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    @RowStart, N'"ChannelNumber":99,"MeasuredValueUnitId":', @TempUnit, N',"Tolerance":0.5,"NominalValue":25,"PairId":"', @PairId, N'"},',
    @RowStart, N'"ChannelNumber":99,"MeasuredValueUnitId":', @RhUnit, N',"Tolerance":2.5,"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Insert;

DECLARE @Rows TABLE (Id INT, UnitId INT);
INSERT INTO @Rows
SELECT MeasurmentPointsToOrderDetailsItemId, MeasuredValueUnitId
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND PairId = @PairId;

INSERT INTO @Results
SELECT N'1. both rows inserted with the PairId',
       IIF(COUNT(*) = 2 AND MIN(UnitId) = LEAST(@TempUnit, @RhUnit) AND MAX(UnitId) = GREATEST(@TempUnit, @RhUnit), N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows, units ', MIN(UnitId), N'/', MAX(UnitId))
FROM @Rows;

DECLARE @TempId INT = (SELECT Id FROM @Rows WHERE UnitId = @TempUnit);
DECLARE @RhId   INT = (SELECT Id FROM @Rows WHERE UnitId = @RhUnit);

/* 2. Update without PairId (an app build without pairs): the PairId stays. */
DECLARE @UpdateWithout NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    N'{"MeasurmentPointsToOrderDetailsItemId":', @TempId, N',"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,',
    N'"ChannelNumber":99,"MeasuredValueUnitId":', @TempUnit, N',"MasterValue":24.9,"Tolerance":0.5,"NominalValue":25}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @UpdateWithout;

INSERT INTO @Results
SELECT N'2. update without PairId keeps it',
       IIF(PairId = @PairId AND MasterValue = 24.9, N'PASS', N'FAIL'),
       CONCAT(N'master ', MasterValue)
FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE MeasurmentPointsToOrderDetailsItemId = @TempId;

/* 3. Update with the PairId: still the same pair. */
DECLARE @UpdateWith NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    N'{"MeasurmentPointsToOrderDetailsItemId":', @RhId, N',"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,',
    N'"ChannelNumber":99,"MeasuredValueUnitId":', @RhUnit, N',"MasterValue":50.1,"Tolerance":2.5,"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @UpdateWith;

INSERT INTO @Results
SELECT N'3. update with PairId keeps the pair',
       IIF(COUNT(*) = 2, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows share the PairId')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND PairId = @PairId;

/* 4. A PairId that is not a GUID is stored as no pair, and the save goes through. */
DECLARE @BadId NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    @RowStart, N'"ChannelNumber":99,"MeasuredValueUnitId":', @TempUnit, N',"MasterValue":12.345,"NominalValue":25,"PairId":"default-', @ItemId, N'"}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @BadId;

INSERT INTO @Results
SELECT N'4. non-GUID PairId saved as no pair',
       IIF(COUNT(*) = 1 AND MAX(CASE WHEN PairId IS NULL THEN 1 ELSE 0 END) = 1, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' row(s) saved')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND MasterValue = 12.345;

/* 5. The read procedure returns the column. */
INSERT INTO @Results
SELECT N'5. GetCalibrationValuesForOrderDetailItem returns PairId',
       IIF(COUNT(*) = 1, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' column')
FROM sys.dm_exec_describe_first_result_set(
        N'EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 1, @OrderDetailsItemId = 1', NULL, 0)
WHERE name = N'PairId';

ROLLBACK;

/* 6. A third row on a pair is refused. */
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Insert;
    DECLARE @Third NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
        @RowStart, N'"ChannelNumber":99,"MeasuredValueUnitId":', @TempUnit, N',"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
    EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Third;
    ROLLBACK;
    INSERT INTO @Results VALUES (N'6. third row on a pair refused', N'FAIL', N'the save went through');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT INTO @Results
    VALUES (N'6. third row on a pair refused', IIF(ERROR_NUMBER() = 51000, N'PASS', N'FAIL'), LEFT(ERROR_MESSAGE(), 200));
END CATCH;

/* 7. A pair row without a channel is refused, rather than half the pair being saved. */
BEGIN TRY
    BEGIN TRAN;
    DECLARE @NoChannel NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
        @RowStart, N'"ChannelNumber":99,"MeasuredValueUnitId":', @TempUnit, N',"NominalValue":25,"PairId":"', @PairId, N'"},',
        @RowStart, N'"MeasuredValueUnitId":', @RhUnit, N',"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
    EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @NoChannel;
    ROLLBACK;
    INSERT INTO @Results VALUES (N'7. pair row without channel refused', N'FAIL', N'the save went through');
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT INTO @Results
    VALUES (N'7. pair row without channel refused', IIF(ERROR_NUMBER() = 51000, N'PASS', N'FAIL'), LEFT(ERROR_MESSAGE(), 200));
END CATCH;

/* 8. Nothing survived. */
INSERT INTO @Results
SELECT N'8. rolled back',
       IIF(COUNT(*) = @Before, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows on item ', @ItemId, N' (', @Before, N' before)')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0;

SELECT Step, Result, Detail FROM @Results;
