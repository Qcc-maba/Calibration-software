/*
    Tests for dbo.SaveMasterSensorCorrectionsBatch                                     MBA-816
    ---------------------------------------------------------------------------------------------
    Run against a database where the procedure and dbo.fnMasterValueAfterCorrection are deployed.
    Anything other than 'PASS' in Result is a failure. Every write happens inside a transaction
    that is rolled back, so the file leaves the database as it found it.

    The procedure is judged by the READER, not by itself. What matters is not which rows it writes
    but what dbo.fnMasterValueAfterCorrection answers afterwards - that function is what the wizard
    and the logger compensate with. So each save is followed by readings through the function, and
    the expectations are literals worked by hand, not derived the way the procedure derives them:

        points   reading -40.02 -> reference -40.00      deviation  -0.02
                 reading   0.03 -> reference   0.00      deviation   0.03
                 reading 100.10 -> reference 100.00      deviation   0.10
                 reading 250.05 -> reference 250.00      deviation   0.05

        at each point the corrected value must be the reference itself.

        between points, 50.065 sits exactly halfway from 0.03 to 100.10 (100.07 / 2 = 50.035),
        so its deviation is halfway from 0.03 to 0.10 = 0.065, and the corrected value is 50.000.
        A procedure that stored points instead of ranges, or got the sign backwards, fails here.
*/
SET NOCOUNT ON;

DECLARE @Fail INT = 0;
DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(80),
                    Expected NVARCHAR(40), Actual NVARCHAR(40), Result NVARCHAR(60));
DROP TABLE IF EXISTS #R;
CREATE TABLE #R (Outcome NVARCHAR(10), CorVersion INT, Source NVARCHAR(20), MeasurementId INT,
                 Value1 DECIMAL(25,15), Value2 DECIMAL(25,15), Deviation DECIMAL(35,15),
                 Equation NVARCHAR(300));

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);
DECLARE @Points NVARCHAR(MAX) = N'[{"Reading":100.10,"Reference":100.00},{"Reading":-40.02,"Reference":-40.00},
                                   {"Reading":250.05,"Reference":250.00},{"Reading":0.03,"Reference":0.00}]';

/* a master whose newest certificate carries one quantity, and one whose newest carries two */
DECLARE @D1 INT, @M1 INT, @D2 INT, @M2 INT, @Other INT;
WITH Newest AS
(
    SELECT c.MeasurementDevicesId, c.MeasurementId,
           Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    JOIN dbo.MeasurementDevices AS md ON md.ID = c.MeasurementDevicesId AND md.IsDeleted = 0
    WHERE c.IsDeleted = 0 AND c.MeasurementId IS NOT NULL
)
SELECT TOP (1) @D1 = MeasurementDevicesId, @M1 = MIN(MeasurementId)
FROM Newest WHERE Rnk = 1
GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1
ORDER BY MeasurementDevicesId;

WITH Newest AS
(
    SELECT c.MeasurementDevicesId, c.MeasurementId,
           Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    JOIN dbo.MeasurementDevices AS md ON md.ID = c.MeasurementDevicesId AND md.IsDeleted = 0
    WHERE c.IsDeleted = 0 AND c.MeasurementId IS NOT NULL
)
SELECT TOP (1) @D2 = MeasurementDevicesId, @M2 = MIN(MeasurementId), @Other = MAX(MeasurementId)
FROM Newest WHERE Rnk = 1
GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 2
ORDER BY MeasurementDevicesId;

DECLARE @Before INT, @MaxBefore INT, @After INT, @OldRows INT, @OldRowsAfter INT;


/* =============================================================================================
   Section 1 - a dry run writes nothing
   ============================================================================================= */
SELECT @Before = COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1;
INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @Email, @D1, @Points, @M1, NULL, NULL, 0;
SELECT @After = COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1;

INSERT @Out SELECT N'1 dry run', N'@Apply = 0 writes no rows',
       CAST(@Before AS NVARCHAR(40)), CAST(@After AS NVARCHAR(40)),
       CASE WHEN @Before = @After THEN N'PASS' ELSE N'FAIL' END;
INSERT @Out SELECT N'1 dry run', N'four points plan three ranges, outcome WouldSave',
       N'3 WouldSave', CONCAT(COUNT(*), N' ', MIN(Outcome)),
       CASE WHEN COUNT(*) = 3 AND MIN(Outcome) = N'WouldSave' AND MAX(Outcome) = N'WouldSave'
            THEN N'PASS' ELSE N'FAIL' END
FROM #R;


/* =============================================================================================
   Section 2 - a save, read back through the function
   ============================================================================================= */
BEGIN TRANSACTION;

SELECT @MaxBefore = MAX(CorVersion), @OldRows = COUNT(*)
FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1 AND IsDeleted = 0;

DELETE #R;
INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @Email, @D1, @Points, @M1, NULL, NULL, 1;

INSERT @Out SELECT N'2 save', N'new version = previous highest + 1',
       CAST(@MaxBefore + 1 AS NVARCHAR(40)), CAST(MAX(CorVersion) AS NVARCHAR(40)),
       CASE WHEN MAX(CorVersion) = @MaxBefore + 1 THEN N'PASS' ELSE N'FAIL' END
FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1 AND IsDeleted = 0;

SELECT @OldRowsAfter = COUNT(*) FROM dbo.MeasurementDevicesCorrections
WHERE MeasurementDevicesId = @D1 AND IsDeleted = 0 AND CorVersion <= @MaxBefore;
INSERT @Out SELECT N'2 save', N'earlier versions are left untouched',
       CAST(@OldRows AS NVARCHAR(40)), CAST(@OldRowsAfter AS NVARCHAR(40)),
       CASE WHEN @OldRows = @OldRowsAfter THEN N'PASS' ELSE N'FAIL' END;

