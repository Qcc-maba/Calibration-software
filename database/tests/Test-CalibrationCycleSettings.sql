/*
    MBA-980: a chamber cycle's settings are saved, survive a graph-screen save, and carry over to
    the device's next calibration.                                        Writes and rolls back.

    Uses live cycles already in the database and changes nothing for good:
    - dbo.GetCalibrationCycles and dbo.GetPreviousCalibrationCycleSettings return all fifteen
      settings columns;
    - dbo.SaveCalibrationCycleSettings: the dry run writes nothing, @Apply = 1 saves all fifteen, the
      same values again are NoChange, a change of case is a change, a blank text is stored as NULL,
      NULLs clear, and dbo.AddCalibrationCycle (the graph screen's save) leaves the settings alone;
    - the refusals: each sign rule (the two new resolutions included), an unknown or deleted cycle,
      an unknown user, a controller type from another status category, a manufacturer or model over
      100 characters, a missing parameter, and the CHECK constraints and the foreign key against a
      direct UPDATE;
    - dbo.GetPreviousCalibrationCycleSettings: two earlier lines of one device (SERN set inside
      the transaction) - the one whose cycles ran last wins, deleted cycles are left out, a later
      line is never "previous", a line without SERN returns nothing, and an id on two lines is
      never used;
    - a save by a user whose e-mail is shared still goes through.

    Needs database/data/Seed-ControllerTypeStatuses.sql applied (step 0 fails otherwise).

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-CalibrationCycleSettings.sql
    Every row of the result should read PASS.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @UserEmail NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users
                                    WHERE Email LIKE N'ezequiel[_]lo%@mba.co.il' ORDER BY ID);
DECLARE @Results TABLE (Step NVARCHAR(100), Result NVARCHAR(10), Detail NVARCHAR(300));

/* The two controller types, and a status of another category */
DECLARE @Digital INT, @Analog INT, @OtherStatus INT;
SELECT @Digital = MAX(CASE WHEN s.Code = N'Digital' THEN s.StatusId END),
       @Analog  = MAX(CASE WHEN s.Code = N'Analog'  THEN s.StatusId END)
FROM dbo.Statuses AS s
JOIN dbo.StatusesCategories AS c ON c.StatusCategoryId = s.StatusCategoryId
WHERE c.StatusDescriptionENG = N'ControllerType';
SELECT @OtherStatus = MIN(s.StatusId)
FROM dbo.Statuses AS s
JOIN dbo.StatusesCategories AS c ON c.StatusCategoryId = s.StatusCategoryId
WHERE c.StatusDescriptionENG <> N'ControllerType';

/* Line A: the line with the most live cycles (at least 2, so one can be deleted). Line C: another
   line with live cycles. Line B: a live line created after both, with no cycles of its own. */
DECLARE @A INT, @C INT, @B INT;

SELECT TOP (1) @A = cc.OrderDetailsItemId
FROM dbo.CalibrationCycles AS cc
WHERE cc.IsDeleted = 0
GROUP BY cc.OrderDetailsItemId
HAVING COUNT(*) >= 2
ORDER BY COUNT(*) DESC, cc.OrderDetailsItemId DESC;

/* C ran before A - before A's second-to-last cycle, so A is still the latest after its last cycle
   is deleted in step 7 */
SELECT TOP (1) @C = cc.OrderDetailsItemId
FROM dbo.CalibrationCycles AS cc
WHERE cc.IsDeleted = 0 AND cc.OrderDetailsItemId <> @A
GROUP BY cc.OrderDetailsItemId
HAVING MAX(cc.CalibrationCycleStartDate) <
       (SELECT MIN(x.CalibrationCycleStartDate)
        FROM (SELECT TOP (2) CalibrationCycleStartDate FROM dbo.CalibrationCycles
              WHERE OrderDetailsItemId = @A AND IsDeleted = 0 ORDER BY CalibrationCycleStartDate DESC) AS x)
ORDER BY MAX(cc.CalibrationCycleStartDate) DESC;

SELECT TOP (1) @B = oi.OrderDetailsItemId
FROM dbo.OrderDetailsItems AS oi
WHERE oi.IsDeleted = 0 AND oi.IsCancelled = 0
  AND oi.CreatedDate > (SELECT MAX(CreatedDate) FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId IN (@A, @C))
  AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = oi.OrderDetailsItemId)
  AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = oi.OrderDetailsItemId) = 1
