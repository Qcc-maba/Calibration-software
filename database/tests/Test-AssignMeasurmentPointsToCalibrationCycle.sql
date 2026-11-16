/*
    MBA-522: dbo.AssignMeasurmentPointsToCalibrationCycle keeps several placeholder points (channel
    99, or the NO_SENSOR sensor) on one sensor apart by point name, and refuses a request that names
    the same point twice.                                                  Writes and rolls back.

    Uses the live cycle with the most channel-99 points on one sensor (on STAGE: line 3019, sensor
    152, T1 + an unnamed point) and resends its own saved points, so nothing else in the cycle is
    touched:
    1. resend with changed values on both placeholder points - both updated in place (same ids);
       before MBA-522 this failed with "MERGE ... same row more than once";
    2. the same request again changes nothing;
    3. one placeholder point left out - only that one is soft-deleted;
    4. a new named placeholder point - inserted beside the others;
    5. a real channel: a point renamed keeps its row (the key there is still sensor + channel);
       5b. a case-only re-spelling is still written;
    6. two differently named points on NO_SENSOR, real channel - both saved;
    7. refusals (51000, before any write): the same unnamed placeholder twice, two points on one
       real sensor + channel;
    9. the soft delete touches only the (line, cycle) pairs in the request, not every line x date.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-AssignMeasurmentPointsToCalibrationCycle.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;

DECLARE @UserEmail NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users
                                    WHERE Email LIKE N'ezequiel[_]lo%@mba.co.il' ORDER BY ID);
DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(400));

DECLARE @NoSensorId INT = (SELECT MIN(ID) FROM dbo.MeasurementDevices WHERE MabaID = N'NO_SENSOR');

/* The cycle + sensor with the most live channel-99 points */
DECLARE @Line INT, @Cycle DATETIME2(0), @Sensor INT;
SELECT TOP (1) @Line = c.OrderDetailsItemId, @Cycle = c.CalibrationCycleStartDate,
               @Sensor = c.SensorMeasurementDeviceId
FROM dbo.MeasurmentPointsToCalibrationCycles AS c
WHERE c.IsDeleted = 0 AND c.ChannelNumber = 99 AND c.SensorMeasurementDeviceId <> COALESCE(@NoSensorId, -1)
GROUP BY c.OrderDetailsItemId, c.CalibrationCycleStartDate, c.SensorMeasurementDeviceId
HAVING COUNT(*) >= 2 AND COUNT(*) = COUNT(DISTINCT LTRIM(RTRIM(COALESCE(c.MeasurmentPointName, N''))))
   /* and nothing else in the cycle is already a duplicate under the new key (it would be refused) */
   AND NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles AS d
                   WHERE d.OrderDetailsItemId = c.OrderDetailsItemId
                     AND d.CalibrationCycleStartDate = c.CalibrationCycleStartDate AND d.IsDeleted = 0
                   GROUP BY d.SensorMeasurementDeviceId, d.ChannelNumber,
                            CASE WHEN d.ChannelNumber = 99 OR d.SensorMeasurementDeviceId = @NoSensorId
                                 THEN LTRIM(RTRIM(COALESCE(d.MeasurmentPointName, N''))) ELSE N'' END
                   HAVING COUNT(*) > 1)
ORDER BY COUNT(*) DESC, c.CalibrationCycleStartDate DESC;

/* A real (non-99) channel unused by this sensor in the cycle */
DECLARE @RealCh INT = (SELECT MIN(v.n) FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS v(n)
                       WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles AS c
                                         WHERE c.OrderDetailsItemId = @Line AND c.CalibrationCycleStartDate = @Cycle
                                           AND c.IsDeleted = 0 AND c.ChannelNumber = v.n
                                           AND c.SensorMeasurementDeviceId IN (@Sensor, @NoSensorId)));

IF @Line IS NULL OR @UserEmail IS NULL OR @NoSensorId IS NULL OR @RealCh IS NULL
BEGIN
    SELECT N'0 setup' AS Step, N'FAIL' AS Result,
           N'needs a cycle with 2+ named-apart ch-99 points and no other duplicates, a free channel 1-8, the test user and NO_SENSOR' AS Detail;
    RETURN;
END;

