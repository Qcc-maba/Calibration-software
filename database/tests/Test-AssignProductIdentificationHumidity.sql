/*
    MBA-802: the humidity set round-trips through page 1's save and load.        Writes and rolls back.

    Saves HumidityAccuracy / HumidityTolerance / HumidityResolution on one humidity device through
    dbo.AssignProductIdentificationData, reads them back the way the app does
    (dbo.GetOrderDetailsDevices), then checks that a save without them leaves them alone (the NULL
    convention) and that the temperature set was not touched. Everything is rolled back.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-AssignProductIdentificationHumidity.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(50) = N'ezequiel_lo@mba.co.il';

/* Any humidity device (secondary category 5) on a work plan. */
DECLARE @ItemId INT, @DetailId INT, @PlanId INT;
SELECT TOP 1 @ItemId = i.OrderDetailsItemId, @DetailId = i.OrderDetailId, @PlanId = od.OrderWorkPlanId
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
WHERE od.SecondaryCategoryId = 5 AND od.OrderWorkPlanId IS NOT NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(200));

BEGIN TRAN;

DECLARE @TolBefore DECIMAL(18,6), @ResBefore DECIMAL(18,6), @AccBefore TINYINT;
SELECT @TolBefore = Tolerance, @ResBefore = Resolution, @AccBefore = Accuracy
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

DECLARE @Ignore TABLE (OrderDetailsItemId INT);

/* 1. Save the humidity set. */
INSERT INTO @Ignore
EXEC dbo.AssignProductIdentificationData
     @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
     @HumidityAccuracy = 7, @HumidityTolerance = 2.5, @HumidityResolution = 0.1;

INSERT INTO @Results
SELECT N'1. saved to the row',
       IIF(HumidityAccuracy = 7 AND HumidityTolerance = 2.5 AND HumidityResolution = 0.1, N'PASS', N'FAIL'),
       CONCAT(HumidityAccuracy, N' / ', HumidityTolerance, N' / ', HumidityResolution)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

/* 2. A save that does not send them leaves them alone. */
INSERT INTO @Ignore
EXEC dbo.AssignProductIdentificationData
     @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
     @Tolerance = @TolBefore;

INSERT INTO @Results
SELECT N'2. NULL leaves them alone',
       IIF(HumidityAccuracy = 7 AND HumidityTolerance = 2.5 AND HumidityResolution = 0.1, N'PASS', N'FAIL'),
       CONCAT(HumidityAccuracy, N' / ', HumidityTolerance, N' / ', HumidityResolution)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

/* 3. The temperature set is untouched. */
INSERT INTO @Results
SELECT N'3. temperature set unchanged',
       IIF(    ISNULL(Tolerance, -1) = ISNULL(@TolBefore, -1)
           AND ISNULL(Resolution, -1) = ISNULL(@ResBefore, -1)
           AND ISNULL(Accuracy, 255) = ISNULL(@AccBefore, 255), N'PASS', N'FAIL'),
       CONCAT(Accuracy, N' / ', Tolerance, N' / ', Resolution)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

/* 4. GetOrderDetailsDevices returns them. Its result has ~70 columns, so check its column
      list rather than capture the whole row set. */
INSERT INTO @Results
SELECT N'4. GetOrderDetailsDevices returns the columns',
       IIF(COUNT(*) = 3, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' of 3 columns in the result set')
FROM sys.dm_exec_describe_first_result_set(
        N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0)
WHERE name IN (N'HumidityAccuracy', N'HumidityTolerance', N'HumidityResolution');

ROLLBACK;

/* 5. Nothing survived the rollback. */
INSERT INTO @Results
SELECT N'5. rolled back',
       IIF(HumidityAccuracy IS NULL AND HumidityTolerance IS NULL AND HumidityResolution IS NULL, N'PASS', N'FAIL'),
       CONCAT(N'item ', @ItemId)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

SELECT Step, Result, Detail FROM @Results;