ORDER BY oi.CreatedDate DESC;

DECLARE @Start DATETIME2(0), @Start2 DATETIME2(0);
SELECT TOP (1) @Start = CalibrationCycleStartDate FROM dbo.CalibrationCycles
WHERE OrderDetailsItemId = @A AND IsDeleted = 0 ORDER BY CalibrationCycleStartDate;
SELECT TOP (1) @Start2 = CalibrationCycleStartDate FROM dbo.CalibrationCycles
WHERE OrderDetailsItemId = @A AND IsDeleted = 0 ORDER BY CalibrationCycleStartDate DESC;

DECLARE @LiveA INT = (SELECT COUNT(*) FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND IsDeleted = 0);
/* Every column the test writes, on every cycle of A and C, so step 20 can prove nothing leaked. */
DECLARE @Snapshot TABLE (OrderDetailsItemId INT, CalibrationCycleStartDate DATETIME2(0), IsDeleted BIT,
                         UpdatedDate DATETIME2(0), UpdateUserID INT,
                         ToleranceValue DECIMAL(18,6), ToleranceStart DECIMAL(18,6), ToleranceEnd DECIMAL(18,6),
                         Resolution DECIMAL(18,6), Uncertainty DECIMAL(18,6),
                         StabilityThreshold DECIMAL(18,6), UniformityThreshold DECIMAL(18,6),
                         DisplayValue DECIMAL(18,6), DisplayResolution DECIMAL(18,6),
                         IsDisplayEnabled BIT, IsTargetValueEnabled BIT, ControllerTypeStatusId INT,
                         ControllerManufacturer NVARCHAR(100), ControllerModel NVARCHAR(100),
                         CalculationResolution DECIMAL(18,6));
INSERT @Snapshot
SELECT OrderDetailsItemId, CalibrationCycleStartDate, IsDeleted, UpdatedDate, UpdateUserID,
       ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty, StabilityThreshold, UniformityThreshold,
       DisplayValue, DisplayResolution, IsDisplayEnabled, IsTargetValueEnabled, ControllerTypeStatusId,
       ControllerManufacturer, ControllerModel, CalculationResolution
FROM dbo.CalibrationCycles WHERE OrderDetailsItemId IN (@A, @C);

INSERT @Results VALUES (N'0. test data found',
    IIF(@UserEmail IS NOT NULL AND @A IS NOT NULL AND @B IS NOT NULL AND @C IS NOT NULL
        AND @Digital IS NOT NULL AND @Analog IS NOT NULL AND @OtherStatus IS NOT NULL, N'PASS', N'FAIL'),
    CONCAT(N'A=', @A, N' (', @LiveA, N' live cycles), C=', @C, N', B=', @B, N', Digital=', @Digital,
           N', Analog=', @Analog, N', user ', @UserEmail));

/* 1. The read procedures return the fifteen columns. */
DECLARE @SettingsColumns TABLE (name SYSNAME);
INSERT @SettingsColumns VALUES (N'ToleranceValue'), (N'ToleranceStart'), (N'ToleranceEnd'), (N'Resolution'),
    (N'Uncertainty'), (N'StabilityThreshold'), (N'UniformityThreshold'), (N'DisplayValue'), (N'DisplayResolution'),
    (N'IsDisplayEnabled'), (N'IsTargetValueEnabled'), (N'ControllerTypeStatusId'), (N'ControllerManufacturer'),
    (N'ControllerModel'), (N'CalculationResolution');

INSERT @Results
SELECT N'1. GetCalibrationCycles returns the settings',
       IIF(COUNT(*) = 15, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 15 columns')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetCalibrationCycles @OrderDetailsItemId = 1', NULL, 0)
WHERE name COLLATE DATABASE_DEFAULT IN (SELECT name FROM @SettingsColumns);   -- metadata is in the server collation

INSERT @Results
SELECT N'1b. GetPreviousCalibrationCycleSettings returns them',
       IIF(COUNT(*) = 15, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' of 15 columns')
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = 1', NULL, 0)
WHERE name COLLATE DATABASE_DEFAULT IN (SELECT name FROM @SettingsColumns);

