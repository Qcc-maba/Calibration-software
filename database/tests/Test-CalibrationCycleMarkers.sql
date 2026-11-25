/*
    Tests for the cycle markers                                                            MBA-983
    ---------------------------------------------------------------------------------------------
    dbo.SaveCalibrationCycleMarkers, dbo.GetCalibrationCycleMarkers, dbo.MoveCalibrationCycleMarkers
    and the markers step of dbo.DeleteCalibrationCycle.

    Run against a database where dbo.CalibrationCycleMarkers and the four procedures are deployed.
    Anything other than 'PASS' in Result is a failure. Every write happens inside a transaction
    that is rolled back, so the file leaves the database as it found it. Each refusal runs in a
    transaction of its own, because the procedures run with XACT_ABORT ON and an error dooms the
    transaction it happens in.
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(90),
                    Expected NVARCHAR(200), Actual NVARCHAR(200), Result NVARCHAR(10));

DROP TABLE IF EXISTS #S;
CREATE TABLE #S (Outcome NVARCHAR(10), MarkerType NVARCHAR(20), Time1 DATETIME2(3), Time2 DATETIME2(3),
                 Time3 DATETIME2(3), PeakMode NVARCHAR(10), MinValue DECIMAL(18,6), MaxValue DECIMAL(18,6),
                 AverageValue DECIMAL(18,6), SecondaryMinValue DECIMAL(18,6), SecondaryMaxValue DECIMAL(18,6),
                 SecondaryAverageValue DECIMAL(18,6));
DROP TABLE IF EXISTS #G;
CREATE TABLE #G (CalibrationCycleMarkerId INT, OrderDetailsItemId INT, CalibrationCycleStartDate VARCHAR(23),
                 MarkerType NVARCHAR(20), Time1 VARCHAR(23), Time2 VARCHAR(23), Time3 VARCHAR(23),
                 PeakMode NVARCHAR(10), MinValue DECIMAL(18,6), MaxValue DECIMAL(18,6), AverageValue DECIMAL(18,6),
                 SecondaryMinValue DECIMAL(18,6), SecondaryMaxValue DECIMAL(18,6), SecondaryAverageValue DECIMAL(18,6));
DROP TABLE IF EXISTS #M;
CREATE TABLE #M (Moved INT);

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

/* a live cycle, and a start time on its line that no cycle uses */
DECLARE @Item INT, @Cycle DATETIME2(0);
SELECT TOP (1) @Item = c.OrderDetailsItemId, @Cycle = c.CalibrationCycleStartDate
FROM dbo.CalibrationCycles AS c
WHERE c.IsDeleted = 0
ORDER BY c.OrderDetailsItemId DESC, c.CalibrationCycleStartDate DESC;
DECLARE @NewCycle DATETIME2(0) = DATEADD(MINUTE, 7, @Cycle);
WHILE EXISTS (SELECT 1 FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @NewCycle)
    SET @NewCycle = DATEADD(MINUTE, 1, @NewCycle);

DECLARE @Full NVARCHAR(MAX) = N'[
  {"Type":"Stabilization","Time1":"2026-11-20T09:50:00.250","Time2":"2026-11-20T10:00:00.000","PeakMode":"Overshoot",
   "Min":19.8,"Max":20.4,"Average":20.1},
  {"Type":"Calibration","Time1":"2026-11-20T10:00:00.000","Time2":"2026-11-20T10:30:00.000",
   "Min":19.9,"Max":20.2,"Average":20.05,"SecondaryMin":49.5,"SecondaryMax":51,"SecondaryAverage":50.2},
  {"Type":"DoorOpening","Time1":"2026-11-20T10:05:00","Time2":"2026-11-20T10:06:00","Time3":"2026-11-20T10:09:00",
   "Min":19.1,"Max":20.3,"Average":19.9},
  {"Type":"PowerFailure","Time1":"2026-11-20T10:12:00","Time2":"2026-11-20T10:14:00","Time3":"2026-11-20T10:20:00"},
  {"Type":"General","Time1":"2026-11-20T10:25:00"}
]';
DECLARE @Err NVARCHAR(400), @N INT, @T NVARCHAR(200);


/* =============================================================================================
   Section 1 - save, read back, no change, replace, clear
   ============================================================================================= */
