/*
    MBA-802: a Temperature/RH pair keeps its PairId through save, update and read.   Writes and rolls back.

    Saves two new rows with one PairId on a humidity device through
    dbo.AssignMeasurmentPointsToOrderDetailsItemsV2, updates them once with the PairId and once
    without it (the way an app build without pairs saves), and checks that
    dbo.GetCalibrationValuesForOrderDetailItem returns the column. Everything is rolled back.

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

DECLARE @PairId UNIQUEIDENTIFIER = NEWID();
DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(200));

BEGIN TRAN;

DECLARE @Before INT = (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems
                       WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0);

/* 1. Insert a Temperature row and an RH row with one PairId (channel 99 = none, as the app sends). */
DECLARE @Insert NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,"ChannelNumber":99,"MeasuredValueUnitId":13,"Tolerance":0.5,"NominalValue":25,"PairId":"', @PairId, N'"},',
    N'{"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,"ChannelNumber":99,"MeasuredValueUnitId":30,"Tolerance":2.5,"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @Insert;

DECLARE @Rows TABLE (Id INT, UnitId INT);
INSERT INTO @Rows
SELECT MeasurmentPointsToOrderDetailsItemId, MeasuredValueUnitId
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND PairId = @PairId;

INSERT INTO @Results
SELECT N'1. both rows inserted with the PairId',
       IIF(COUNT(*) = 2 AND MIN(UnitId) = 13 AND MAX(UnitId) = 30, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows, units ', MIN(UnitId), N'/', MAX(UnitId))
FROM @Rows;

DECLARE @TempId INT = (SELECT Id FROM @Rows WHERE UnitId = 13);
DECLARE @RhId   INT = (SELECT Id FROM @Rows WHERE UnitId = 30);

/* 2. Update without PairId (an app build without pairs): the PairId stays. */
DECLARE @UpdateWithout NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    N'{"MeasurmentPointsToOrderDetailsItemId":', @TempId, N',"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,"ChannelNumber":99,"MeasuredValueUnitId":13,"MasterValue":24.9,"Tolerance":0.5,"NominalValue":25}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @UpdateWithout;

INSERT INTO @Results
SELECT N'2. update without PairId keeps it',
       IIF(PairId = @PairId AND MasterValue = 24.9, N'PASS', N'FAIL'),
       CONCAT(N'master ', MasterValue)
FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE MeasurmentPointsToOrderDetailsItemId = @TempId;

/* 3. Update with the PairId: still the same pair. */
DECLARE @UpdateWith NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @ItemId, N',"Points":[',
    N'{"MeasurmentPointsToOrderDetailsItemId":', @RhId, N',"MeasurmentPointName":"","MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0,"ChannelNumber":99,"MeasuredValueUnitId":30,"MasterValue":50.1,"Tolerance":2.5,"NominalValue":25,"PairId":"', @PairId, N'"}]}]');
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @UserEmail, @Data = @UpdateWith;

INSERT INTO @Results
SELECT N'3. update with PairId keeps the pair',
       IIF(COUNT(*) = 2, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows share the PairId')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0 AND PairId = @PairId;

/* 4. The read procedure returns the column. */
INSERT INTO @Results
SELECT N'4. GetCalibrationValuesForOrderDetailItem returns PairId',
       IIF(COUNT(*) = 1, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' column')
FROM sys.dm_exec_describe_first_result_set(
        N'EXEC dbo.GetCalibrationValuesForOrderDetailItem @OrderDetailId = 1, @OrderDetailsItemId = 1', NULL, 0)
WHERE name = N'PairId';

ROLLBACK;

/* 5. Nothing survived the rollback. */
INSERT INTO @Results
SELECT N'5. rolled back',
       IIF(COUNT(*) = @Before, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows on item ', @ItemId, N' (', @Before, N' before)')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @ItemId AND IsDeleted = 0;

SELECT Step, Result, Detail FROM @Results;