/* The cycle's saved points, as the app would send them */
CREATE TABLE #Pts (
    RowId INT IDENTITY PRIMARY KEY,
    MeasurmentPointName NVARCHAR(100) COLLATE DATABASE_DEFAULT, SensorMeasurementDeviceId INT, ChannelNumber INT,
    MeasurmentPointCoordX DECIMAL(10,4), MeasurmentPointCoordY DECIMAL(10,4),
    MasterValue DECIMAL(10,4), MasterValueUnitId INT, AdditionalValue DECIMAL(10,4),
    AdditionalValueUnitId INT, StabilityValue DECIMAL(10,4), UncertancyValue DECIMAL(10,4),
    MeasuredValue DECIMAL(10,4), MeasuredValueUnitId INT);

INSERT #Pts (MeasurmentPointName, SensorMeasurementDeviceId, ChannelNumber, MeasurmentPointCoordX,
             MeasurmentPointCoordY, MasterValue, MasterValueUnitId, AdditionalValue, AdditionalValueUnitId,
             StabilityValue, UncertancyValue, MeasuredValue, MeasuredValueUnitId)
SELECT c.MeasurmentPointName, c.SensorMeasurementDeviceId, c.ChannelNumber, c.MeasurmentPointCoordX,
       c.MeasurmentPointCoordY, c.MasterValue, c.MasterValueUnitId, c.AdditionalValue, c.AdditionalValueUnitId,
       c.StabilityValue, c.UncertancyValue, c.MeasuredValue, c.MeasuredValueUnitId
FROM dbo.MeasurmentPointsToCalibrationCycles AS c
WHERE c.OrderDetailsItemId = @Line AND c.CalibrationCycleStartDate = @Cycle AND c.IsDeleted = 0;

