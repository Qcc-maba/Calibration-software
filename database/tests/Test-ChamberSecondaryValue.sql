/*
    MBA-800: a chamber calibrated for Temperature + RH - the device's pair, the cycle's RH set
    point and settings, and the Temperature / RH roles of its points.     Writes and rolls back.

    Uses one live line that has live cycles and changes nothing for good:
    - the new columns exist and the read procedures return them;
    - dbo.AssignProductIdentificationData saves the second unit (%RH) and its set points, NULL
      leaves them, '' clears them, and any unit other than %RH (or one that is not a number) is
      refused before anything is written;
    - dbo.SaveCalibrationCycleSecondarySettings: the dry run writes nothing, @Apply = 1 saves all
      fourteen, the same values again are NoChange, the graph screen's save (AddCalibrationCycle)
      and the temperature save leave them alone, an all-NULL call clears them, and the refusals:
      values without a unit, a unit that is not the device's, each sign rule, an unknown cycle, a
      missing parameter, and the CHECK constraints and the foreign key against a direct UPDATE;
    - dbo.AssignMeasurmentPointsToOrderDetailsItems: a Temperature + RH position is saved as two
      rows with one PairId and roles 1 / 2, the RH row takes the temperature row's name, a broken
      pair is skipped and reported, and sending the position as temperature only again removes the
      RH row and the PairId;
    - dbo.AssignMeasurmentPointsToCalibrationCycle writes PairId / ValueRole and refuses a role
      other than 1 or 2 and a PairId that is not a GUID.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-ChamberSecondaryValue.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users
                                    WHERE Email LIKE N'ezequiel[_]lo%@mba.co.il' ORDER BY ID);
DECLARE @Results TABLE (Step NVARCHAR(120), Result NVARCHAR(10), Detail NVARCHAR(400));

DECLARE @RH INT = (SELECT TOP (1) MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                   WHERE ShortNameEn = N'%RH' AND IsDeleted = 0 ORDER BY MeasurementDeviceUnitId);
DECLARE @Celsius INT = (SELECT TOP (1) MeasurementDeviceUnitId FROM dbo.MeasurementDeviceUnits
                        WHERE ShortNameEn = N'°C' AND IsDeleted = 0 ORDER BY MeasurementDeviceUnitId);

/* Line A: a live line with live cycles whose id is on one line only (cycles are keyed by the id) */
DECLARE @A INT, @Detail INT, @Start DATETIME2(0);
SELECT TOP (1) @A = cc.OrderDetailsItemId
FROM dbo.CalibrationCycles AS cc
WHERE cc.IsDeleted = 0
  AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems AS oi
       WHERE oi.OrderDetailsItemId = cc.OrderDetailsItemId AND oi.IsDeleted = 0) = 1
  AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems AS oi
       WHERE oi.OrderDetailsItemId = cc.OrderDetailsItemId) = 1
GROUP BY cc.OrderDetailsItemId
ORDER BY MAX(cc.CalibrationCycleStartDate) DESC;
SELECT @Detail = OrderDetailId FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @A;
SELECT TOP (1) @Start = CalibrationCycleStartDate FROM dbo.CalibrationCycles
WHERE OrderDetailsItemId = @A AND IsDeleted = 0 ORDER BY CalibrationCycleStartDate;

/* A sensor with at least two channels on a logger: one T/RH position */
DECLARE @Sensor INT, @Ch1 INT, @Ch2 INT;
SELECT TOP (1) @Sensor = SensorMeasurementDeviceId
FROM dbo.ChannelsToSensorRelation
WHERE IsDeleted = 0
  AND SensorMeasurementDeviceId IN (SELECT ID FROM dbo.MeasurementDevices)
GROUP BY SensorMeasurementDeviceId
HAVING COUNT(DISTINCT ChannelNumber) >= 2
ORDER BY SensorMeasurementDeviceId;
SELECT @Ch1 = MIN(ChannelNumber), @Ch2 = MAX(ChannelNumber)
FROM (SELECT TOP (2) ChannelNumber FROM dbo.ChannelsToSensorRelation
      WHERE SensorMeasurementDeviceId = @Sensor AND IsDeleted = 0
      GROUP BY ChannelNumber ORDER BY ChannelNumber) AS c;

