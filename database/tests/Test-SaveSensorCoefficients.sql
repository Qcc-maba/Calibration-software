/*
    Tests for dbo.SaveSensorCoefficients and dbo.GetSensorCoefficients                 MBA-816
    ---------------------------------------------------------------------------------------------
    Run against a database where both procedures and the dbo.ConversionParameters changes are
    deployed. Anything other than 'PASS' in Result is a failure. Every write happens inside a
    transaction that is rolled back, so the file leaves the database as it found it.

    The save is judged by the READER: every save is read back through dbo.GetSensorCoefficients,
    which is what the screens and the station will use, and compared against literals.

    Two real coefficient sets are used:
        S1  sensor 21-214's, as hard-coded in HydraCalculations.CalcResistanceToTemperatureITS90
            RTP 100.0018614  A4 -0.0188349  B4 0.00064590173677  A7 -0.01943119  B7 -0.00032928408
            C7 0.00022327774
        S2  the example in the old dbo.CreateConversionParameter (a 25-ohm sensor)
            RTP 25.4011  A4 -0.00010288  B4 -0.0000052588  A7 -0.00011873  B7 -0.0000016079
            C7 -0.000003391
*/
SET NOCOUNT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(80),
                    Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(60));
DROP TABLE IF EXISTS #S;
CREATE TABLE #S (Outcome NVARCHAR(10), ConversionParameterId INT, MeasurementDevicesId INT,
                 MabaID NVARCHAR(50), RTP DECIMAL(35,15), A4 DECIMAL(35,15), B4 DECIMAL(35,15),
                 A7 DECIMAL(35,15), B7 DECIMAL(35,15), C7 DECIMAL(35,15), OrderDetailsItemId INT);
DROP TABLE IF EXISTS #G;
CREATE TABLE #G (ConversionParameterId INT, MeasurementDevicesId INT, MabaID NVARCHAR(50),
                 RTP DECIMAL(35,15), A4 DECIMAL(35,15), B4 DECIMAL(35,15), A7 DECIMAL(35,15),
                 B7 DECIMAL(35,15), C7 DECIMAL(35,15), OrderDetailsItemId INT, CreatedDate DATETIME2,
                 UpdateUserID INT, IsCurrent BIT);

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

/* S1 and S2 */
DECLARE @R1 DECIMAL(35,15) = 100.0018614, @A41 DECIMAL(35,15) = -0.0188349,
        @B41 DECIMAL(35,15) = 0.00064590173677, @A71 DECIMAL(35,15) = -0.01943119,
        @B71 DECIMAL(35,15) = -0.00032928408, @C71 DECIMAL(35,15) = 0.00022327774;
DECLARE @R2 DECIMAL(35,15) = 25.4011, @A42 DECIMAL(35,15) = -0.00010288,
        @B42 DECIMAL(35,15) = -0.0000052588, @A72 DECIMAL(35,15) = -0.00011873,
        @B72 DECIMAL(35,15) = -0.0000016079, @C72 DECIMAL(35,15) = -0.000003391;

/* two live sensors whose MabaID is theirs alone - 21-214 first when it qualifies */
DECLARE @Unique TABLE (Rn INT IDENTITY, ID INT, MabaID NVARCHAR(50));
INSERT @Unique (ID, MabaID)
SELECT TOP (2) MIN(md.ID), LTRIM(RTRIM(md.MabaID))
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0 AND NULLIF(LTRIM(RTRIM(md.MabaID)), N'') IS NOT NULL
GROUP BY LTRIM(RTRIM(md.MabaID))
HAVING COUNT(*) = 1
ORDER BY CASE WHEN LTRIM(RTRIM(md.MabaID)) = N'21-214' THEN 0 ELSE 1 END, MIN(md.ID);

DECLARE @D1 INT, @M1 NVARCHAR(50), @D2 INT, @M2 NVARCHAR(50);
SELECT @D1 = ID, @M1 = MabaID FROM @Unique WHERE Rn = 1;
SELECT @D2 = ID, @M2 = MabaID FROM @Unique WHERE Rn = 2;

DECLARE @Before INT, @After INT, @FirstId INT;


/* =============================================================================================
   Section 1 - a dry run writes nothing
   ============================================================================================= */
SELECT @Before = COUNT(*) FROM dbo.ConversionParameters;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M1,
    @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71, @B7 = @B71, @C7 = @C71;
SELECT @After = COUNT(*) FROM dbo.ConversionParameters;

