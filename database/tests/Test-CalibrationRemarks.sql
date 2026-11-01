/*
    Tests for the calibration remarks procedures                                           MBA-848
    ---------------------------------------------------------------------------------------------
    dbo.fnRenderRemarkTemplate, dbo.GetPredefinedRemarks, dbo.SaveCalibrationRemarks,
    dbo.GetCalibrationRemarks, dbo.SetCalibrationRemarksLock, dbo.GetCalibrationRemarksLock.

    Run against a database where the two tables, the RemarksLockedDate column and the procedures
    are deployed. It does not need the seed: it adds its own list rows. Anything other than 'PASS'
    in Result is a failure. Every write happens inside a transaction that is rolled back, so the
    file leaves the database as it found it. Each refusal runs in a transaction of its own, because
    the procedures run with XACT_ABORT ON and an error dooms the transaction it happens in.

    The expected texts are literals, not derived the way the procedure derives them: a remark
    "Sensor {1} at {2} cm" with values 7 and 30 must read "Sensor 7 at 30 cm", and its Hebrew
    "רגש {1} במרחק {2} ס""מ" must carry the same two values.
*/
SET NOCOUNT ON;

DECLARE @Fail INT = 0;
DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(90),
                    Expected NVARCHAR(120), Actual NVARCHAR(120), Result NVARCHAR(60));

DROP TABLE IF EXISTS #S;
CREATE TABLE #S (Outcome NVARCHAR(10), DisplayOrder INT, PredefinedRemarkId INT, ValuesJson NVARCHAR(MAX),
                 IsCustomized BIT, TextHEB NVARCHAR(MAX), TextENG NVARCHAR(MAX));
DROP TABLE IF EXISTS #G;
CREATE TABLE #G (CalibrationRemarkId INT, OrderDetailsItemId INT, Scope NVARCHAR(10),
                 CalibrationCycleStartDate DATETIME2(0), DisplayOrder INT, PredefinedRemarkId INT,
                 ValuesJson NVARCHAR(MAX), IsCustomized BIT, IsManual BIT, TextHEB NVARCHAR(MAX),
                 TextENG NVARCHAR(MAX), TemplateHEB NVARCHAR(1000), TemplateENG NVARCHAR(1000),
                 IsLocked BIT, UpdatedDate DATETIME2(0), CreatedDate DATETIME2(0));
DROP TABLE IF EXISTS #L;
CREATE TABLE #L (OrderDetailsItemId INT, IsLocked BIT, RemarksLockedDate DATETIME2(0), Outcome NVARCHAR(10));
DROP TABLE IF EXISTS #P;
CREATE TABLE #P (PredefinedRemarkId INT, SecondaryCategoryId INT, Scope NVARCHAR(10), DisplayOrder INT,
                 TextHEB NVARCHAR(1000), TextENG NVARCHAR(1000), DefaultValues NVARCHAR(1000),
                 PlaceholderCount INT, ExampleHEB NVARCHAR(MAX), ExampleENG NVARCHAR(MAX));

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);
DECLARE @Cat INT = (SELECT MIN(ID) FROM dbo.SecondaryCategories WHERE IsDeleted = 0);

/* a line that is unique, live, and has a live cycle */
DECLARE @Item INT, @Cycle DATETIME2(0);
SELECT TOP (1) @Item = c.OrderDetailsItemId, @Cycle = c.CalibrationCycleStartDate
FROM dbo.CalibrationCycles AS c
WHERE c.IsDeleted = 0
  AND (SELECT COUNT(*) FROM dbo.OrderDetailsItems AS i
       WHERE i.OrderDetailsItemId = c.OrderDetailsItemId AND i.IsDeleted = 0) = 1
  AND EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS i
              WHERE i.OrderDetailsItemId = c.OrderDetailsItemId AND i.RemarksLockedDate IS NULL)
ORDER BY c.OrderDetailsItemId DESC;

DECLARE @R1 INT, @R2 INT, @RCycle INT, @ROld INT, @Err NVARCHAR(400), @N INT, @T NVARCHAR(MAX);


/* =============================================================================================
   Section 1 - the render function
   ============================================================================================= */
INSERT @Out SELECT N'1 render', N'two values, both languages', N'Sensor 7 at 30 cm',
       dbo.fnRenderRemarkTemplate(N'Sensor {1} at {2} cm', N'["7","30"]'),
       CASE WHEN dbo.fnRenderRemarkTemplate(N'Sensor {1} at {2} cm', N'["7","30"]') = N'Sensor 7 at 30 cm'
             AND dbo.fnRenderRemarkTemplate(N'רגש {1} במרחק {2} ס"מ', N'["7","30"]') = N'רגש 7 במרחק 30 ס"מ'
            THEN N'PASS' ELSE N'FAIL' END;