DECLARE @Out TABLE (Outcome NVARCHAR(20), OrderDetailsItemId INT, CalibrationCycleStartDate DATETIME2(0),
                    ToleranceValue DECIMAL(18,6), ToleranceStart DECIMAL(18,6), ToleranceEnd DECIMAL(18,6),
                    Resolution DECIMAL(18,6), Uncertainty DECIMAL(18,6),
                    StabilityThreshold DECIMAL(18,6), UniformityThreshold DECIMAL(18,6),
                    DisplayValue DECIMAL(18,6), DisplayResolution DECIMAL(18,6),
                    IsDisplayEnabled BIT, IsTargetValueEnabled BIT, ControllerTypeStatusId INT,
                    ControllerManufacturer NVARCHAR(100), ControllerModel NVARCHAR(100),
                    CalculationResolution DECIMAL(18,6));

BEGIN TRAN;

/* The cycle is real data: start it from "not set", whatever the app has saved on it by now. */
UPDATE dbo.CalibrationCycles
SET ToleranceValue = NULL, ToleranceStart = NULL, ToleranceEnd = NULL, Resolution = NULL, Uncertainty = NULL,
    StabilityThreshold = NULL, UniformityThreshold = NULL,
    DisplayValue = NULL, DisplayResolution = NULL, IsDisplayEnabled = NULL, IsTargetValueEnabled = NULL,
    ControllerTypeStatusId = NULL, ControllerManufacturer = NULL, ControllerModel = NULL, CalculationResolution = NULL
WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start;

/* 2. Dry run: reports WouldSave and writes nothing. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.3, @StabilityThreshold = 0, @UniformityThreshold = 1.5,
    @DisplayValue = 20.4, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Analog, @ControllerManufacturer = N'Binder', @ControllerModel = N'KB 240',
    @CalculationResolution = 0.01;

INSERT @Results
SELECT N'2. dry run writes nothing',
       IIF(o.Outcome = N'WouldSave' AND cc.ToleranceValue IS NULL AND cc.DisplayValue IS NULL
           AND cc.ControllerModel IS NULL, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', stored tolerance ', COALESCE(CAST(cc.ToleranceValue AS NVARCHAR(30)), N'NULL'))
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 3. Apply: all fifteen stored as sent, and the update stamped. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.3, @StabilityThreshold = 0, @UniformityThreshold = 1.5,
    @DisplayValue = 20.4, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Analog, @ControllerManufacturer = N'Binder', @ControllerModel = N'KB 240',
    @CalculationResolution = 0.01, @Apply = 1;

INSERT @Results
SELECT N'3. apply saves all fifteen',
       IIF(o.Outcome = N'Saved' AND cc.ToleranceValue = 20.5 AND cc.ToleranceStart = -0.5 AND cc.ToleranceEnd = 0.25
           AND cc.Resolution = 0.1 AND cc.Uncertainty = 0.3 AND cc.StabilityThreshold = 0 AND cc.UniformityThreshold = 1.5
           AND cc.DisplayValue = 20.4 AND cc.DisplayResolution = 0.1 AND cc.IsDisplayEnabled = 1
           AND cc.IsTargetValueEnabled = 0 AND cc.ControllerTypeStatusId = @Analog
           AND cc.ControllerManufacturer = N'Binder' AND cc.ControllerModel = N'KB 240' AND cc.CalculationResolution = 0.01
           AND cc.UpdateUserID = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @UserEmail ORDER BY ID), N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N': ', cc.ToleranceValue, N' [', cc.ToleranceStart, N', ', cc.ToleranceEnd, N'] display ', cc.DisplayValue,
              N'/', cc.DisplayResolution, N' controller ', cc.ControllerTypeStatusId, N' ', cc.ControllerManufacturer, N' ',
              cc.ControllerModel, N' calc ', cc.CalculationResolution)
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 4. The same values again: NoChange. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.3, @StabilityThreshold = 0, @UniformityThreshold = 1.5,
    @DisplayValue = 20.4, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Analog, @ControllerManufacturer = N'Binder', @ControllerModel = N'KB 240',
    @CalculationResolution = 0.01, @Apply = 1;
INSERT @Results SELECT N'4. same values again: NoChange', IIF(Outcome = N'NoChange', N'PASS', N'FAIL'), Outcome FROM @Out;
DELETE @Out;

/* 4a. A change of case only is still a change. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.3, @StabilityThreshold = 0, @UniformityThreshold = 1.5,
    @DisplayValue = 20.4, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Analog, @ControllerManufacturer = N'Binder', @ControllerModel = N'kb 240',
    @CalculationResolution = 0.01, @Apply = 1;
INSERT @Results
SELECT N'4a. a change of case is saved',
       IIF(o.Outcome = N'Saved' AND cc.ControllerModel = N'kb 240' COLLATE Latin1_General_100_BIN2, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', model ', cc.ControllerModel)
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 4b. A blank manufacturer is stored as NULL; Digital replaces Analog. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.3, @StabilityThreshold = 0, @UniformityThreshold = 1.5,
    @DisplayValue = 20.4, @DisplayResolution = 0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Digital, @ControllerManufacturer = N'   ', @ControllerModel = N'KB 240',
    @CalculationResolution = 0.01, @Apply = 1;
INSERT @Results
SELECT N'4b. blank text stored as NULL',
       IIF(o.Outcome = N'Saved' AND cc.ControllerManufacturer IS NULL AND o.ControllerManufacturer IS NULL
           AND cc.ControllerTypeStatusId = @Digital, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', manufacturer ', COALESCE(cc.ControllerManufacturer, N'NULL'), N', controller ', cc.ControllerTypeStatusId)
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 5. The graph screen's save (AddCalibrationCycle on the same cycle) keeps the settings. */
DECLARE @End DATETIME2(0), @Name NVARCHAR(200), @Unit INT, @Tested DECIMAL(18,6), @Refs NVARCHAR(100),
        @Status INT, @NameStatus INT;
