/*
    Tests for dbo.SaveMasterSensorCorrectionsBatch                                     MBA-816
    ---------------------------------------------------------------------------------------------
    Run against a database where the procedure and dbo.fnMasterValueAfterCorrection are deployed.
    Anything other than 'PASS' in Result is a failure. Every write happens inside a transaction
    that is rolled back, so the file leaves the database as it found it.

    The procedure is judged by the READER, not by itself. What matters is not which rows it writes
    but what dbo.fnMasterValueAfterCorrection answers afterwards - that function is what the wizard
    and the logger compensate with. So each save is followed by questions to the function, and the
    expectations are literals worked by hand, not derived the way the procedure derives them:

        points   reference -40 <- reading -40.02         deviation  -0.02
                 reference   0 <- reading   0.03         deviation   0.03
                 reference 100 <- reading 100.10         deviation   0.10
                 reference 250 <- reading 250.05         deviation   0.05

    The certificate is laid out over the REFERENCE (Nofar, 24/09), so:

      * asked at a reference value, the function's Deviation is that point's deviation exactly.
        50 sits halfway between 0 and 100, so its deviation is halfway from 0.03 to 0.10 = 0.065.
      * asked at the READING, the corrected value lands within 1e-4 of the reference, not exactly
        on it: the lookup is by reading, so the line is evaluated a deviation's width away from its
        own point. At 100.10: range 100..250 has slope -0.05/150, deviation 0.10 - 0.10/3000 =
        0.0999667, corrected 100.0000333.

    A procedure that stored points instead of ranges, laid them over the reading, or got the sign
    backwards, fails here.
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
DECLARE @Points NVARCHAR(MAX) = N'[{"Reference":100,"Reading":100.10},{"Reference":-40,"Reading":-40.02},
                                   {"Reference":250,"Reading":250.05},{"Reference":0,"Reading":0.03}]';

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
INSERT @Out SELECT N'1 dry run', N'ranges start at the reference values, not the readings',
       N'-40 / 0 / 100', CONCAT(CAST(MIN(Value1) AS DECIMAL(9,2)), N' .. ', CAST(MAX(Value1) AS DECIMAL(9,2))),
       CASE WHEN (SELECT COUNT(*) FROM #R WHERE Value1 IN (-40, 0, 100)) = 3 THEN N'PASS' ELSE N'FAIL' END
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

/* at each reference value the certificate gives that point's deviation - exact */
INSERT @Out
SELECT N'2 at ref', CONCAT(N'deviation at reference ', v.Ref),
       CAST(v.Expected AS NVARCHAR(40)), CAST(f.Deviation AS NVARCHAR(40)),
       CASE WHEN ABS(f.Deviation - v.Expected) < 0.000001 THEN N'PASS' ELSE N'FAIL' END
FROM (VALUES (-40, -0.02), (0, 0.03), (100, 0.10), (250, 0.05), (50, 0.065)) AS v (Ref, Expected)
CROSS APPLY dbo.fnMasterValueAfterCorrection(@D1, v.Ref, @M1) AS f;

/* a real reading corrects to its reference, to within slope x deviation (see the header) */
INSERT @Out
SELECT N'2 reading', CONCAT(N'reading ', v.Reading, N' corrects to ', v.Ref, N' within 1e-4'),
       CAST(v.Ref AS NVARCHAR(40)), CAST(f.CorrectedExact AS NVARCHAR(40)),
       CASE WHEN ABS(f.CorrectedExact - v.Ref) < 0.0001 THEN N'PASS' ELSE N'FAIL' END
FROM (VALUES (-40.02, -40), (0.03, 0), (100.10, 100), (250.05, 250)) AS v (Reading, Ref)
CROSS APPLY dbo.fnMasterValueAfterCorrection(@D1, v.Reading, @M1) AS f;

INSERT @Out SELECT N'2 at ref', N'the top reference is inside the certificate, not beyond it',
       N'0', ISNULL(CAST(f.OutOfRange AS NVARCHAR(40)), N'NULL'),
       CASE WHEN f.OutOfRange = 0 THEN N'PASS' ELSE N'FAIL' END