INSERT @Out SELECT N'1 dry run', N'@Apply = 0 writes no rows', CAST(@Before AS NVARCHAR(12)), CAST(@After AS NVARCHAR(12)),
       CASE WHEN @Before = @After THEN N'PASS' ELSE N'FAIL' END;
INSERT @Out SELECT N'1 dry run', CONCAT(N'MabaID ', @M1, N' resolves; outcome WouldSave, no id'),
       CONCAT(@D1, N' WouldSave NULL'),
       CONCAT(MeasurementDevicesId, N' ', Outcome, N' ', ISNULL(CAST(ConversionParameterId AS NVARCHAR(12)), N'NULL')),
       CASE WHEN MeasurementDevicesId = @D1 AND Outcome = N'WouldSave' AND ConversionParameterId IS NULL
            THEN N'PASS' ELSE N'FAIL' END
FROM #S;


/* =============================================================================================
   Section 2 - saves, read back through GetSensorCoefficients
   ============================================================================================= */
BEGIN TRANSACTION;

/* S1 on sensor 1 */
DELETE #S;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M1,
    @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71, @B7 = @B71, @C7 = @C71,
    @OrderDetailsItemId = 424242, @Apply = 1;
SELECT @FirstId = ConversionParameterId FROM #S;

INSERT @Out SELECT N'2 save', N'first save: Saved, with the new row''s id',
       N'Saved + id', CONCAT(Outcome, N' ', ConversionParameterId),
       CASE WHEN Outcome = N'Saved' AND ConversionParameterId IS NOT NULL THEN N'PASS' ELSE N'FAIL' END
FROM #S;

DELETE #G;
INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = @M1;
INSERT @Out
SELECT N'2 read back', CONCAT(v.Name, N' reads back exactly'), CAST(v.Expected AS NVARCHAR(60)),
       CAST(v.Actual AS NVARCHAR(60)), CASE WHEN v.Actual = v.Expected THEN N'PASS' ELSE N'FAIL' END
FROM #G AS g
CROSS APPLY (VALUES (N'RTP', @R1, g.RTP), (N'A4', @A41, g.A4), (N'B4', @B41, g.B4),
                    (N'A7', @A71, g.A7), (N'B7', @B71, g.B7), (N'C7', @C71, g.C7)) AS v (Name, Expected, Actual);
INSERT @Out SELECT N'2 read back', N'the calibration it came from is kept',
       N'424242 current', CONCAT(OrderDetailsItemId, CASE WHEN IsCurrent = 1 THEN N' current' ELSE N' not current' END),
       CASE WHEN OrderDetailsItemId = 424242 AND IsCurrent = 1 THEN N'PASS' ELSE N'FAIL' END
FROM #G;

/* the same values again: nothing written, the existing row named */
DELETE #S;
SELECT @Before = COUNT(*) FROM dbo.ConversionParameters WHERE MeasurementDevicesId = @D1;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M1,
    @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71, @B7 = @B71, @C7 = @C71, @Apply = 1;
SELECT @After = COUNT(*) FROM dbo.ConversionParameters WHERE MeasurementDevicesId = @D1;
INSERT @Out SELECT N'2 repeat', N'identical values again: NoChange, no row, same id',
       CONCAT(N'NoChange ', @Before, N' ', @FirstId), CONCAT(Outcome, N' ', @After, N' ', ConversionParameterId),
       CASE WHEN Outcome = N'NoChange' AND @Before = @After AND ConversionParameterId = @FirstId
            THEN N'PASS' ELSE N'FAIL' END
FROM #S;

/* S2 replaces S1 as current; S1 stays as history */
DELETE #S;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M1,
    @RTP = @R2, @A4 = @A42, @B4 = @B42, @A7 = @A72, @B7 = @B72, @C7 = @C72, @Apply = 1;
DELETE #G;
INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = @M1;
INSERT @Out SELECT N'2 history', N'new values become the current set',
       CAST(@R2 AS NVARCHAR(60)), CAST(RTP AS NVARCHAR(60)),
       CASE WHEN COUNT(*) OVER () = 1 AND RTP = @R2 AND C7 = @C72 THEN N'PASS' ELSE N'FAIL' END
FROM #G;
DELETE #G;
INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = @M1, @IncludeHistory = 1;
INSERT @Out SELECT N'2 history', N'history keeps the old set, not current',
       N'2 rows, 1 current', CONCAT(COUNT(*), N' rows, ', SUM(CAST(IsCurrent AS INT)), N' current'),
       CASE WHEN COUNT(*) = 2 AND SUM(CAST(IsCurrent AS INT)) = 1
             AND MAX(CASE WHEN IsCurrent = 0 THEN RTP END) = @R1 THEN N'PASS' ELSE N'FAIL' END