INSERT @Out SELECT N'1 render', N'values in the other order in Hebrew', N'{2} before {1} still right',
       dbo.fnRenderRemarkTemplate(N'B={2}, A={1}', N'["a","b"]'),
       CASE WHEN dbo.fnRenderRemarkTemplate(N'B={2}, A={1}', N'["a","b"]') = N'B=b, A=a' THEN N'PASS' ELSE N'FAIL' END;

INSERT @Out SELECT N'1 render', N'{1} is not replaced inside {10}', N'x1 y{10}... untouched',
       dbo.fnRenderRemarkTemplate(N'x{1} y{10}', N'["1"]'),
       CASE WHEN dbo.fnRenderRemarkTemplate(N'x{1} y{10}', N'["1"]') = N'x1 y{10}' THEN N'PASS' ELSE N'FAIL' END;

INSERT @Out SELECT N'1 render', N'NULL values leave the template', N'OFFSET = {1}',
       dbo.fnRenderRemarkTemplate(N'OFFSET = {1}', NULL),
       CASE WHEN dbo.fnRenderRemarkTemplate(N'OFFSET = {1}', NULL) = N'OFFSET = {1}' THEN N'PASS' ELSE N'FAIL' END;


/* =============================================================================================
   Section 2 - picking, saving, reading back, saving again
   ============================================================================================= */
IF @Item IS NULL
    INSERT @Out VALUES (N'2 save', N'no line with a live cycle in this database', N'-', N'-', N'SKIPPED');