BEGIN TRANSACTION;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Markers = @Full;
    INSERT @Out SELECT N'1 save', N'dry run reports 5 WouldSave rows and writes nothing', N'5 / 0',
        CONCAT((SELECT COUNT(*) FROM #S WHERE Outcome = N'WouldSave'), N' / ',
               (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0)), NULL;
    DELETE #S;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Markers = @Full, @Apply = 1;
    INSERT @Out SELECT N'1 save', N'apply saves 5 rows', N'5',
        (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
         WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0), NULL;
    DELETE #S;

    INSERT #G EXEC dbo.GetCalibrationCycleMarkers @OrderDetailsItemId = @Item;
    INSERT @Out SELECT N'1 read', N'stabilization comes back with its milliseconds as text',
        N'2026-11-20T09:50:00.250 / 2026-11-20T10:00:00 / Overshoot',
        (SELECT CONCAT(Time1, N' / ', Time2, N' / ', PeakMode) FROM #G
         WHERE MarkerType = N'Stabilization' AND CalibrationCycleStartDate = CONVERT(VARCHAR(23), @Cycle, 126)), NULL;
    INSERT @Out SELECT N'1 read', N'calibration results incl. the RH value',
        N'19.900000 20.200000 20.050000 / 49.500000 51.000000 50.200000',
        (SELECT CONCAT(MinValue, N' ', MaxValue, N' ', AverageValue, N' / ',
                       SecondaryMinValue, N' ', SecondaryMaxValue, N' ', SecondaryAverageValue) FROM #G
         WHERE MarkerType = N'Calibration' AND CalibrationCycleStartDate = CONVERT(VARCHAR(23), @Cycle, 126)), NULL;
    INSERT @Out SELECT N'1 read', N'door opening keeps its three lines',
        N'2026-11-20T10:05:00 / 2026-11-20T10:06:00 / 2026-11-20T10:09:00',
        (SELECT CONCAT(Time1, N' / ', Time2, N' / ', Time3) FROM #G
         WHERE MarkerType = N'DoorOpening' AND CalibrationCycleStartDate = CONVERT(VARCHAR(23), @Cycle, 126)), NULL;
    INSERT @Out SELECT N'1 read', N'a one-line General marker, no results',
        N'2026-11-20T10:25:00 / - / -',
        (SELECT CONCAT(Time1, N' / ', ISNULL(Time2, N'-'), N' / ', ISNULL(CAST(MinValue AS NVARCHAR(30)), N'-')) FROM #G
         WHERE MarkerType = N'General' AND CalibrationCycleStartDate = CONVERT(VARCHAR(23), @Cycle, 126)), NULL;
    DELETE #G;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Markers = @Full, @Apply = 1;
    INSERT @Out SELECT N'1 save', N'the same set again is NoChange and adds no row', N'5 NoChange / 5',
        CONCAT((SELECT COUNT(*) FROM #S WHERE Outcome = N'NoChange'), N' NoChange / ',
               (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle)), NULL;
    DELETE #S;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Apply = 1,
        @Markers = N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:40:00","Min":19.9,"Max":20.2,"Average":20.06}]';
    INSERT @Out SELECT N'1 save', N'a new set replaces the old: 1 live, 5 soft-deleted', N'1 / 5',
        CONCAT((SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0), N' / ',
               (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 1)), NULL;
    DELETE #S;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Markers = N'[]', @Apply = 1;
    INSERT @Out SELECT N'1 save', N'[] clears the cycle', N'0 rows / 0',
        CONCAT((SELECT COUNT(*) FROM #S), N' rows / ',
               (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle AND IsDeleted = 0)), NULL;
    DELETE #S;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Apply = 1,
        @Markers = N'[{"Type":"Stabilization","Time1":"2026-11-20T09:50:00","Time2":"2026-11-20T10:00:00"},
                      {"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00"}]';
    INSERT @Out SELECT N'1 save', N'stabilization may end exactly at the calibration start', N'2', COUNT(*), NULL
    FROM #S WHERE Outcome = N'Saved';
    DELETE #S;

ROLLBACK TRANSACTION;


/* =============================================================================================
   Section 2 - move with the cycle, delete with the cycle
   ============================================================================================= */
BEGIN TRANSACTION;

    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @Cycle, @Markers = @Full, @Apply = 1;
    DELETE #S;

    INSERT #M EXEC dbo.MoveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @OriginalStartDate = @Cycle, @NewStartDate = @Cycle;
    INSERT @Out SELECT N'2 move', N'same time on both sides moves nothing', N'0', (SELECT Moved FROM #M), NULL;
    DELETE #M;

    /* the app's cycle update: insert the new key, move, retire the old row */
    INSERT dbo.CalibrationCycles (OrderDetailsItemId, CalibrationCycleStartDate, CalibrationCycleEndDate, CreatedUserID)
    SELECT OrderDetailsItemId, @NewCycle, CalibrationCycleEndDate, CreatedUserID
    FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle;
    INSERT #M EXEC dbo.MoveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @OriginalStartDate = @Cycle, @NewStartDate = @NewCycle;
    UPDATE dbo.CalibrationCycles SET IsDeleted = 1 WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle;
    INSERT @Out SELECT N'2 move', N'moves all 5 markers to the new start time', N'5 / 5',
        CONCAT((SELECT Moved FROM #M), N' / ',
               (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
                WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @NewCycle AND IsDeleted = 0)), NULL;
    DELETE #M;

    INSERT #G EXEC dbo.GetCalibrationCycleMarkers @OrderDetailsItemId = @Item;
    INSERT @Out SELECT N'2 move', N'the marker times did not move', N'2026-11-20T10:00:00',
        (SELECT Time1 FROM #G WHERE MarkerType = N'Calibration'
         AND CalibrationCycleStartDate = CONVERT(VARCHAR(23), @NewCycle, 126)), NULL;
    INSERT @Out SELECT N'2 move', N'the deleted cycle returns no markers', N'0',
        (SELECT COUNT(*) FROM #G WHERE CalibrationCycleStartDate = CONVERT(VARCHAR(23), @Cycle, 126)), NULL;
    DELETE #G;

    EXEC dbo.DeleteCalibrationCycle @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @NewCycle;
    INSERT @Out SELECT N'2 delete', N'deleting the cycle retires its markers', N'0',
        (SELECT COUNT(*) FROM dbo.CalibrationCycleMarkers
         WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @NewCycle AND IsDeleted = 0), NULL;

ROLLBACK TRANSACTION;


/* =============================================================================================
   Section 3 - refusals
   ============================================================================================= */
DECLARE @Cases TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Markers NVARCHAR(MAX), Expected NVARCHAR(200));
INSERT @Cases (Test, Markers, Expected) VALUES
 (N'not an array', N'{"Type":"General"}', N'Markers must be a JSON array.'),
 (N'an element that is not an object', N'[1]', N'Every marker must be a JSON object.'),
 (N'a misspelled key', N'[{"Type":"General","time1":"2026-11-20T10:00:00"}]',
  N'Unknown key in a marker: only Type, Time1-3, PeakMode, Min, Max, Average and Secondary* are read.'),
 (N'an unknown type', N'[{"Type":"Door","Time1":"2026-11-20T10:00:00"}]',
  N'Type must be Calibration, Stabilization, DoorOpening, PowerFailure or General.'),
 (N'a type in the wrong case', N'[{"Type":"general","Time1":"2026-11-20T10:00:00"}]',
  N'Type must be Calibration, Stabilization, DoorOpening, PowerFailure or General.'),
 (N'two markers of one type',
  N'[{"Type":"General","Time1":"2026-11-20T10:00:00"},{"Type":"General","Time1":"2026-11-20T11:00:00"}]',
  N'One marker of each type per cycle.'),
 (N'no Time1', N'[{"Type":"General"}]', N'Every marker needs Time1.'),
 (N'calibration with one line', N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00"}]',
  N'Wrong number of lines: Calibration and Stabilization have 2, DoorOpening and PowerFailure 3, General 1 or 2.'),
 (N'door opening with two lines',
  N'[{"Type":"DoorOpening","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:01:00"}]',
  N'Wrong number of lines: Calibration and Stabilization have 2, DoorOpening and PowerFailure 3, General 1 or 2.'),
 (N'general with three lines',
  N'[{"Type":"General","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:01:00","Time3":"2026-11-20T10:02:00"}]',
  N'Wrong number of lines: Calibration and Stabilization have 2, DoorOpening and PowerFailure 3, General 1 or 2.'),
 (N'lines out of order',
  N'[{"Type":"PowerFailure","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:05:00","Time3":"2026-11-20T10:04:00"}]',
  N'The lines of a marker must be in time order.'),
 (N'two lines at the same time',
  N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:00:00"}]',
  N'The lines of a marker must be in time order.'),
 (N'PeakMode on a calibration marker',
  N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00","PeakMode":"Overshoot"}]',
  N'PeakMode is Overshoot or Undershoot, on the Stabilization marker only.'),
 (N'an unknown PeakMode',
  N'[{"Type":"Stabilization","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00","PeakMode":"Peak"}]',
  N'PeakMode is Overshoot or Undershoot, on the Stabilization marker only.'),
 (N'results on a General marker', N'[{"Type":"General","Time1":"2026-11-20T10:00:00","Min":1}]',
  N'A General marker is a visual mark only: it has no results.'),
 (N'Min greater than Max',
  N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00","Min":21,"Max":20}]',
  N'Min must not be greater than Max.'),
 (N'stabilization ends after the calibration starts',
  N'[{"Type":"Stabilization","Time1":"2026-11-20T09:50:00","Time2":"2026-11-20T10:00:01"},
     {"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00"}]',
  N'The Stabilization marker must end at or before the Calibration marker starts.'),
 (N'a time in UTC (Z)', N'[{"Type":"General","Time1":"2026-11-20T08:00:00.000Z"}]',
  N'Times are the station''s wall-clock time: send them without a time zone (no Z or +hh:mm).'),
 (N'a time with an offset', N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00+02:00"}]',
  N'Times are the station''s wall-clock time: send them without a time zone (no Z or +hh:mm).'),
 (N'a time that is not a date', N'[{"Type":"General","Time1":"10:00"}]',
  N'A time is not a valid date and time: send yyyy-mm-ddThh:mi:ss.mmm.'),
 (N'a month 13', N'[{"Type":"General","Time1":"2026-13-01T10:00:00"}]',
  N'A time is not a valid date and time: send yyyy-mm-ddThh:mi:ss.mmm.'),
 (N'a result that is not a number',
  N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00","Min":"n/a"}]',
  N'Min, Max, Average and Secondary* must be numbers.'),
 (N'accepted: an array after a newline and a tab',
  NCHAR(13) + NCHAR(10) + NCHAR(9) + N'[{"Type":"General","Time1":"2026-11-20T10:00:00"}]', N'(no error)'),
 (N'accepted: a result in exponent notation',
  N'[{"Type":"Calibration","Time1":"2026-11-20T10:00:00","Time2":"2026-11-20T10:30:00","Min":2e1,"Max":2.1E1}]',
  N'(no error)');

DECLARE @I INT = 1, @Max INT = (SELECT MAX(Seq) FROM @Cases), @Case NVARCHAR(MAX), @Exp NVARCHAR(200);
WHILE @I <= @Max
BEGIN
    SELECT @T = Test, @Case = Markers, @Exp = Expected FROM @Cases WHERE Seq = @I;
    SET @Err = N'(no error)';
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
            @CalibrationCycleStartDate = @Cycle, @Markers = @Case, @Apply = 1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @Err = ERROR_MESSAGE();
    END CATCH;
    DELETE #S;
    INSERT @Out SELECT N'3 refuse', @T, @Exp, @Err, NULL;
    SET @I += 1;
END;

/* the cycle must be live, and the user known */
SET @Err = N'(no error)';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @CalibrationCycleStartDate = @NewCycle, @Markers = N'[]', @Apply = 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SET @Err = ERROR_MESSAGE();
END CATCH;
DELETE #S;
INSERT @Out SELECT N'3 refuse', N'a cycle that does not exist',
    N'No live calibration cycle starts at that time on this line.', @Err, NULL;

SET @Err = N'(no error)';
BEGIN TRY
    INSERT #S EXEC dbo.SaveCalibrationCycleMarkers @LoggedInUserEmail = N'nobody@example.invalid',
        @OrderDetailsItemId = @Item, @CalibrationCycleStartDate = @Cycle, @Markers = N'[]';
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
END CATCH;
DELETE #S;
INSERT @Out SELECT N'3 refuse', N'an unknown user', N'Unknown user.', @Err, NULL;

SET @Err = N'(no error)';
BEGIN TRY
    INSERT #M EXEC dbo.MoveCalibrationCycleMarkers @LoggedInUserEmail = @Email, @OrderDetailsItemId = @Item,
        @OriginalStartDate = NULL, @NewStartDate = @Cycle;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
END CATCH;
INSERT @Out SELECT N'3 refuse', N'move without the original time',
    N'Both the original and the new start time are needed.', @Err, NULL;


UPDATE @Out SET Result = CASE WHEN Expected = Actual THEN N'PASS' ELSE N'FAIL' END;
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
SELECT Passed = SUM(CASE WHEN Result = N'PASS' THEN 1 ELSE 0 END), Failed = SUM(CASE WHEN Result = N'FAIL' THEN 1 ELSE 0 END)
FROM @Out;