FROM #G;

/* back to S1: a real new calibration, so a third row - not NoChange against the older row */
DELETE #S;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M1,
    @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71, @B7 = @B71, @C7 = @C71, @Apply = 1;
INSERT @Out SELECT N'2 history', N'A, B, then A again: saved, three rows',
       N'Saved 3', CONCAT(Outcome, N' ', (SELECT COUNT(*) FROM dbo.ConversionParameters
                                          WHERE MeasurementDevicesId = @D1 AND IsDeleted = 0)),
       CASE WHEN Outcome = N'Saved' AND (SELECT COUNT(*) FROM dbo.ConversionParameters
                                         WHERE MeasurementDevicesId = @D1 AND IsDeleted = 0) = 3
            THEN N'PASS' ELSE N'FAIL' END
FROM #S;

/* the same values on ANOTHER sensor: allowed - the old procedure's check spanned the whole table */
DELETE #S;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D2,
    @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71, @B7 = @B71, @C7 = @C71, @Apply = 1;
INSERT @Out SELECT N'2 per sensor', CONCAT(N'identical values on ', @M2, N' (by device id) are saved'),
       N'Saved', Outcome, CASE WHEN Outcome = N'Saved' THEN N'PASS' ELSE N'FAIL' END
FROM #S;

/* a sensor used above 0 degC only: zeros for the A4/B4 range */
DELETE #S;
INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @M2,
    @RTP = @R2, @A4 = 0, @B4 = 0, @A7 = @A72, @B7 = @B72, @C7 = @C72, @Apply = 1;
INSERT @Out SELECT N'2 one range', N'zeros for the unused range are accepted',
       N'Saved', Outcome, CASE WHEN Outcome = N'Saved' THEN N'PASS' ELSE N'FAIL' END
FROM #S;

ROLLBACK TRANSACTION;


/* =============================================================================================
   Section 3 - reading with nothing on file is an answer, not an error
   ============================================================================================= */
DECLARE @GetErr NVARCHAR(400);
BEGIN TRY
    DELETE #G;
    INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = N'no-such-maba-id';
END TRY
BEGIN CATCH
    SET @GetErr = ERROR_MESSAGE();