SELECT @End = CalibrationCycleEndDate, @Name = CalibrationCycleName, @Unit = UnitId, @Tested = TestedValue,
       @Refs = SpecificationReferenceIds, @Status = CalibrationCycleStatusId, @NameStatus = CalibrationCycleNameStatusId
FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start;

EXEC dbo.AddCalibrationCycle
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @CalibrationCycleEndDate = @End, @CalibrationCycleName = @Name, @UnitId = @Unit, @TestedValue = @Tested,
    @SpecificationReferenceIds = @Refs, @CalibrationCycleStatusId = @Status, @CalibrationCycleNameStatusId = @NameStatus;

INSERT @Results
SELECT N'5. AddCalibrationCycle keeps the settings',
       IIF(ToleranceValue = 20.5 AND UniformityThreshold = 1.5 AND DisplayValue = 20.4
           AND ControllerTypeStatusId = @Digital AND ControllerModel = N'KB 240', N'PASS', N'FAIL'),
       CONCAT(N'tolerance ', ToleranceValue, N', uniformity ', UniformityThreshold, N', display ', DisplayValue)
FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start;

/* 6. NULL clears a value. */
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = NULL, @StabilityThreshold = 0, @UniformityThreshold = NULL,
    @DisplayValue = 20.4, @DisplayResolution = NULL, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Digital, @ControllerManufacturer = NULL, @ControllerModel = N'KB 240',
    @CalculationResolution = NULL, @Apply = 1;

INSERT @Results
SELECT N'6. NULL clears a value',
       IIF(o.Outcome = N'Saved' AND cc.Uncertainty IS NULL AND cc.UniformityThreshold IS NULL AND cc.ToleranceValue = 20.5
           AND cc.DisplayResolution IS NULL AND cc.CalculationResolution IS NULL AND cc.DisplayValue = 20.4, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', uncertainty ', COALESCE(CAST(cc.Uncertainty AS NVARCHAR(30)), N'NULL'),
              N', display resolution ', COALESCE(CAST(cc.DisplayResolution AS NVARCHAR(30)), N'NULL'))
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

/* 7-9. The previous calibration. A and C become two earlier lines of B's device; both get saved
   settings on their first cycle. A's last cycle is deleted first, and must never be returned.
   C was chosen to have run before A, so A must win. */
