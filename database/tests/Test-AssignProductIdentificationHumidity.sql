/*
    MBA-802: the humidity set round-trips through page 1's save and load.        Writes and rolls back.

    Saves HumidityAccuracy / HumidityTolerance / HumidityResolution on one humidity device through
    dbo.AssignProductIdentificationData, reads them back the way the app does
    (dbo.GetOrderDetailsDevices), then checks that a save without them leaves them alone (the NULL
    convention), that the temperature set was not touched, that '' clears a value, that text that
    is not a number leaves it, and that all three can be cleared at once. Everything is rolled back.

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
DECLARE @HumAccBefore TINYINT, @HumTolBefore DECIMAL(18,6), @HumResBefore DECIMAL(18,6);
SELECT @TolBefore = Tolerance, @ResBefore = Resolution, @AccBefore = Accuracy,
       @HumAccBefore = HumidityAccuracy, @HumTolBefore = HumidityTolerance, @HumResBefore = HumidityResolution
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

/* 5. An empty string clears one value; the others stay. */
INSERT INTO @Ignore
EXEC dbo.AssignProductIdentificationData
     @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
     @HumidityTolerance = N'';

INSERT INTO @Results
SELECT N'5. '''' clears that value only',
       IIF(HumidityTolerance IS NULL AND HumidityAccuracy = 7 AND HumidityResolution = 0.1, N'PASS', N'FAIL'),
       CONCAT(HumidityAccuracy, N' / ', HumidityTolerance, N' / ', HumidityResolution)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

/* 6. Text that is not a number leaves the value, and does not fail the save. */
INSERT INTO @Ignore
EXEC dbo.AssignProductIdentificationData
     @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
     @HumidityAccuracy = N'abc', @HumidityTolerance = N'1.25';

INSERT INTO @Results
SELECT N'6. non-number leaves it, number sets it',
       IIF(HumidityAccuracy = 7 AND HumidityTolerance = 1.25, N'PASS', N'FAIL'),
       CONCAT(HumidityAccuracy, N' / ', HumidityTolerance, N' / ', HumidityResolution)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

/* 7. All three cleared, as page 1 sends them for a device that is no longer "Humidity". */
INSERT INTO @Ignore
EXEC dbo.AssignProductIdentificationData
     @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
     @HumidityAccuracy = N'', @HumidityTolerance = N'', @HumidityResolution = N'';

INSERT INTO @Results
SELECT N'7. all three cleared',
       IIF(HumidityAccuracy IS NULL AND HumidityTolerance IS NULL AND HumidityResolution IS NULL, N'PASS', N'FAIL'),
       CONCAT(N'[', HumidityAccuracy, N' / ', HumidityTolerance, N' / ', HumidityResolution, N']')
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

ROLLBACK;

/* 8. Nothing survived the rollback: the humidity set is what it was before the test. */
INSERT INTO @Results
SELECT N'8. rolled back',
       IIF(    ISNULL(HumidityAccuracy, 255) = ISNULL(@HumAccBefore, 255)
           AND ISNULL(HumidityTolerance, -1) = ISNULL(@HumTolBefore, -1)
           AND ISNULL(HumidityResolution, -1) = ISNULL(@HumResBefore, -1), N'PASS', N'FAIL'),
       CONCAT(N'item ', @ItemId)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @ItemId;

SELECT Step, Result, Detail FROM @Results;