INSERT @Out
SELECT N'2 read back', CONCAT(N'reading ', v.Reading, N' corrects to its reference'),
       CAST(v.Expected AS NVARCHAR(40)), CAST(f.CorrectedExact AS NVARCHAR(40)),
       CASE WHEN ABS(f.CorrectedExact - v.Expected) < 0.000001 THEN N'PASS' ELSE N'FAIL' END
FROM (VALUES (-40.02, -40.000), (0.03, 0.000), (100.10, 100.000), (250.05, 250.000),
             (50.065, 50.000)) AS v (Reading, Expected)
CROSS APPLY dbo.fnMasterValueAfterCorrection(@D1, v.Reading, @M1) AS f;

INSERT @Out SELECT N'2 read back', N'the top point is inside the certificate, not beyond it',
       N'0', ISNULL(CAST(f.OutOfRange AS NVARCHAR(40)), N'NULL'),
       CASE WHEN f.OutOfRange = 0 THEN N'PASS' ELSE N'FAIL' END
FROM dbo.fnMasterValueAfterCorrection(@D1, 250.05, @M1) AS f;

/* the same points again: nothing to write */
DELETE #R;
SELECT @Before = COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1;
INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @Email, @D1, @Points, @M1, NULL, NULL, 1;
SELECT @After = COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D1;
INSERT @Out SELECT N'2 repeat', N'saving identical points again writes nothing',
       CONCAT(@Before, N' NoChange'), CONCAT(@After, N' ', (SELECT MIN(Outcome) FROM #R)),
       CASE WHEN @Before = @After AND (SELECT MIN(Outcome) FROM #R) = N'NoChange'
            THEN N'PASS' ELSE N'FAIL' END;

ROLLBACK TRANSACTION;


/* =============================================================================================
   Section 3 - a two-quantity master keeps its other certificate

   The function reads the newest CorVersion of the whole device. Without the carry-forward, saving
   one quantity would leave the other with no rows in the newest version and it would stop
   answering. Its answer before and after the save must be identical.
   ============================================================================================= */
IF @D2 IS NOT NULL
BEGIN
    DECLARE @Probe DECIMAL(18,6) =
        (SELECT TOP (1) c.Value1 FROM dbo.MeasurementDevicesCorrections AS c
         WHERE c.MeasurementDevicesId = @D2 AND c.MeasurementId = @Other AND c.IsDeleted = 0
         ORDER BY c.CorVersion DESC, c.Value1);
    DECLARE @OtherBefore DECIMAL(18,6) =
        (SELECT CorrectedExact FROM dbo.fnMasterValueAfterCorrection(@D2, @Probe + 0.5, @Other));

    BEGIN TRANSACTION;
    DELETE #R;
    INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @Email, @D2, @Points, @M2, NULL, NULL, 1;

    INSERT @Out SELECT N'3 carry', N'the other quantity answers exactly as before',
           ISNULL(CAST(@OtherBefore AS NVARCHAR(40)), N'NULL'),
           ISNULL(CAST(f.CorrectedExact AS NVARCHAR(40)), N'NULL'),
           CASE WHEN @OtherBefore IS NOT NULL AND f.CorrectedExact = @OtherBefore
                THEN N'PASS' ELSE N'FAIL' END
    FROM (SELECT 1 AS x) AS one
    OUTER APPLY dbo.fnMasterValueAfterCorrection(@D2, @Probe + 0.5, @Other) AS f;

    INSERT @Out SELECT N'3 carry', N'the saved quantity reads the new certificate',
           N'50.000000', ISNULL(CAST(f.CorrectedExact AS NVARCHAR(40)), N'NULL'),
           CASE WHEN ABS(f.CorrectedExact - 50) < 0.000001 THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.fnMasterValueAfterCorrection(@D2, 50.065, @M2) AS f;
    ROLLBACK TRANSACTION;
END
ELSE
    INSERT @Out VALUES (N'3 carry', N'no two-quantity master in this database', N'-', N'-', N'SKIPPED');


/* =============================================================================================
   Section 4 - input the procedure must refuse, before it writes anything
   ============================================================================================= */
DECLARE @Bad TABLE (Test NVARCHAR(80), Data NVARCHAR(MAX));
INSERT @Bad VALUES
 (N'refuses a single point',            N'[{"Reading":1,"Reference":1}]'),
 (N'refuses two points at one reading', N'[{"Reading":1,"Reference":1},{"Reading":1,"Reference":2}]'),
 (N'refuses a point with no reference', N'[{"Reading":1,"Reference":1},{"Reading":2}]'),
 (N'refuses text that is not JSON',     N'not json');

DECLARE @T NVARCHAR(80), @J NVARCHAR(MAX), @Err NVARCHAR(400);
DECLARE b CURSOR LOCAL FAST_FORWARD FOR SELECT Test, Data FROM @Bad;
OPEN b; FETCH b INTO @T, @J;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        DELETE #R;
        INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch @Email, @D1, @J, @M1, NULL, NULL, 1;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'4 refuse', @T, N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
           CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;
    FETCH b INTO @T, @J;
END;
CLOSE b; DEALLOCATE b;


/* ============================================================================================= */
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

SELECT @Fail = COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%';
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out),
       Device1 = @D1, Device2 = @D2;