DECLARE @Sern INT = -980980;   -- not a real Priority key
UPDATE dbo.OrderDetailsItems SET SERN = @Sern WHERE OrderDetailsItemId IN (@A, @B, @C);

UPDATE dbo.CalibrationCycles SET IsDeleted = 1
WHERE OrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start2;

DECLARE @CStart DATETIME2(0) = (SELECT MIN(CalibrationCycleStartDate) FROM dbo.CalibrationCycles
                                WHERE OrderDetailsItemId = @C AND IsDeleted = 0);
INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @C, @CalibrationCycleStartDate = @CStart,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = NULL, @StabilityThreshold = 0, @UniformityThreshold = NULL,
    @DisplayValue = 19.9, @DisplayResolution = 0.1, @IsDisplayEnabled = 0, @IsTargetValueEnabled = 1,
    @ControllerTypeStatusId = @Analog, @ControllerManufacturer = N'Memmert', @ControllerModel = N'IN 55',
    @CalculationResolution = 0.1, @Apply = 1;
DELETE @Out;
DECLARE @Prev TABLE (PreviousOrderDetailsItemId INT, PreviousMbaReportNumber NVARCHAR(200), CycleNumber BIGINT,
                     CalibrationCycleStartDate DATETIME2(0), CalibrationCycleName NVARCHAR(200),
                     CalibrationCycleNameStatusId INT, UnitId INT, UnitName NVARCHAR(200), TestedValue DECIMAL(18,6),
                     ToleranceValue DECIMAL(18,6), ToleranceStart DECIMAL(18,6), ToleranceEnd DECIMAL(18,6),
                     Resolution DECIMAL(18,6), Uncertainty DECIMAL(18,6),
                     StabilityThreshold DECIMAL(18,6), UniformityThreshold DECIMAL(18,6),
                     DisplayValue DECIMAL(18,6), DisplayResolution DECIMAL(18,6),
                     IsDisplayEnabled BIT, IsTargetValueEnabled BIT, ControllerTypeStatusId INT,
                     ControllerManufacturer NVARCHAR(100), ControllerModel NVARCHAR(100),
                     CalculationResolution DECIMAL(18,6));
DECLARE @Expected INT = @A;   -- C was chosen to have run before A

INSERT @Prev EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = @B;