DECLARE @LivePointsBefore INT = (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems
                                 WHERE OrderDetailsItemId = @A AND IsDeleted = 0);

INSERT @Results VALUES (N'0. test data found',
    IIF(@UserEmail IS NOT NULL AND @A IS NOT NULL AND @Detail IS NOT NULL AND @Start IS NOT NULL
        AND @RH IS NOT NULL AND @Celsius IS NOT NULL AND @Sensor IS NOT NULL AND @Ch1 <> @Ch2, N'PASS', N'FAIL'),
    CONCAT(N'line ', @A, N', cycle ', CONVERT(NVARCHAR(19), @Start, 120), N', %RH=', @RH, N', °C=', @Celsius,
           N', sensor ', @Sensor, N' ch ', @Ch1, N'/', @Ch2, N', ', @LivePointsBefore, N' live points'));

/* 1. The new columns exist (14 + 2 + 1 + 2). */
INSERT @Results
SELECT N'1. columns exist', IIF(COUNT(*) = 19, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 19')
FROM sys.columns
WHERE (object_id = OBJECT_ID('dbo.CalibrationCycles') AND name LIKE N'Secondary%')
   OR (object_id = OBJECT_ID('dbo.OrderDetailsItems') AND name IN (N'SecondaryMeasurementUnitId', N'SecondaryMeasurementValueList'))
   OR (object_id = OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems') AND name = N'ValueRole')
   OR (object_id = OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles') AND name IN (N'PairId', N'ValueRole'));

/* 2. The read procedures return them. */
INSERT @Results
SELECT N'2a. GetCalibrationCycles returns the second value', IIF(COUNT(*) = 15, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 15')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetCalibrationCycles @OrderDetailsItemId = 1', NULL, 0)
WHERE name LIKE N'Secondary%';
INSERT @Results
SELECT N'2b. GetPreviousCalibrationCycleSettings returns it', IIF(COUNT(*) = 15, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 15')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = 1', NULL, 0)
WHERE name LIKE N'Secondary%';
INSERT @Results
SELECT N'2c. GetOrderDetailsDevices returns the pair', IIF(COUNT(*) = 3, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 3')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0)
WHERE name IN (N'SecondaryMeasurementUnitId', N'SecondaryMeasurementUnit', N'SecondaryMeasurementValueList');
INSERT @Results
SELECT N'2d. GetMeasurmentPointsForOrderDetail returns the roles', IIF(COUNT(*) = 2, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 2')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetMeasurmentPointsForOrderDetail @OrderDetailsItemId = 1', NULL, 0)
WHERE name IN (N'PairId', N'ValueRole');

BEGIN TRAN;

DECLARE @Ignore TABLE (OrderDetailsItemId INT);

/* 3. Page 1 saves the pair. */
INSERT @Ignore
EXEC dbo.AssignProductIdentificationData @UserEmail = @UserEmail, @OrderDetailId = @Detail, @OrderDetailsItemId = @A,
     @SecondaryMeasurementUnitId = @RH, @SecondaryMeasurementValueList = N' 40,60 ';
INSERT @Results
SELECT N'3. page 1 saves %RH and its set points',
       IIF(SecondaryMeasurementUnitId = @RH AND SecondaryMeasurementValueList = N'40,60', N'PASS', N'FAIL'),
       CONCAT(SecondaryMeasurementUnitId, N' / [', SecondaryMeasurementValueList, N']')
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @A;

/* 4. A save that does not send them leaves them. */
INSERT @Ignore
EXEC dbo.AssignProductIdentificationData @UserEmail = @UserEmail, @OrderDetailId = @Detail, @OrderDetailsItemId = @A,
     @HumidityTolerance = N'3';
INSERT @Results
SELECT N'4. NULL leaves them',
       IIF(SecondaryMeasurementUnitId = @RH AND SecondaryMeasurementValueList = N'40,60' AND HumidityTolerance = 3, N'PASS', N'FAIL'),
       CONCAT(SecondaryMeasurementUnitId, N' / [', SecondaryMeasurementValueList, N'] / tol ', HumidityTolerance)
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @A;

/* 5-7. The cycle's RH settings: dry run, save, same again. */
DECLARE @Out TABLE (Outcome NVARCHAR(20), OrderDetailsItemId INT, CalibrationCycleStartDate DATETIME2(0),
                    SecondaryUnitId INT, SecondaryTestedValue DECIMAL(18,6), SecondaryToleranceValue DECIMAL(18,6),
                    SecondaryToleranceStart DECIMAL(18,6), SecondaryToleranceEnd DECIMAL(18,6),
                    SecondaryResolution DECIMAL(18,6), SecondaryUncertainty DECIMAL(18,6),
                    SecondaryStabilityThreshold DECIMAL(18,6), SecondaryUniformityThreshold DECIMAL(18,6),
                    SecondaryDisplayValue DECIMAL(18,6), SecondaryDisplayResolution DECIMAL(18,6),
                    SecondaryIsDisplayEnabled BIT, SecondaryIsTargetValueEnabled BIT,
                    SecondaryCalculationResolution DECIMAL(18,6));

INSERT @Out
EXEC dbo.SaveCalibrationCycleSecondarySettings @UserEmail = @UserEmail, @OrderDetailsItemId = @A,
     @CalibrationCycleStartDate = @Start, @SecondaryUnitId = @RH, @SecondaryTestedValue = 50,
     @SecondaryToleranceValue = 50, @SecondaryToleranceStart = -3, @SecondaryToleranceEnd = 3,
     @SecondaryResolution = 0.1, @SecondaryUncertainty = 1.5, @SecondaryStabilityThreshold = NULL,
     @SecondaryUniformityThreshold = 2, @SecondaryDisplayValue = 50.2, @SecondaryDisplayResolution = 0.1,
     @SecondaryIsDisplayEnabled = 1, @SecondaryIsTargetValueEnabled = 0, @SecondaryCalculationResolution = 0.01;
INSERT @Results
SELECT N'5. dry run writes nothing',
       IIF(o.Outcome = N'WouldSave' AND cc.SecondaryUnitId IS NULL AND cc.SecondaryTestedValue IS NULL, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', row unit ', cc.SecondaryUnitId)
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

INSERT @Out
EXEC dbo.SaveCalibrationCycleSecondarySettings @UserEmail = @UserEmail, @OrderDetailsItemId = @A,
     @CalibrationCycleStartDate = @Start, @SecondaryUnitId = @RH, @SecondaryTestedValue = 50,
     @SecondaryToleranceValue = 50, @SecondaryToleranceStart = -3, @SecondaryToleranceEnd = 3,
     @SecondaryResolution = 0.1, @SecondaryUncertainty = 1.5, @SecondaryStabilityThreshold = NULL,
     @SecondaryUniformityThreshold = 2, @SecondaryDisplayValue = 50.2, @SecondaryDisplayResolution = 0.1,
     @SecondaryIsDisplayEnabled = 1, @SecondaryIsTargetValueEnabled = 0, @SecondaryCalculationResolution = 0.01,
     @Apply = 1;
INSERT @Results
SELECT N'6. @Apply = 1 saves all fourteen',
       IIF(o.Outcome = N'Saved' AND cc.SecondaryUnitId = @RH AND cc.SecondaryTestedValue = 50
           AND cc.SecondaryToleranceValue = 50 AND cc.SecondaryToleranceStart = -3 AND cc.SecondaryToleranceEnd = 3
           AND cc.SecondaryResolution = 0.1 AND cc.SecondaryUncertainty = 1.5 AND cc.SecondaryStabilityThreshold IS NULL
           AND cc.SecondaryUniformityThreshold = 2 AND cc.SecondaryDisplayValue = 50.2 AND cc.SecondaryDisplayResolution = 0.1
           AND cc.SecondaryIsDisplayEnabled = 1 AND cc.SecondaryIsTargetValueEnabled = 0
           AND cc.SecondaryCalculationResolution = 0.01, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', set point ', cc.SecondaryTestedValue, N', tol ', cc.SecondaryToleranceStart, N'..', cc.SecondaryToleranceEnd)
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

INSERT @Out
EXEC dbo.SaveCalibrationCycleSecondarySettings @UserEmail = @UserEmail, @OrderDetailsItemId = @A,
     @CalibrationCycleStartDate = @Start, @SecondaryUnitId = @RH, @SecondaryTestedValue = 50,
     @SecondaryToleranceValue = 50, @SecondaryToleranceStart = -3, @SecondaryToleranceEnd = 3,
     @SecondaryResolution = 0.1, @SecondaryUncertainty = 1.5, @SecondaryStabilityThreshold = NULL,
     @SecondaryUniformityThreshold = 2, @SecondaryDisplayValue = 50.2, @SecondaryDisplayResolution = 0.1,
     @SecondaryIsDisplayEnabled = 1, @SecondaryIsTargetValueEnabled = 0, @SecondaryCalculationResolution = 0.01,
     @Apply = 1;
INSERT @Results SELECT N'7. the same values again are NoChange', IIF(Outcome = N'NoChange', N'PASS', N'FAIL'), Outcome FROM @Out;
DELETE @Out;

/* 8. The graph screen's save (AddCalibrationCycle) leaves the second value alone. */
DECLARE @End DATETIME2(0), @Name NVARCHAR(200), @Unit INT, @Tested DECIMAL(18,6), @Refs NVARCHAR(100),
        @Status INT, @NameStatus INT;
SELECT @End = CalibrationCycleEndDate, @Name = CalibrationCycleName, @Unit = UnitId, @Tested = TestedValue,
       @Refs = SpecificationReferenceIds, @Status = CalibrationCycleStatusId, @NameStatus = CalibrationCycleNameStatusId
FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start;
EXEC dbo.AddCalibrationCycle @UserEmail = @UserEmail, @OrderDetailsItemId = @A,
     @CalibrationCycleStartDate = @Start, @CalibrationCycleEndDate = @End, @CalibrationCycleName = @Name,
     @UnitId = @Unit, @TestedValue = @Tested, @SpecificationReferenceIds = @Refs,
     @CalibrationCycleStatusId = @Status, @CalibrationCycleNameStatusId = @NameStatus;
INSERT @Results
SELECT N'8. graph-screen save leaves the RH settings',
       IIF(SecondaryUnitId = @RH AND SecondaryTestedValue = 50 AND SecondaryUncertainty = 1.5, N'PASS', N'FAIL'),
       CONCAT(SecondaryUnitId, N' / ', SecondaryTestedValue, N' / ', SecondaryUncertainty)
FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start;

/* 9. All NULL removes the second set point from the cycle. */
INSERT @Out
EXEC dbo.SaveCalibrationCycleSecondarySettings @UserEmail = @UserEmail, @OrderDetailsItemId = @A,
     @CalibrationCycleStartDate = @Start, @SecondaryUnitId = NULL, @SecondaryTestedValue = NULL,
     @SecondaryToleranceValue = NULL, @SecondaryToleranceStart = NULL, @SecondaryToleranceEnd = NULL,
     @SecondaryResolution = NULL, @SecondaryUncertainty = NULL, @SecondaryStabilityThreshold = NULL,
     @SecondaryUniformityThreshold = NULL, @SecondaryDisplayValue = NULL, @SecondaryDisplayResolution = NULL,
     @SecondaryIsDisplayEnabled = NULL, @SecondaryIsTargetValueEnabled = NULL, @SecondaryCalculationResolution = NULL,
     @Apply = 1;
INSERT @Results
SELECT N'9. all NULL clears the cycle''s second value',
       IIF(o.Outcome = N'Saved' AND cc.SecondaryUnitId IS NULL AND cc.SecondaryTestedValue IS NULL
           AND cc.SecondaryUniformityThreshold IS NULL AND cc.SecondaryIsDisplayEnabled IS NULL, N'PASS', N'FAIL'),
       o.Outcome
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 10-12. Logger setup: one Temperature + RH position (two channels of one sensor), plus two
          broken RH points that must be skipped. */
DECLARE @Pair UNIQUEIDENTIFIER = NEWID();
DECLARE @Json NVARCHAR(MAX) = CONCAT(N'{"OrderDetailsItemId":"', @A, N'","Points":[',
    N'{"MeasurmentPointName":"P1","MeasurmentPointCoordX":"1","MeasurmentPointCoordY":"1","SensorMeasurementDeviceId":"', @Sensor, N'","ChannelNumber":"', @Ch1, N'","PairId":"', @Pair, N'","ValueRole":"1"},',
    N'{"MeasurmentPointName":"","MeasurmentPointCoordX":"1","MeasurmentPointCoordY":"1","SensorMeasurementDeviceId":"', @Sensor, N'","ChannelNumber":"', @Ch2, N'","PairId":"', @Pair, N'","ValueRole":"2"},',
    N'{"MeasurmentPointName":"Bad1","MeasurmentPointCoordX":"2","MeasurmentPointCoordY":"2","SensorMeasurementDeviceId":"', @Sensor, N'","ChannelNumber":"901","ValueRole":"2"},',
    N'{"MeasurmentPointName":"Bad2","MeasurmentPointCoordX":"3","MeasurmentPointCoordY":"3","SensorMeasurementDeviceId":"', @Sensor, N'","ChannelNumber":"902","ValueRole":"3"}',
    N']}');
DECLARE @Summary TABLE (summary NVARCHAR(MAX));
INSERT @Summary
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItems @LoggedInUserEmail = @UserEmail, @Data = @Json, @SummaryAsJson = 1;

INSERT @Results
SELECT N'10. the pair is two rows, one PairId, roles 1 and 2',
       IIF(COUNT(*) = 2 AND MIN(ValueRole) = 1 AND MAX(ValueRole) = 2 AND MIN(CONVERT(NVARCHAR(36), PairId)) = CONVERT(NVARCHAR(36), @Pair)
           AND MAX(CONVERT(NVARCHAR(36), PairId)) = CONVERT(NVARCHAR(36), @Pair), N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows, roles ', MIN(ValueRole), N'/', MAX(ValueRole))
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @A AND IsDeleted = 0 AND PairId = @Pair;

INSERT @Results
SELECT N'11. the RH row takes the temperature row''s name',
       IIF(MeasurmentPointName = N'P1', N'PASS', N'FAIL'), CONCAT(N'[', MeasurmentPointName, N']')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @A AND IsDeleted = 0 AND PairId = @Pair AND ValueRole = 2;

INSERT @Results
SELECT N'12. the two broken RH points are skipped and reported',
       IIF(JSON_VALUE(s.summary, '$.pointsSkipped') = N'2'
           AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems
                WHERE OrderDetailsItemId = @A AND IsDeleted = 0 AND ChannelNumber IN (901, 902)) = 0, N'PASS', N'FAIL'),
       LEFT(JSON_QUERY(s.summary, '$.skipped'), 400)
FROM @Summary AS s;
DELETE @Summary;

/* 13. The same position sent as temperature only: the RH row and the PairId go. */
SET @Json = CONCAT(N'{"OrderDetailsItemId":"', @A, N'","Points":[',
    N'{"MeasurmentPointName":"P1","MeasurmentPointCoordX":"1","MeasurmentPointCoordY":"1","SensorMeasurementDeviceId":"', @Sensor, N'","ChannelNumber":"', @Ch1, N'","ValueRole":"1"}',
    N']}');
INSERT @Summary
EXEC dbo.AssignMeasurmentPointsToOrderDetailsItems @LoggedInUserEmail = @UserEmail, @Data = @Json, @SummaryAsJson = 1;
INSERT @Results
SELECT N'13. back to temperature only leaves no pair',
       IIF(COUNT(*) = 1 AND MAX(ValueRole) = 1 AND MAX(CONVERT(NVARCHAR(36), PairId)) IS NULL AND MAX(ChannelNumber) = @Ch1, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' live rows')
FROM dbo.MeasurmentPointsToOrderDetailsItems
WHERE OrderDetailsItemId = @A AND IsDeleted = 0;
DELETE @Summary;

/* 14. A cycle's points carry the roles. */
SET @Json = CONCAT(N'[{"OrderDetailsItemId":', @A, N',"CalibrationCycleStartDate":"', CONVERT(NVARCHAR(19), @Start, 126), N'","Points":[',
    N'{"MeasurmentPointName":"P1","MeasurmentPointCoordX":1,"MeasurmentPointCoordY":1,"SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":', @Ch1, N',"PairId":"', @Pair, N'","ValueRole":1},',
    N'{"MeasurmentPointName":"P1","MeasurmentPointCoordX":1,"MeasurmentPointCoordY":1,"SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":', @Ch2, N',"PairId":"', @Pair, N'","ValueRole":2}',
    N']}]');
EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
INSERT @Results
SELECT N'14. cycle points saved with PairId and roles',
       IIF(COUNT(*) = 2 AND MIN(ValueRole) = 1 AND MAX(ValueRole) = 2, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows')
FROM dbo.MeasurmentPointsToCalibrationCycles
WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start AND IsDeleted = 0 AND PairId = @Pair;

/* 15. '' clears the pair on page 1. */
INSERT @Ignore
EXEC dbo.AssignProductIdentificationData @UserEmail = @UserEmail, @OrderDetailId = @Detail, @OrderDetailsItemId = @A,
     @SecondaryMeasurementUnitId = N'', @SecondaryMeasurementValueList = N'';
INSERT @Results
SELECT N'15. '''' clears the pair',
       IIF(SecondaryMeasurementUnitId IS NULL AND SecondaryMeasurementValueList IS NULL, N'PASS', N'FAIL'),
       CONCAT(N'[', SecondaryMeasurementUnitId, N' / ', SecondaryMeasurementValueList, N']')
FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @A;

ROLLBACK;

/* 16-31. Refusals, each in its own rolled-back transaction. @setRh gives the device its RH pair first. */
DECLARE @SetRh NVARCHAR(200) = N'UPDATE dbo.OrderDetailsItems SET SecondaryMeasurementUnitId = @rh WHERE OrderDetailsItemId = @a; ';
DECLARE @Call NVARCHAR(400) = N'EXEC dbo.SaveCalibrationCycleSecondarySettings @UserEmail = @u, @OrderDetailsItemId = @a, @CalibrationCycleStartDate = @s, @SecondaryUnitId = @rh, @SecondaryTestedValue = 50, ';
DECLARE @Tail NVARCHAR(400) = N', @SecondaryDisplayValue = 1, @SecondaryDisplayResolution = 1, @SecondaryIsDisplayEnabled = 1, @SecondaryIsTargetValueEnabled = 1, @SecondaryCalculationResolution = 1, @Apply = 1';
DECLARE @Ok NVARCHAR(400) = N'@SecondaryToleranceValue = 50, @SecondaryToleranceStart = -1, @SecondaryToleranceEnd = 1, @SecondaryResolution = 1, @SecondaryUncertainty = 1, @SecondaryStabilityThreshold = 1, @SecondaryUniformityThreshold = 1';
DECLARE @Cases TABLE (N INT, Step NVARCHAR(120), Sql NVARCHAR(MAX), ExpectedError INT);
INSERT @Cases VALUES
 (16, N'16. page 1: a second unit other than %RH refused',
      N'EXEC dbo.AssignProductIdentificationData @UserEmail = @u, @OrderDetailId = @d, @OrderDetailsItemId = @a, @SecondaryMeasurementUnitId = @c', 51000),
 (17, N'17. page 1: a unit that is not a number refused',
      N'EXEC dbo.AssignProductIdentificationData @UserEmail = @u, @OrderDetailId = @d, @OrderDetailsItemId = @a, @SecondaryMeasurementUnitId = N''abc''', 51000),
 (18, N'18. RH settings on a device without the pair refused', @Call + @Ok + @Tail, 51000),
 (19, N'19. a unit other than the device''s refused',
      @SetRh + REPLACE(@Call, N'@SecondaryUnitId = @rh', N'@SecondaryUnitId = @c') + @Ok + @Tail, 51000),
 (20, N'20. values without a unit refused',
      @SetRh + REPLACE(@Call, N'@SecondaryUnitId = @rh', N'@SecondaryUnitId = NULL') + @Ok + @Tail, 51000),
 (21, N'21. lower border > 0 refused',
      @SetRh + @Call + REPLACE(@Ok, N'@SecondaryToleranceStart = -1', N'@SecondaryToleranceStart = 0.1') + @Tail, 51000),
 (22, N'22. upper border < 0 refused',
      @SetRh + @Call + REPLACE(@Ok, N'@SecondaryToleranceEnd = 1', N'@SecondaryToleranceEnd = -0.1') + @Tail, 51000),
 (23, N'23. negative stability refused',
      @SetRh + @Call + REPLACE(@Ok, N'@SecondaryStabilityThreshold = 1', N'@SecondaryStabilityThreshold = -1') + @Tail, 51000),
 (24, N'24. negative uniformity refused',
      @SetRh + @Call + REPLACE(@Ok, N'@SecondaryUniformityThreshold = 1', N'@SecondaryUniformityThreshold = -1') + @Tail, 51000),
 (25, N'25. negative display resolution refused',
      @SetRh + @Call + @Ok + REPLACE(@Tail, N'@SecondaryDisplayResolution = 1', N'@SecondaryDisplayResolution = -1'), 51000),
 (26, N'26. unknown cycle refused',
      @SetRh + REPLACE(@Call, N'@CalibrationCycleStartDate = @s', N'@CalibrationCycleStartDate = ''1900-01-01''') + @Ok + @Tail, 51000),
 (27, N'27. a missing value is an error, not a clear',
      @SetRh + @Call + @Ok + REPLACE(@Tail, N', @SecondaryCalculationResolution = 1', N''), 201),
 (28, N'28. CHECK stops a direct UPDATE (cycle)',
      N'UPDATE dbo.CalibrationCycles SET SecondaryToleranceStart = 1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547),
 (29, N'29. FK stops an unknown second unit',
      N'UPDATE dbo.CalibrationCycles SET SecondaryUnitId = -1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547),
 (30, N'30. cycle points: role 3 refused',
      N'EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @u, @Data = @j3', 51000),
 (31, N'31. cycle points: PairId that is not a GUID refused',
      N'EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @u, @Data = @jg', 51000),
 (32, N'32. FK stops an unknown device second unit',
      N'UPDATE dbo.OrderDetailsItems SET SecondaryMeasurementUnitId = -1 WHERE OrderDetailsItemId = @a', 547),
 (33, N'33. CHECK stops role 3 on an order-line point',
      N'UPDATE TOP (1) dbo.MeasurmentPointsToOrderDetailsItems SET ValueRole = 3 WHERE IsDeleted = 0', 547);

DECLARE @J3 NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @A, N',"CalibrationCycleStartDate":"', CONVERT(NVARCHAR(19), @Start, 126),
    N'","Points":[{"MeasurmentPointName":"P1","MeasurmentPointCoordX":1,"MeasurmentPointCoordY":1,"SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":', @Ch1, N',"ValueRole":3}]}]');
DECLARE @Jg NVARCHAR(MAX) = REPLACE(@J3, N'"ValueRole":3', N'"PairId":"50%-not-a-guid","ValueRole":1');

DECLARE @n INT = 16, @sql NVARCHAR(MAX), @step NVARCHAR(120), @err INT;
WHILE @n <= 33
BEGIN
    SELECT @sql = Sql, @step = Step, @err = ExpectedError FROM @Cases WHERE N = @n;
    BEGIN TRY
        BEGIN TRAN;
        EXEC sp_executesql @sql,
             N'@u NVARCHAR(255), @a INT, @d INT, @s DATETIME2(0), @rh INT, @c INT, @j3 NVARCHAR(MAX), @jg NVARCHAR(MAX)',
             @u = @UserEmail, @a = @A, @d = @Detail, @s = @Start, @rh = @RH, @c = @Celsius, @j3 = @J3, @jg = @Jg;
        ROLLBACK;
        INSERT @Results VALUES (@step, N'FAIL', N'went through');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        /* a refusal must also say why: THROW returns an EMPTY message when its text has a lone % */
        INSERT @Results VALUES (@step, IIF(ERROR_NUMBER() = @err AND LEN(ERROR_MESSAGE()) > 0, N'PASS', N'FAIL'),
                                CONCAT(ERROR_NUMBER(), N': ', LEFT(ERROR_MESSAGE(), 300)));
    END CATCH;
    SET @n += 1;
END;

/* 34. Nothing survived. */
INSERT @Results
SELECT N'34. rolled back',
       IIF(i.SecondaryMeasurementUnitId IS NULL AND i.SecondaryMeasurementValueList IS NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND SecondaryUnitId IS NOT NULL)
           AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE OrderDetailsItemId = @A AND IsDeleted = 0) = @LivePointsBefore
           AND NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE PairId = @Pair)
           AND NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles WHERE PairId = @Pair), N'PASS', N'FAIL'),
       CONCAT(N'line ', @A)
FROM dbo.OrderDetailsItems AS i WHERE i.OrderDetailsItemId = @A;

SELECT Step, Result, Detail FROM @Results;