FROM dbo.fnMasterValueAfterCorrection(@D1, 250, @M1) AS f;

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
           N'0.065000', ISNULL(CAST(f.Deviation AS NVARCHAR(40)), N'NULL'),
           CASE WHEN ABS(f.Deviation - 0.065) < 0.000001 THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.fnMasterValueAfterCorrection(@D2, 50, @M2) AS f;
    ROLLBACK TRANSACTION;
END
ELSE
    INSERT @Out VALUES (N'3 carry', N'no two-quantity master in this database', N'-', N'-', N'SKIPPED');


/* =============================================================================================
   Section 4 - naming the master by MabaID, as the lab does
   ============================================================================================= */
DECLARE @Maba1 NVARCHAR(50) = (SELECT LTRIM(RTRIM(MabaID)) FROM dbo.MeasurementDevices WHERE ID = @D1);

IF (SELECT COUNT(*) FROM dbo.MeasurementDevices
    WHERE IsDeleted = 0 AND LTRIM(RTRIM(MabaID)) = @Maba1) = 1
BEGIN
    DELETE #R;
    INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch
        @LoggedInUserEmail = @Email, @MeasurementDevicesId = NULL, @Data = @Points,
        @MeasurementId = @M1, @Apply = 0, @MabaID = @Maba1;
    INSERT @Out SELECT N'4 MabaID', CONCAT(N'MabaID ', @Maba1, N' plans the same three ranges'),
           N'3 WouldSave', CONCAT(COUNT(*), N' ', MIN(Outcome)),
           CASE WHEN COUNT(*) = 3 AND MIN(Outcome) = N'WouldSave' THEN N'PASS' ELSE N'FAIL' END
    FROM #R;
END
ELSE
    INSERT @Out VALUES (N'4 MabaID', N'device 1 has no unique MabaID here', N'-', N'-', N'SKIPPED');


/* =============================================================================================
   Section 5 - input the procedure must refuse, before it writes anything
   ============================================================================================= */
DECLARE @DupMaba NVARCHAR(50) =
    (SELECT TOP (1) LTRIM(RTRIM(MabaID)) FROM dbo.MeasurementDevices WHERE IsDeleted = 0
     GROUP BY LTRIM(RTRIM(MabaID)) HAVING COUNT(*) > 1);

DECLARE @Bad TABLE (Test NVARCHAR(80), DeviceId INT, MabaID NVARCHAR(50), Data NVARCHAR(MAX));
INSERT @Bad VALUES
 (N'refuses a single point',                  @D1, NULL, N'[{"Reference":1,"Reading":1}]'),
 (N'refuses two points at one reference',     @D1, NULL, N'[{"Reference":1,"Reading":1},{"Reference":1,"Reading":2}]'),
 (N'refuses a point with no reading',         @D1, NULL, N'[{"Reference":1,"Reading":1},{"Reference":2}]'),
 (N'refuses text that is not JSON',           @D1, NULL, N'not json'),
 (N'refuses a MabaID no master carries',      NULL, N'no-such-maba-id', @Points),
 (N'refuses neither id nor MabaID',           NULL, NULL, @Points);
IF @DupMaba IS NOT NULL
    INSERT @Bad VALUES (N'refuses a MabaID held by two live devices', NULL, @DupMaba, @Points);

DECLARE @T NVARCHAR(80), @Dv INT, @Mb NVARCHAR(50), @J NVARCHAR(MAX), @Err NVARCHAR(400);
DECLARE b CURSOR LOCAL FAST_FORWARD FOR SELECT Test, DeviceId, MabaID, Data FROM @Bad;
OPEN b; FETCH b INTO @T, @Dv, @Mb, @J;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        DELETE #R;
        INSERT #R EXEC dbo.SaveMasterSensorCorrectionsBatch
            @LoggedInUserEmail = @Email, @MeasurementDevicesId = @Dv, @Data = @J,
            @MeasurementId = @M1, @Apply = 1, @MabaID = @Mb;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT @Out SELECT N'5 refuse', @T, N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
           CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;
    FETCH b INTO @T, @Dv, @Mb, @J;
END;
CLOSE b; DEALLOCATE b;


/* ============================================================================================= */
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

SELECT @Fail = COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%';
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out),
       Device1 = @D1, Device2 = @D2;