END CATCH;
INSERT @Out SELECT N'3 read', N'unknown MabaID: no rows, no error',
       N'0 rows', ISNULL(LEFT(@GetErr, 40), CONCAT((SELECT COUNT(*) FROM #G), N' rows')),
       CASE WHEN @GetErr IS NULL AND NOT EXISTS (SELECT 1 FROM #G) THEN N'PASS' ELSE N'FAIL' END;

DELETE #G;
INSERT #G EXEC dbo.GetSensorCoefficients;
INSERT @Out SELECT N'3 read', N'no sensor named: no rows (never the whole table)',
       N'0 rows', CONCAT((SELECT COUNT(*) FROM #G), N' rows'),
       CASE WHEN NOT EXISTS (SELECT 1 FROM #G) THEN N'PASS' ELSE N'FAIL' END;


/* =============================================================================================
   Section 4 - input that must be refused, before anything is written
   ============================================================================================= */
DECLARE @DupMaba NVARCHAR(50), @DupId INT;
SELECT TOP (1) @DupMaba = LTRIM(RTRIM(MabaID)), @DupId = MIN(ID)
FROM dbo.MeasurementDevices WHERE IsDeleted = 0 AND NULLIF(LTRIM(RTRIM(MabaID)), N'') IS NOT NULL
GROUP BY LTRIM(RTRIM(MabaID)) HAVING COUNT(*) > 1;

DECLARE @Bad TABLE (Test NVARCHAR(80), Maba NVARCHAR(50), DevId INT, R DECIMAL(35,15), C7 DECIMAL(35,15));
INSERT @Bad VALUES
 (N'refuses a missing coefficient (C7)',             @M1,  NULL, @R1, NULL),
 (N'refuses RTP = 0',                                @M1,  NULL, 0,   @C71),
 (N'refuses a negative RTP',                         @M1,  NULL, -1,  @C71),
 (N'refuses a MabaID no sensor carries',             N'no-such-maba-id', NULL, @R1, @C71),
 (N'refuses MabaID and device id naming two devices', @M1, @D2,  @R1, @C71),
 (N'refuses neither MabaID nor device id',           NULL, NULL, @R1, @C71);
IF @DupMaba IS NOT NULL
    INSERT @Bad VALUES (N'refuses a MabaID held by two live devices', @DupMaba, NULL, @R1, @C71);

DECLARE @T NVARCHAR(80), @Mb NVARCHAR(50), @Dv INT, @Rx DECIMAL(35,15), @Cx DECIMAL(35,15), @Err NVARCHAR(400);
DECLARE b CURSOR LOCAL FAST_FORWARD FOR SELECT Test, Maba, DevId, R, C7 FROM @Bad;
OPEN b; FETCH b INTO @T, @Mb, @Dv, @Rx, @Cx;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Err = NULL;
    SELECT @Before = COUNT(*) FROM dbo.ConversionParameters;
    BEGIN TRY
        DELETE #S;
        INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @Mb,
            @MeasurementDevicesId = @Dv, @RTP = @Rx, @A4 = @A41, @B4 = @B41, @A7 = @A71,
            @B7 = @B71, @C7 = @Cx, @Apply = 1;
    END TRY
    BEGIN CATCH
        SET @Err = ERROR_MESSAGE();
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;
    SELECT @After = COUNT(*) FROM dbo.ConversionParameters;
    INSERT @Out SELECT N'4 refuse', @T, N'an error, nothing written', ISNULL(LEFT(@Err, 40), N'accepted'),
           CASE WHEN @Err IS NOT NULL AND @Before = @After THEN N'PASS' ELSE N'FAIL' END;
    FETCH b INTO @T, @Mb, @Dv, @Rx, @Cx;
END;
CLOSE b; DEALLOCATE b;

/* reading with a MabaID and a device id that disagree: an error, as the save raises - an empty
   result would read as "no coefficients on file" (PR #18 review) */
SET @Err = NULL;
BEGIN TRY
    DELETE #G;
    INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = @M1, @MeasurementDevicesId = @D2;
END TRY
BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
INSERT @Out SELECT N'4 refuse', N'reading with MabaID and device id naming two devices is refused',
       N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
       CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;

/* the same ambiguous MabaID is accepted once the device id says which one is meant */
IF @DupMaba IS NOT NULL
BEGIN
    SET @Err = NULL;
    BEGIN TRY
        DELETE #S;
        INSERT #S EXEC dbo.SaveSensorCoefficients @LoggedInUserEmail = @Email, @MabaID = @DupMaba,
            @MeasurementDevicesId = @DupId, @RTP = @R1, @A4 = @A41, @B4 = @B41, @A7 = @A71,
            @B7 = @B71, @C7 = @C71;
    END TRY
    BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
    INSERT @Out SELECT N'4 refuse', CONCAT(N'shared MabaID ', @DupMaba, N' + its device id is accepted'),
           N'WouldSave', ISNULL((SELECT Outcome FROM #S), LEFT(@Err, 40)),
           CASE WHEN @Err IS NULL AND (SELECT Outcome FROM #S) = N'WouldSave' THEN N'PASS' ELSE N'FAIL' END;

    SET @Err = NULL;
    BEGIN TRY
        DELETE #G;
        INSERT #G EXEC dbo.GetSensorCoefficients @MabaID = @DupMaba;
    END TRY
    BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
    INSERT @Out SELECT N'4 refuse', N'reading a shared MabaID alone is refused, not guessed',
           N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
           CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;
END;


/* =============================================================================================
   Section 5 - the table itself refuses what the procedure refuses
   ============================================================================================= */
SET @Err = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.ConversionParameters (MeasurementDevicesId, RTP, A4, B4, A7, B7, C7, CreatedDate, IsDeleted)
    VALUES (@D1, 0, 0, 0, 0, 0, 0, GETDATE(), 0);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
INSERT @Out SELECT N'5 table', N'a direct insert with RTP = 0 is refused by the table',
       N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
       CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;

SET @Err = NULL;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.ConversionParameters (RTP, A4, B4, A7, B7, C7, CreatedDate, IsDeleted)
    VALUES (@R1, @A41, @B41, @A71, @B71, @C71, GETDATE(), 0);
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @Err = ERROR_MESSAGE();
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
END CATCH;
INSERT @Out SELECT N'5 table', N'a direct insert with no sensor is refused by the table',
       N'an error', ISNULL(LEFT(@Err, 40), N'accepted'),
       CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;


/* ============================================================================================= */
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

DECLARE @Fail INT = (SELECT COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%');
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out),
       Sensor1 = @M1, Sensor2 = @M2;