DECLARE @CycleRows INT = (SELECT COUNT(*) FROM #Pts);
DECLARE @Json NVARCHAR(MAX), @Before NVARCHAR(MAX), @After NVARCHAR(MAX), @N INT, @Err NVARCHAR(4000);

/* ids of the live channel-99 rows of the sensor, by name */
DECLARE @Ids TABLE (Name NVARCHAR(100), Id INT);
INSERT @Ids SELECT LTRIM(RTRIM(COALESCE(c.MeasurmentPointName, N''))), c.MeasurmentPointsToCalibrationCycleId
FROM dbo.MeasurmentPointsToCalibrationCycles AS c
WHERE c.OrderDetailsItemId = @Line AND c.CalibrationCycleStartDate = @Cycle AND c.IsDeleted = 0
  AND c.SensorMeasurementDeviceId = @Sensor AND c.ChannelNumber = 99;

BEGIN TRANSACTION;
BEGIN TRY
    /* 1. changed values on every placeholder point of the sensor */
    UPDATE #Pts SET MasterValue = COALESCE(MasterValue, 0) + 1 + RowId, UncertancyValue = 7
    WHERE SensorMeasurementDeviceId = @Sensor AND ChannelNumber = 99;

    SET @Json = (SELECT @Line AS OrderDetailsItemId, @Cycle AS CalibrationCycleStartDate,
                        JSON_QUERY((SELECT p.MeasurmentPointName, p.SensorMeasurementDeviceId, p.ChannelNumber,
                                           p.MeasurmentPointCoordX, p.MeasurmentPointCoordY, p.MasterValue,
                                           p.MasterValueUnitId, p.AdditionalValue, p.AdditionalValueUnitId,
                                           p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId
                                    FROM #Pts AS p FOR JSON PATH, INCLUDE_NULL_VALUES)) AS Points
                 FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;

    SELECT @N = COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles AS c
    JOIN @Ids AS i ON i.Id = c.MeasurmentPointsToCalibrationCycleId
    JOIN #Pts AS p ON p.SensorMeasurementDeviceId = @Sensor AND p.ChannelNumber = 99
                  AND LTRIM(RTRIM(COALESCE(p.MeasurmentPointName, N''))) = i.Name
    WHERE c.IsDeleted = 0 AND c.MasterValue = p.MasterValue AND c.UncertancyValue = 7;
    INSERT @Results SELECT N'1 placeholder points updated in place',
        CASE WHEN @N = (SELECT COUNT(*) FROM @Ids)
              AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0) = @CycleRows
             THEN N'PASS' ELSE N'FAIL' END,
        CONCAT(N'line ', @Line, N', sensor ', @Sensor, N': ', @N, N' of ', (SELECT COUNT(*) FROM @Ids), N' updated');

    /* 2. the same request again: no row changes */
    SET @Before = (SELECT c.MeasurmentPointsToCalibrationCycleId, c.UpdatedDate, c.IsDeleted
                   FROM dbo.MeasurmentPointsToCalibrationCycles AS c
                   WHERE c.OrderDetailsItemId = @Line AND c.CalibrationCycleStartDate = @Cycle
                   ORDER BY 1 FOR JSON PATH);
    WAITFOR DELAY '00:00:01';
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    SET @After = (SELECT c.MeasurmentPointsToCalibrationCycleId, c.UpdatedDate, c.IsDeleted
                  FROM dbo.MeasurmentPointsToCalibrationCycles AS c
                  WHERE c.OrderDetailsItemId = @Line AND c.CalibrationCycleStartDate = @Cycle
                  ORDER BY 1 FOR JSON PATH);
    INSERT @Results SELECT N'2 resend is a no-op', CASE WHEN @Before = @After THEN N'PASS' ELSE N'FAIL' END, NULL;

    /* 3. leave one placeholder point out */
    DECLARE @DropName NVARCHAR(100) = (SELECT MIN(Name) FROM @Ids);
    DELETE #Pts WHERE SensorMeasurementDeviceId = @Sensor AND ChannelNumber = 99
                  AND LTRIM(RTRIM(COALESCE(MeasurmentPointName, N''))) = @DropName;
    SET @Json = (SELECT @Line AS OrderDetailsItemId, @Cycle AS CalibrationCycleStartDate,
                        JSON_QUERY((SELECT p.MeasurmentPointName, p.SensorMeasurementDeviceId, p.ChannelNumber,
                                           p.MeasurmentPointCoordX, p.MeasurmentPointCoordY, p.MasterValue,
                                           p.MasterValueUnitId, p.AdditionalValue, p.AdditionalValueUnitId,
                                           p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId
                                    FROM #Pts AS p FOR JSON PATH, INCLUDE_NULL_VALUES)) AS Points
                 FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    INSERT @Results SELECT N'3 omitted placeholder soft-deleted, rest kept',
        CASE WHEN (SELECT IsDeleted FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE MeasurmentPointsToCalibrationCycleId = (SELECT Id FROM @Ids WHERE Name = @DropName)) = 1
              AND NOT EXISTS (SELECT 1 FROM @Ids AS i JOIN dbo.MeasurmentPointsToCalibrationCycles AS c
                              ON c.MeasurmentPointsToCalibrationCycleId = i.Id
                              WHERE i.Name <> @DropName AND c.IsDeleted = 1)
              AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0) = @CycleRows - 1
             THEN N'PASS' ELSE N'FAIL' END,
        CONCAT(N'dropped "', @DropName, N'"');

    /* 4. new named placeholder point, 5. real channel point (then renamed), 6. two names on NO_SENSOR */
    INSERT #Pts (MeasurmentPointName, SensorMeasurementDeviceId, ChannelNumber, MasterValue, MeasurmentPointCoordX, MeasurmentPointCoordY)
    VALUES (N'MBA522-T', @Sensor, 99, 30, 0, 0), (N'MBA522-A', @Sensor, @RealCh, 31, 0, 0),
           (N'MBA522-N1', @NoSensorId, @RealCh, 32, 0, 0), (N'MBA522-N2', @NoSensorId, @RealCh, 33, 0, 0);
    SET @Json = (SELECT @Line AS OrderDetailsItemId, @Cycle AS CalibrationCycleStartDate,
                        JSON_QUERY((SELECT p.MeasurmentPointName, p.SensorMeasurementDeviceId, p.ChannelNumber,
                                           p.MeasurmentPointCoordX, p.MeasurmentPointCoordY, p.MasterValue,
                                           p.MasterValueUnitId, p.AdditionalValue, p.AdditionalValueUnitId,
                                           p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId
                                    FROM #Pts AS p FOR JSON PATH, INCLUDE_NULL_VALUES)) AS Points
                 FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    INSERT @Results SELECT N'4 new placeholder inserted beside the others',
        CASE WHEN EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles
                          WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0
                            AND SensorMeasurementDeviceId = @Sensor AND ChannelNumber = 99 AND MeasurmentPointName = N'MBA522-T')
              AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0
                     AND SensorMeasurementDeviceId = @Sensor AND ChannelNumber = 99) = (SELECT COUNT(*) FROM @Ids)
             THEN N'PASS' ELSE N'FAIL' END, NULL;
    INSERT @Results SELECT N'6 two names on NO_SENSOR both saved',
        CASE WHEN (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0
                     AND SensorMeasurementDeviceId = @NoSensorId AND ChannelNumber = @RealCh) = 2
             THEN N'PASS' ELSE N'FAIL' END, CONCAT(N'NO_SENSOR id ', @NoSensorId, N', channel ', @RealCh);

    DECLARE @RealId INT = (SELECT MeasurmentPointsToCalibrationCycleId FROM dbo.MeasurmentPointsToCalibrationCycles
                           WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0
                             AND SensorMeasurementDeviceId = @Sensor AND ChannelNumber = @RealCh);
    UPDATE #Pts SET MeasurmentPointName = N'MBA522-B' WHERE MeasurmentPointName = N'MBA522-A';
    SET @Json = (SELECT @Line AS OrderDetailsItemId, @Cycle AS CalibrationCycleStartDate,
                        JSON_QUERY((SELECT p.MeasurmentPointName, p.SensorMeasurementDeviceId, p.ChannelNumber,
                                           p.MeasurmentPointCoordX, p.MeasurmentPointCoordY, p.MasterValue,
                                           p.MasterValueUnitId, p.AdditionalValue, p.AdditionalValueUnitId,
                                           p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId
                                    FROM #Pts AS p FOR JSON PATH, INCLUDE_NULL_VALUES)) AS Points
                 FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    INSERT @Results SELECT N'5 real channel rename keeps its row',
        CASE WHEN (SELECT MeasurmentPointName FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE MeasurmentPointsToCalibrationCycleId = @RealId AND IsDeleted = 0) = N'MBA522-B'
              AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0
                     AND SensorMeasurementDeviceId = @Sensor AND ChannelNumber = @RealCh) = 1
             THEN N'PASS' ELSE N'FAIL' END, CONCAT(N'row ', @RealId);

    /* 5b. a case-only re-spelling is still written */
    UPDATE #Pts SET MeasurmentPointName = N'mba522-b' WHERE MeasurmentPointName = N'MBA522-B';
    SET @Json = (SELECT @Line AS OrderDetailsItemId, @Cycle AS CalibrationCycleStartDate,
                        JSON_QUERY((SELECT p.MeasurmentPointName, p.SensorMeasurementDeviceId, p.ChannelNumber,
                                           p.MeasurmentPointCoordX, p.MeasurmentPointCoordY, p.MasterValue,
                                           p.MasterValueUnitId, p.AdditionalValue, p.AdditionalValueUnitId,
                                           p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId
                                    FROM #Pts AS p FOR JSON PATH, INCLUDE_NULL_VALUES)) AS Points
                 FOR JSON PATH, INCLUDE_NULL_VALUES);
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    INSERT @Results SELECT N'5b case-only rename is written',
        CASE WHEN (SELECT MeasurmentPointName COLLATE Latin1_General_100_BIN2 FROM dbo.MeasurmentPointsToCalibrationCycles
                   WHERE MeasurmentPointsToCalibrationCycleId = @RealId AND IsDeleted = 0) = N'mba522-b' COLLATE Latin1_General_100_BIN2
             THEN N'PASS' ELSE N'FAIL' END, NULL;
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'1-6 unexpected error', N'FAIL', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

/* 7. refusals. The procedure's CATCH rolls back the caller's transaction, so each runs on its own. */
DECLARE @Dup NVARCHAR(MAX) = CONCAT(N'[{"OrderDetailsItemId":', @Line, N',"CalibrationCycleStartDate":"',
    CONVERT(NVARCHAR(19), @Cycle, 126), N'","Points":[',
    N'{"MeasurmentPointName":"","SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":99,"MasterValue":1,"MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0},',
    N'{"MeasurmentPointName":" ","SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":99,"MasterValue":2,"MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0}]}]');
SET @Err = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Dup;
END TRY
BEGIN CATCH
    SET @Err = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
INSERT @Results SELECT N'7a same unnamed placeholder twice refused',
    CASE WHEN @Err LIKE N'51000: Order line %two points share%' THEN N'PASS' ELSE N'FAIL' END, COALESCE(@Err, N'no error');

SET @Dup = CONCAT(N'[{"OrderDetailsItemId":', @Line, N',"CalibrationCycleStartDate":"',
    CONVERT(NVARCHAR(19), @Cycle, 126), N'","Points":[',
    N'{"MeasurmentPointName":"X1","SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":', @RealCh, N',"MasterValue":1,"MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0},',
    N'{"MeasurmentPointName":"X2","SensorMeasurementDeviceId":', @Sensor, N',"ChannelNumber":', @RealCh, N',"MasterValue":2,"MeasurmentPointCoordX":0,"MeasurmentPointCoordY":0}]}]');
SET @Err = NULL;
BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Dup;
END TRY
BEGIN CATCH
    SET @Err = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
INSERT @Results SELECT N'7b two points on one real sensor + channel refused',
    CASE WHEN @Err LIKE N'51000: Order line %two points share%' THEN N'PASS' ELSE N'FAIL' END, COALESCE(@Err, N'no error');

/* 9. the soft delete is scoped per (line, cycle) pair. Line A resends cycle X unchanged and the
   request also carries a pair (-1, Y) with no points, where Y is another cycle of line A. A line x
   date scope would soft-delete A/Y's points; a pair scope leaves them alone. */
DECLARE @A INT, @X DATETIME2(0), @Y DATETIME2(0);
SELECT TOP (1) @A = x.OrderDetailsItemId, @X = x.CalibrationCycleStartDate, @Y = y.CalibrationCycleStartDate
FROM (SELECT DISTINCT OrderDetailsItemId, CalibrationCycleStartDate
      FROM dbo.MeasurmentPointsToCalibrationCycles WHERE IsDeleted = 0) AS x
JOIN (SELECT DISTINCT OrderDetailsItemId, CalibrationCycleStartDate
      FROM dbo.MeasurmentPointsToCalibrationCycles WHERE IsDeleted = 0) AS y
  ON y.OrderDetailsItemId = x.OrderDetailsItemId AND y.CalibrationCycleStartDate <> x.CalibrationCycleStartDate
WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles AS d
                  WHERE d.OrderDetailsItemId = x.OrderDetailsItemId
                    AND d.CalibrationCycleStartDate = x.CalibrationCycleStartDate AND d.IsDeleted = 0
                  GROUP BY d.SensorMeasurementDeviceId, d.ChannelNumber,
                           CASE WHEN d.ChannelNumber = 99 OR d.SensorMeasurementDeviceId = @NoSensorId
                                THEN LTRIM(RTRIM(COALESCE(d.MeasurmentPointName, N''))) ELSE N'' END
                  HAVING COUNT(*) > 1)
ORDER BY x.CalibrationCycleStartDate DESC;

IF @A IS NULL
    INSERT @Results VALUES (N'9 soft delete scoped per line + cycle', N'SKIP', N'no line with two live cycles');
ELSE
BEGIN
    DECLARE @YRows INT = (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
                          WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Y AND IsDeleted = 0);
    SET @Json = CONCAT(N'[{"OrderDetailsItemId":', @A, N',"CalibrationCycleStartDate":"', CONVERT(NVARCHAR(19), @X, 126),
        N'","Points":', (SELECT c.MeasurmentPointName, c.SensorMeasurementDeviceId, c.ChannelNumber,
                                c.MeasurmentPointCoordX, c.MeasurmentPointCoordY, c.MasterValue,
                                c.MasterValueUnitId, c.AdditionalValue, c.AdditionalValueUnitId,
                                c.StabilityValue, c.UncertancyValue, c.MeasuredValue, c.MeasuredValueUnitId
                         FROM dbo.MeasurmentPointsToCalibrationCycles AS c
                         WHERE c.OrderDetailsItemId = @A AND c.CalibrationCycleStartDate = @X AND c.IsDeleted = 0
                         FOR JSON PATH, INCLUDE_NULL_VALUES),
        N'},{"OrderDetailsItemId":-1,"CalibrationCycleStartDate":"', CONVERT(NVARCHAR(19), @Y, 126), N'","Points":[]}]');
    SET @Err = NULL;
    BEGIN TRANSACTION;
    BEGIN TRY
        EXEC dbo.AssignMeasurmentPointsToCalibrationCycle @LoggedInUserEmail = @UserEmail, @Data = @Json;
    END TRY
    BEGIN CATCH
        SET @Err = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
    SET @N = (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
              WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Y AND IsDeleted = 0);
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    INSERT @Results SELECT N'9 soft delete scoped per line + cycle',
        CASE WHEN @Err IS NULL AND @N = @YRows THEN N'PASS' ELSE N'FAIL' END,
        CONCAT(N'line ', @A, N': cycle Y points ', @YRows, N' -> ', @N, CASE WHEN @Err IS NOT NULL THEN N'; ' + @Err END);
END;

/* nothing persisted */
INSERT @Results SELECT N'8 nothing left behind',
    CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.MeasurmentPointsToCalibrationCycles WHERE MeasurmentPointName LIKE N'MBA522-%')
          AND (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles
               WHERE OrderDetailsItemId = @Line AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0) = @CycleRows
         THEN N'PASS' ELSE N'FAIL' END, NULL;

DROP TABLE #Pts;
SELECT Step, Result, Detail FROM @Results ORDER BY Step;