INSERT @Results
SELECT N'7. previous = the line whose cycles ran last',
       IIF(COUNT(*) > 0 AND MIN(PreviousOrderDetailsItemId) = @Expected AND MAX(PreviousOrderDetailsItemId) = @Expected, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows from line ', MIN(PreviousOrderDetailsItemId), N' (expected ', @Expected, N')')
FROM @Prev;

INSERT @Results
SELECT N'8. settings carried, deleted cycle left out',
       IIF(COUNT(*) = (SELECT COUNT(*) FROM dbo.CalibrationCycles WHERE OrderDetailsItemId = @Expected AND IsDeleted = 0)
           AND SUM(CASE WHEN CycleNumber = 1 AND ToleranceValue = 20.5 AND ToleranceStart = -0.5 AND ToleranceEnd = 0.25
                         AND DisplayValue = 20.4 AND IsDisplayEnabled = 1 AND IsTargetValueEnabled = 0
                         AND ControllerTypeStatusId = @Digital AND ControllerModel = N'KB 240' THEN 1 ELSE 0 END) = 1
           AND SUM(CASE WHEN PreviousOrderDetailsItemId = @A AND CalibrationCycleStartDate = @Start2 THEN 1 ELSE 0 END) = 0,
           N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' cycles from line ', @Expected, IIF(@Expected = @A, N', deleted cycle checked', N' - FAIL: C should not win'))
FROM @Prev;
DELETE @Prev;

/* 9. A later line is never "previous". B was created after A and C; give it a cycle that ran last
   of all, so only the "created before this one" rule can keep it out when asking about A. */
DECLARE @BStart DATETIME2(0) = '2099-01-01 00:00:00', @BEnd DATETIME2(0) = '2099-01-02 00:00:00';
EXEC dbo.AddCalibrationCycle
    @UserEmail = @UserEmail, @OrderDetailsItemId = @B, @CalibrationCycleStartDate = @BStart,
    @CalibrationCycleEndDate = @BEnd, @CalibrationCycleName = @Name, @UnitId = @Unit, @TestedValue = @Tested,
    @SpecificationReferenceIds = @Refs, @CalibrationCycleStatusId = @Status, @CalibrationCycleNameStatusId = @NameStatus;

INSERT @Prev EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = @A;
INSERT @Results
SELECT N'9. a later line is not previous',
       IIF(ISNULL(SUM(CASE WHEN PreviousOrderDetailsItemId = @B THEN 1 ELSE 0 END), 0) = 0, N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows, none from later line ', @B)
FROM @Prev AS p;
DELETE @Prev;

/* 10. A line without SERN has no previous calibration. */
UPDATE dbo.OrderDetailsItems SET SERN = NULL WHERE OrderDetailsItemId = @B;
INSERT @Prev EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = @B;
INSERT @Results SELECT N'10. no SERN: no rows', IIF(COUNT(*) = 0, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' rows') FROM @Prev;
DELETE @Prev;
UPDATE dbo.OrderDetailsItems SET SERN = @Sern WHERE OrderDetailsItemId = @B;

/* 10a, 10b. An id on two live lines is never used. The second line is a copy of the row on another
   order, removed again after each step. */
DECLARE @Columns NVARCHAR(MAX) = (SELECT STRING_AGG(CAST(QUOTENAME(name) AS NVARCHAR(MAX)), N',')
                                  FROM sys.columns
                                  WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems') AND is_computed = 0
                                    AND name <> N'OrderDetailId');
DECLARE @OtherDetail INT = (SELECT TOP (1) OrderDetailId FROM dbo.OrderDetailsItems
                            WHERE OrderDetailId NOT IN (SELECT OrderDetailId FROM dbo.OrderDetailsItems
                                                        WHERE OrderDetailsItemId IN (@A, @B))
                            ORDER BY OrderDetailId DESC);
DECLARE @Copy NVARCHAR(MAX) = N'SET IDENTITY_INSERT dbo.OrderDetailsItems ON;
INSERT dbo.OrderDetailsItems (OrderDetailId,' + @Columns + N')
SELECT TOP (1) @d,' + @Columns + N' FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @i;
SET IDENTITY_INSERT dbo.OrderDetailsItems OFF;';

EXEC sp_executesql @Copy, N'@d INT, @i INT', @d = @OtherDetail, @i = @B;
INSERT @Prev EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = @B;
INSERT @Results SELECT N'10a. the line asked about is on two lines: no rows', IIF(COUNT(*) = 0, N'PASS', N'FAIL'), CONCAT(COUNT(*), N' rows') FROM @Prev;
DELETE @Prev;
DELETE dbo.OrderDetailsItems WHERE OrderDetailsItemId = @B AND OrderDetailId = @OtherDetail;

EXEC sp_executesql @Copy, N'@d INT, @i INT', @d = @OtherDetail, @i = @A;
INSERT @Prev EXEC dbo.GetPreviousCalibrationCycleSettings @OrderDetailsItemId = @B;
INSERT @Results
SELECT N'10b. a candidate on two lines is skipped',
       IIF(COUNT(*) > 0 AND MIN(PreviousOrderDetailsItemId) = @C AND MAX(PreviousOrderDetailsItemId) = @C
           AND SUM(CASE WHEN ControllerModel = N'IN 55' AND IsDisplayEnabled = 0 AND DisplayValue = 19.9 THEN 1 ELSE 0 END) = 1,
           N'PASS', N'FAIL'),
       CONCAT(COUNT(*), N' rows from line ', MIN(PreviousOrderDetailsItemId), N' (expected ', @C, N')')
FROM @Prev;
DELETE @Prev;
DELETE dbo.OrderDetailsItems WHERE OrderDetailsItemId = @A AND OrderDetailId = @OtherDetail;

/* 10c. Two users sharing an e-mail: the save still goes through, stamped with the lower id. */
DECLARE @FirstUser INT = (SELECT TOP (1) ID FROM dbo.Users WHERE Email = @UserEmail ORDER BY ID);
UPDATE dbo.Users SET Email = @UserEmail
WHERE ID = (SELECT TOP (1) ID FROM dbo.Users WHERE ID > @FirstUser ORDER BY ID);

INSERT @Out EXEC dbo.SaveCalibrationCycleSettings
    @UserEmail = @UserEmail, @OrderDetailsItemId = @A, @CalibrationCycleStartDate = @Start,
    @ToleranceValue = 20.5, @ToleranceStart = -0.5, @ToleranceEnd = 0.25, @Resolution = 0.1,
    @Uncertainty = 0.7, @StabilityThreshold = 0, @UniformityThreshold = NULL,
    @DisplayValue = 20.4, @DisplayResolution = NULL, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 0,
    @ControllerTypeStatusId = @Digital, @ControllerManufacturer = NULL, @ControllerModel = N'KB 240',
    @CalculationResolution = NULL, @Apply = 1;

INSERT @Results
SELECT N'10c. a shared e-mail still saves',
       IIF(o.Outcome = N'Saved' AND cc.Uncertainty = 0.7 AND cc.UpdateUserID = @FirstUser, N'PASS', N'FAIL'),
       CONCAT(o.Outcome, N', stamped user ', cc.UpdateUserID, N' (expected ', @FirstUser, N')')
FROM @Out AS o
JOIN dbo.CalibrationCycles AS cc ON cc.OrderDetailsItemId = @A AND cc.CalibrationCycleStartDate = @Start;
DELETE @Out;

ROLLBACK;

/* 11-19. Refusals, each in its own rolled-back transaction. */
DECLARE @Cases TABLE (N INT, Step NVARCHAR(100), Sql NVARCHAR(MAX), ExpectedError INT);
DECLARE @Call NVARCHAR(MAX) = N'EXEC dbo.SaveCalibrationCycleSettings @UserEmail = @u, @OrderDetailsItemId = @a, @CalibrationCycleStartDate = @s, ';
DECLARE @Rest NVARCHAR(MAX) = N', @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = NULL, @ControllerModel = NULL, @CalculationResolution = 1, @Apply = 1';
DECLARE @Ok7 NVARCHAR(MAX) = N'@ToleranceValue = 1, @ToleranceStart = -1, @ToleranceEnd = 1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = 1, @UniformityThreshold = 1';
INSERT @Cases VALUES
 (11, N'11. lower border > 0 refused',     @Call + N'@ToleranceValue = 1, @ToleranceStart = 0.1, @ToleranceEnd = 1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = 1, @UniformityThreshold = 1' + @Rest, 51000),
 (12, N'12. upper border < 0 refused',     @Call + N'@ToleranceValue = 1, @ToleranceStart = -1, @ToleranceEnd = -0.1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = 1, @UniformityThreshold = 1' + @Rest, 51000),
 (13, N'13. negative stability refused',   @Call + N'@ToleranceValue = 1, @ToleranceStart = -1, @ToleranceEnd = 1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = -1, @UniformityThreshold = 1' + @Rest, 51000),
 (14, N'14. negative uniformity refused',  @Call + N'@ToleranceValue = 1, @ToleranceStart = -1, @ToleranceEnd = 1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = 1, @UniformityThreshold = -1' + @Rest, 51000),
 (15, N'15. unknown cycle refused',        N'EXEC dbo.SaveCalibrationCycleSettings @UserEmail = @u, @OrderDetailsItemId = @a, @CalibrationCycleStartDate = ''1900-01-01'', ' + @Ok7 + @Rest, 51000),
 (16, N'16. deleted cycle refused',        N'UPDATE dbo.CalibrationCycles SET IsDeleted = 1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s; ' + @Call + @Ok7 + @Rest, 51000),
 (17, N'17. unknown user refused',         N'EXEC dbo.SaveCalibrationCycleSettings @UserEmail = N''nobody@example.invalid'', @OrderDetailsItemId = @a, @CalibrationCycleStartDate = @s, ' + @Ok7 + @Rest, 51000),
 (18, N'17a. controller of another category refused', @Call + @Ok7 + N', @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = @o, @ControllerManufacturer = NULL, @ControllerModel = NULL, @CalculationResolution = 1, @Apply = 1', 51000),
 (19, N'18. a missing value is an error, not a clear', @Call + N'@ToleranceValue = 1, @ToleranceStart = -1, @ToleranceEnd = 1, @Resolution = 1, @Uncertainty = 1, @StabilityThreshold = 1, @UniformityThreshold = 1, @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = NULL, @ControllerModel = NULL, @Apply = 1', 201),
 (20, N'19. CHECK stops a direct UPDATE',  N'UPDATE dbo.CalibrationCycles SET ToleranceStart = 1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547),
 (21, N'19a. FK stops an unknown controller status', N'UPDATE dbo.CalibrationCycles SET ControllerTypeStatusId = -1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547),
 (22, N'17b. negative display resolution refused', @Call + @Ok7 + N', @DisplayValue = 1, @DisplayResolution = -0.1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = NULL, @ControllerModel = NULL, @CalculationResolution = 1, @Apply = 1', 51000),
 (23, N'17c. negative calculation resolution refused', @Call + @Ok7 + N', @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = NULL, @ControllerModel = NULL, @CalculationResolution = -1, @Apply = 1', 51000),
 (24, N'17d. manufacturer over 100 characters refused, not cut', @Call + @Ok7 + N', @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = @long, @ControllerModel = NULL, @CalculationResolution = 1, @Apply = 1', 51000),
 (25, N'17e. model over 100 characters refused, not cut', @Call + @Ok7 + N', @DisplayValue = 1, @DisplayResolution = 1, @IsDisplayEnabled = 1, @IsTargetValueEnabled = 1, @ControllerTypeStatusId = NULL, @ControllerManufacturer = NULL, @ControllerModel = @long, @CalculationResolution = 1, @Apply = 1', 51000),
 (26, N'19b. CHECK stops a negative resolution', N'UPDATE dbo.CalibrationCycles SET DisplayResolution = -1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547),
 (27, N'19c. CHECK stops a negative calculation resolution', N'UPDATE dbo.CalibrationCycles SET CalculationResolution = -1 WHERE OrderDetailsItemId = @a AND CalibrationCycleStartDate = @s', 547);

DECLARE @Long NVARCHAR(200) = REPLICATE(N'x', 101);
DECLARE @n INT = 11, @sql NVARCHAR(MAX), @step NVARCHAR(100), @err INT;
WHILE @n <= 27
BEGIN
    SELECT @sql = Sql, @step = Step, @err = ExpectedError FROM @Cases WHERE N = @n;
    BEGIN TRY
        BEGIN TRAN;
        EXEC sp_executesql @sql, N'@u NVARCHAR(255), @a INT, @s DATETIME2(0), @o INT, @long NVARCHAR(200)',
             @u = @UserEmail, @a = @A, @s = @Start, @o = @OtherStatus, @long = @Long;
        ROLLBACK;
        INSERT @Results VALUES (@step, N'FAIL', N'went through');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        INSERT @Results VALUES (@step, IIF(ERROR_NUMBER() = @err, N'PASS', N'FAIL'),
                                CONCAT(ERROR_NUMBER(), N': ', LEFT(ERROR_MESSAGE(), 250)));
    END CATCH;
    SET @n += 1;
END;

/* 20. Nothing survived: all fifteen settings, the deleted flag and the update stamp. */
INSERT @Results
SELECT N'20. rolled back',
       IIF(NOT EXISTS (SELECT OrderDetailsItemId, CalibrationCycleStartDate, IsDeleted, UpdatedDate, UpdateUserID,
                              ToleranceValue, ToleranceStart, ToleranceEnd, Resolution, Uncertainty,
                              StabilityThreshold, UniformityThreshold, DisplayValue, DisplayResolution,
                              IsDisplayEnabled, IsTargetValueEnabled, ControllerTypeStatusId,
                              ControllerManufacturer, ControllerModel, CalculationResolution
                       FROM dbo.CalibrationCycles WHERE OrderDetailsItemId IN (@A, @C)
                       EXCEPT SELECT * FROM @Snapshot)
           AND (SELECT COUNT(*) FROM dbo.CalibrationCycles WHERE OrderDetailsItemId IN (@A, @C)) = (SELECT COUNT(*) FROM @Snapshot)
           AND NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE SERN = @Sern), N'PASS', N'FAIL'),
       CONCAT((SELECT COUNT(*) FROM @Snapshot), N' cycle rows on A and C unchanged');

SELECT Step, Result, Detail FROM @Results;