ELSE
BEGIN
    BEGIN TRANSACTION;

    INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
    VALUES (@Cat, N'Report', N'רגש {1} במרחק {2} ס"מ', N'Sensor {1} at {2} cm', N'["","30"]', 1);
    SET @R1 = SCOPE_IDENTITY();
    INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
    VALUES (@Cat, N'Report', N'בוצע כיוון.', N'Adjustment performed.', NULL, 2);
    SET @R2 = SCOPE_IDENTITY();
    INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder, IsActive)
    VALUES (@Cat, N'Report', N'הערה ישנה', N'Old remark', NULL, 3, 0);
    SET @ROld = SCOPE_IDENTITY();
    INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
    VALUES (@Cat, N'Cycle', N'נבדק עם מטען.', N'Tested under loaded conditions.', NULL, 1);
    SET @RCycle = SCOPE_IDENTITY();

    /* the picker */
    INSERT #P EXEC dbo.GetPredefinedRemarks @SecondaryCategoryId = @Cat, @Scope = N'Report';
    INSERT @Out SELECT N'2 picker', N'active Report rows only, defaults shown filled',
           N'R1 then R2, no inactive, no Cycle; 2 placeholders',
           CONCAT(COUNT(*), N' rows; ', MAX(CASE WHEN PredefinedRemarkId = @R1 THEN ExampleENG END)),
           CASE WHEN EXISTS (SELECT 1 FROM #P WHERE PredefinedRemarkId = @R1 AND PlaceholderCount = 2
                                                AND ExampleENG = N'Sensor  at 30 cm')
                 AND EXISTS (SELECT 1 FROM #P WHERE PredefinedRemarkId = @R2)
                 AND NOT EXISTS (SELECT 1 FROM #P WHERE PredefinedRemarkId IN (@ROld, @RCycle))
                 AND (SELECT MIN(DisplayOrder) FROM #P WHERE PredefinedRemarkId IN (@R1, @R2))
                     = (SELECT DisplayOrder FROM #P WHERE PredefinedRemarkId = @R1)
                THEN N'PASS' ELSE N'FAIL' END
    FROM #P;

    SET @T = CONCAT(N'[{"PredefinedRemarkId":', @R1, N',"Values":["7"]},',
                    N'{"Text":"הערה חופשית - free text"},',
                    N'{"PredefinedRemarkId":', @R2, N',"TextHEB":"בוצע כיוון לבקר.","TextENG":"Controller adjusted."},',
                    N'{"PredefinedRemarkId":', @R2, N',"TextHEB":"כיוון בלי תרגום"}]');

    /* a dry run renders and writes nothing */
    SELECT @N = COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, @T, 0;
    INSERT @Out SELECT N'2 save', N'dry run: 4 WouldSave, nothing written', N'4 WouldSave, 0 new rows',
           CONCAT(COUNT(*), N' ', MIN(Outcome), N', ',
                  (SELECT COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item) - @N, N' new rows'),
           CASE WHEN COUNT(*) = 4 AND MIN(Outcome) = N'WouldSave' AND MAX(Outcome) = N'WouldSave'
                 AND (SELECT COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item) = @N
                THEN N'PASS' ELSE N'FAIL' END
    FROM #S;

    INSERT @Out SELECT N'2 save', N'list remark: sent value + default, same in both languages',
           N'Sensor 7 at 30 cm / רגש 7 במרחק 30 ס"מ / ["7","30"]',
           CONCAT(TextENG, N' / ', TextHEB, N' / ', ValuesJson),
           CASE WHEN TextENG = N'Sensor 7 at 30 cm' AND TextHEB = N'רגש 7 במרחק 30 ס"מ'
                 AND ValuesJson = N'["7","30"]' AND IsCustomized = 0 THEN N'PASS' ELSE N'FAIL' END
    FROM #S WHERE DisplayOrder = 1;

    INSERT @Out SELECT N'2 save', N'typed remark: printed as typed in both languages',
           N'same text both, no list id', CONCAT(TextENG, N' | ', ISNULL(CAST(PredefinedRemarkId AS NVARCHAR(10)), N'NULL')),
           CASE WHEN TextHEB = N'הערה חופשית - free text' AND TextENG = TextHEB AND PredefinedRemarkId IS NULL
                THEN N'PASS' ELSE N'FAIL' END
    FROM #S WHERE DisplayOrder = 2;

    INSERT @Out SELECT N'2 save', N'customized: own texts kept; English may be missing',
           N'Controller adjusted. / NULL, both IsCustomized',
           CONCAT((SELECT TextENG FROM #S WHERE DisplayOrder = 3), N' / ',
                  ISNULL((SELECT TextENG FROM #S WHERE DisplayOrder = 4), N'NULL')),
           CASE WHEN (SELECT TextENG FROM #S WHERE DisplayOrder = 3 AND IsCustomized = 1) = N'Controller adjusted.'
                 AND EXISTS (SELECT 1 FROM #S WHERE DisplayOrder = 4 AND IsCustomized = 1 AND TextENG IS NULL
                                                AND TextHEB = N'כיוון בלי תרגום')
                THEN N'PASS' ELSE N'FAIL' END;

    /* apply, read back */
    DELETE #S;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, @T, 1;
    INSERT #G EXEC dbo.GetCalibrationRemarks @Item;
    INSERT @Out SELECT N'2 save', N'apply, then read back in print order', N'4 Saved; 4 rows read, 1..4, unlocked',
           CONCAT((SELECT COUNT(*) FROM #S WHERE Outcome = N'Saved'), N' Saved; ', COUNT(*), N' rows read'),
           CASE WHEN (SELECT COUNT(*) FROM #S WHERE Outcome = N'Saved') = 4
                 AND COUNT(*) = 4 AND MIN(DisplayOrder) = 1 AND MAX(DisplayOrder) = 4
                 AND MAX(CAST(IsLocked AS INT)) = 0
                 AND MAX(CASE WHEN DisplayOrder = 1 THEN TemplateENG END) = N'Sensor {1} at {2} cm'
                 AND MAX(CASE WHEN DisplayOrder = 2 THEN CAST(IsManual AS INT) END) = 1
                THEN N'PASS' ELSE N'FAIL' END
    FROM #G WHERE Scope = N'Report';

    /* the same set again writes nothing */
    SELECT @N = COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item;
    DELETE #S;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, @T, 1;
    INSERT @Out SELECT N'2 save', N'saving the same set again', N'NoChange, 0 new rows',
           CONCAT(MIN(Outcome), N', ', (SELECT COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item) - @N, N' new rows'),
           CASE WHEN MIN(Outcome) = N'NoChange' AND MAX(Outcome) = N'NoChange'
                 AND (SELECT COUNT(*) FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item) = @N
                THEN N'PASS' ELSE N'FAIL' END
    FROM #S;

    /* a changed set replaces the old one; the old rows are kept, soft-deleted */
    DELETE #S;
    SET @T = CONCAT(N'[{"PredefinedRemarkId":', @R2, N'}]');
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, @T, 1;
    INSERT @Out SELECT N'2 save', N'a new set replaces the old; history kept', N'1 live, 4 soft-deleted',
           CONCAT(SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END), N' live, ',
                  SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END), N' soft-deleted'),
           CASE WHEN SUM(CASE WHEN IsDeleted = 0 THEN 1 ELSE 0 END) = 1
                 AND SUM(CASE WHEN IsDeleted = 1 THEN 1 ELSE 0 END) = 4 THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item AND Scope = N'Report';

    /* a retired list row on the section already: saving it again is allowed */
    UPDATE dbo.PredefinedRemarks SET IsActive = 0 WHERE PredefinedRemarkId = @R2;
    DELETE #S;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, @T, 1;
    INSERT @Out SELECT N'2 save', N'retired list row already on the report re-saves', N'NoChange',
           MIN(Outcome), CASE WHEN MIN(Outcome) = N'NoChange' THEN N'PASS' ELSE N'FAIL' END
    FROM #S;

    /* a cycle's remarks: their own section, gone from the read when the cycle is deleted */
    DELETE #S;
    SET @T = CONCAT(N'[{"PredefinedRemarkId":', @RCycle, N'},{"Text":"מחזור"}]');
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Cycle', @Cycle, @T, 1;
    DELETE #G;
    INSERT #G EXEC dbo.GetCalibrationRemarks @Item;
    SELECT @N = COUNT(*) FROM #G WHERE Scope = N'Cycle' AND CalibrationCycleStartDate = @Cycle;
    UPDATE dbo.CalibrationCycles SET IsDeleted = 1 WHERE OrderDetailsItemId = @Item AND CalibrationCycleStartDate = @Cycle;
    DELETE #G;
    INSERT #G EXEC dbo.GetCalibrationRemarks @Item;
    INSERT @Out SELECT N'2 cycle', N'cycle remarks saved apart; hidden once the cycle is deleted',
           N'2 cycle rows, report row untouched, then 0',
           CONCAT(@N, N' cycle rows, then ', (SELECT COUNT(*) FROM #G WHERE Scope = N'Cycle'),
                  N'; report rows ', (SELECT COUNT(*) FROM #G WHERE Scope = N'Report')),
           CASE WHEN @N = 2 AND (SELECT COUNT(*) FROM #G WHERE Scope = N'Cycle') = 0
                 AND (SELECT COUNT(*) FROM #G WHERE Scope = N'Report') = 1 THEN N'PASS' ELSE N'FAIL' END;

    /* clearing a section */
    DELETE #S;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, N'[]', 1;
    INSERT @Out SELECT N'2 save', N'[] clears the section', N'0 live report rows',
           CAST(COUNT(*) AS NVARCHAR(10)), CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.CalibrationRemarks WHERE OrderDetailsItemId = @Item AND Scope = N'Report' AND IsDeleted = 0;

    ROLLBACK TRANSACTION;
END;


/* =============================================================================================
   Section 3 - the signature lock
   ============================================================================================= */
IF @Item IS NOT NULL
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT #L EXEC dbo.SetCalibrationRemarksLock @Email, @Item, 1;
        INSERT #L EXEC dbo.SetCalibrationRemarksLock @Email, @Item, 1;
        INSERT #L (OrderDetailsItemId, IsLocked, RemarksLockedDate)  -- no Outcome: NULL
            EXEC dbo.GetCalibrationRemarksLock @Item;
        SET @T = (SELECT STRING_AGG(ISNULL(Outcome, N'read:' + CAST(IsLocked AS NVARCHAR(1))), N',') FROM #L);
        SET @Err = NULL;
        BEGIN TRY
            EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, N'[{"Text":"x"}]', 1;
        END TRY
        BEGIN CATCH
            SET @Err = ERROR_MESSAGE();
        END CATCH;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Err = CONCAT(N'setup failed: ', ERROR_MESSAGE());
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END CATCH;

    INSERT @Out SELECT N'3 lock', N'lock, lock again, read, then a save is refused',
           N'Locked,NoChange,read:1 + refused', CONCAT(@T, N' + ', ISNULL(LEFT(@Err, 40), N'accepted')),
           CASE WHEN @T = N'Locked,NoChange,read:1' AND @Err LIKE N'%signed%' THEN N'PASS' ELSE N'FAIL' END;

    DELETE #L;
    BEGIN TRANSACTION;
    INSERT #L EXEC dbo.SetCalibrationRemarksLock @Email, @Item, 1;
    INSERT #L EXEC dbo.SetCalibrationRemarksLock @Email, @Item, 0;
    DELETE #S;
    INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @Item, N'Report', NULL, N'[{"Text":"x"}]', 1;
    INSERT @Out SELECT N'3 lock', N'unlocking (report reopened) allows saving again', N'Locked,Unlocked + Saved',
           CONCAT((SELECT STRING_AGG(Outcome, N',') FROM #L), N' + ', MIN(Outcome)),
           CASE WHEN (SELECT STRING_AGG(Outcome, N',') FROM #L) = N'Locked,Unlocked' AND MIN(Outcome) = N'Saved'
                THEN N'PASS' ELSE N'FAIL' END
    FROM #S;
    ROLLBACK TRANSACTION;
END;


/* =============================================================================================
   Section 4 - input the procedure must refuse
   ============================================================================================= */
IF @Item IS NOT NULL
BEGIN
    DECLARE @Case TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Scope NVARCHAR(10), UseCycle BIT, J NVARCHAR(MAX));
    INSERT @Case (Test, Scope, UseCycle, J) VALUES
        (N'not a JSON array',                            N'Report', 0, N'{"Text":"x"}'),
        (N'element is not an object',                    N'Report', 0, N'["x"]'),
        (N'empty typed text',                            N'Report', 0, N'[{"Text":"  "}]'),
        (N'list id and Text together',                   N'Report', 0, N'[{"PredefinedRemarkId":#R1,"Text":"x"}]'),
        (N'unknown list id',                             N'Report', 0, N'[{"PredefinedRemarkId":-1}]'),
        (N'list row of the other scope',                 N'Report', 0, N'[{"PredefinedRemarkId":#RC}]'),
        (N'retired list row, new on this report',        N'Report', 0, N'[{"PredefinedRemarkId":#RO}]'),
        (N'placeholder left empty (no value, "" default)', N'Report', 0, N'[{"PredefinedRemarkId":#R1}]'),
        (N'more values than placeholders',               N'Report', 0, N'[{"PredefinedRemarkId":#R1,"Values":["1","2","3"]}]'),
        (N'Values and TextHEB together',                 N'Report', 0, N'[{"PredefinedRemarkId":#R1,"Values":["1"],"TextHEB":"x"}]'),
        (N'English without Hebrew',                      N'Report', 0, N'[{"PredefinedRemarkId":#R1,"TextENG":"x"}]'),
        (N'report remark given a cycle',                 N'Report', 1, N'[]'),
        (N'cycle remark without a cycle',                N'Cycle',  0, N'[]'),
        (N'cycle that does not exist',                   N'Cycle',  1, N'[]'),
        (N'unknown scope',                               N'Other',  0, N'[]');

    DECLARE @Seq INT = 1, @Max INT = (SELECT MAX(Seq) FROM @Case), @Sc NVARCHAR(10), @Uc BIT, @J NVARCHAR(MAX),
            @CycleArg DATETIME2(0);
    WHILE @Seq <= @Max
    BEGIN
        SELECT @T = Test, @Sc = Scope, @Uc = UseCycle, @J = J FROM @Case WHERE Seq = @Seq;
        SET @Err = NULL;
        BEGIN TRY
            BEGIN TRANSACTION;
            INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
            VALUES (@Cat, N'Report', N'רגש {1} במרחק {2} ס"מ', N'Sensor {1} at {2} cm', N'["","30"]', 1);
            SET @R1 = SCOPE_IDENTITY();
            INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
            VALUES (@Cat, N'Cycle', N'נבדק עם מטען.', N'Tested under loaded conditions.', NULL, 1);
            SET @RCycle = SCOPE_IDENTITY();
            INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder, IsActive)
            VALUES (@Cat, N'Report', N'הערה ישנה', N'Old remark', NULL, 3, 0);
            SET @ROld = SCOPE_IDENTITY();

            SET @J = REPLACE(REPLACE(REPLACE(@J, N'#R1', @R1), N'#RC', @RCycle), N'#RO', @ROld);
            SET @CycleArg = CASE WHEN @Uc = 1 AND @Sc = N'Cycle' THEN DATEADD(YEAR, -50, @Cycle)
                                 WHEN @Uc = 1 THEN @Cycle END;
            EXEC dbo.SaveCalibrationRemarks @Email, @Item, @Sc, @CycleArg, @J, 0;
        END TRY
        BEGIN CATCH
            SET @Err = ERROR_MESSAGE();
        END CATCH;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        INSERT @Out SELECT N'4 refuse', @T, N'an error', ISNULL(LEFT(@Err, 60), N'accepted'),
               CASE WHEN @Err IS NOT NULL THEN N'PASS' ELSE N'FAIL' END;
        SET @Seq += 1;
    END;
END;


/* ============================================================================================= */
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

SELECT @Fail = COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%';
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out),
       Item    = @Item, Cycle = @Cycle;
