/*
    Tests for dbo.GetPreviousCalibrationRemarks                                            MBA-831
    ---------------------------------------------------------------------------------------------
    Run against a database where dbo.GetPreviousCalibrationRemarks and the MBA-848 remarks objects
    are deployed. Anything other than 'PASS' in Result is a failure. Everything happens inside one
    transaction that is rolled back, so the file leaves the database as it found it.

    Three live order lines whose id is theirs alone are given one test serial number: A and B are
    two earlier calibrations of the "same sensor", C is the new one. Remarks are saved on A and then
    on B through dbo.SaveCalibrationRemarks, exactly as the report screen saves them.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;   -- OrderDetailsItems has a filtered index; sqlcmd starts with this OFF
SET ANSI_NULLS ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Expected NVARCHAR(120), Actual NVARCHAR(120),
                    Result NVARCHAR(10));

DROP TABLE IF EXISTS #S;
CREATE TABLE #S (Outcome NVARCHAR(10), DisplayOrder INT, PredefinedRemarkId INT, ValuesJson NVARCHAR(MAX),
                 IsCustomized BIT, TextHEB NVARCHAR(MAX), TextENG NVARCHAR(MAX));
DROP TABLE IF EXISTS #P;
CREATE TABLE #P (CalibrationRemarkId INT, OrderDetailsItemId INT, Scope NVARCHAR(10),
                 CalibrationCycleStartDate DATETIME2(0), DisplayOrder INT, PredefinedRemarkId INT,
                 ValuesJson NVARCHAR(MAX), IsCustomized BIT, IsManual BIT, TextHEB NVARCHAR(MAX),
                 TextENG NVARCHAR(MAX), TemplateHEB NVARCHAR(1000), TemplateENG NVARCHAR(1000),
                 IsLocked BIT, UpdatedDate DATETIME2(0), CreatedDate DATETIME2(0),
                 PredefinedIsActive BIT, SourceOrderDetailsItemId INT, SourceReportNumber NVARCHAR(200),
                 SourceCalibrationDate DATETIME2(0));

DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);
DECLARE @Serial NVARCHAR(100) = CONCAT(N'MBA831-TEST-', LEFT(CONVERT(NVARCHAR(36), NEWID()), 8));

/* three live, unlocked lines whose OrderDetailsItemId sits on one order line only */
DECLARE @Lines TABLE (Rn INT IDENTITY, Id INT);
INSERT @Lines (Id)
SELECT TOP (3) i.OrderDetailsItemId
FROM dbo.OrderDetailsItems AS i
WHERE i.IsDeleted = 0 AND ISNULL(i.IsCancelled, 0) = 0 AND i.RemarksLockedDate IS NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.CalibrationRemarks AS r WHERE r.OrderDetailsItemId = i.OrderDetailsItemId)
GROUP BY i.OrderDetailsItemId
HAVING COUNT(*) = 1
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @A INT = (SELECT Id FROM @Lines WHERE Rn = 1),
        @B INT = (SELECT Id FROM @Lines WHERE Rn = 2),
        @C INT = (SELECT Id FROM @Lines WHERE Rn = 3);

BEGIN TRANSACTION;

UPDATE dbo.OrderDetailsItems SET SerialNumber = @Serial WHERE OrderDetailsItemId IN (@A, @B, @C);
UPDATE dbo.OrderDetailsItems SET MbaReportNumber = N'TEST-B', ActualCalibrationDate = '2026-03-04'
WHERE OrderDetailsItemId = @B;

/* a list row in A's sub-domain, so a list remark can be saved on A */
DECLARE @Cat INT = COALESCE((SELECT od.SecondaryCategoryId FROM dbo.OrderDetailsItems AS i
                             JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
                             WHERE i.OrderDetailsItemId = @A),
                            (SELECT MIN(ID) FROM dbo.SecondaryCategories WHERE IsDeleted = 0));
INSERT dbo.PredefinedRemarks (SecondaryCategoryId, Scope, TextHEB, TextENG, DefaultValues, DisplayOrder)
VALUES (@Cat, N'Report', N'החשל הנמדד הנו {1}', N'The measured hysteresis is {1}', N'[""]', 9990);
DECLARE @Pre INT = SCOPE_IDENTITY();

/* nothing on file yet: no rows, no error */
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'no earlier calibration with remarks: no rows', N'0', CONCAT(COUNT(*), N''),
       CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #P;

/* remarks on A: a list remark with a value and a typed one */
DECLARE @T NVARCHAR(MAX) = CONCAT(N'[{"PredefinedRemarkId":', @Pre, N',"Values":["0.005 °C"]},',
                                  N'{"Text":"R0=+2.013092E+02, AL=+3.846645E-03"}]');
DELETE #S; INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @A, N'Report', NULL, @T, 1;

DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
DECLARE @First NVARCHAR(10) = (SELECT TOP (1) CASE WHEN IsManual = 1 THEN N'typed' ELSE N'list' END FROM #P ORDER BY DisplayOrder),
        @Last  NVARCHAR(10) = (SELECT TOP (1) CASE WHEN IsManual = 1 THEN N'typed' ELSE N'list' END FROM #P ORDER BY DisplayOrder DESC);
INSERT @Out SELECT N'the same serial''s earlier remarks are offered, in print order',
       CONCAT(N'2 rows from ', @A, N': list, then typed'),
       CONCAT(COUNT(*), N' rows from ', MIN(SourceOrderDetailsItemId), N': ', @First, N', then ', @Last),
       CASE WHEN COUNT(*) = 2 AND MIN(SourceOrderDetailsItemId) = @A AND MAX(SourceOrderDetailsItemId) = @A
             AND @First = N'list' AND @Last = N'typed'
            THEN N'PASS' ELSE N'FAIL' END FROM #P;

INSERT @Out SELECT N'the list remark keeps its id, values, rendered text and template',
       N'0.005 °C | החשל הנמדד הנו 0.005 °C | active',
       CONCAT(JSON_VALUE(ValuesJson, '$[0]'), N' | ', TextHEB, N' | ', CASE WHEN PredefinedIsActive = 1 THEN N'active' ELSE N'retired' END),
       CASE WHEN PredefinedRemarkId = @Pre AND JSON_VALUE(ValuesJson, '$[0]') = N'0.005 °C'
             AND TextHEB = N'החשל הנמדד הנו 0.005 °C' AND TemplateHEB = N'החשל הנמדד הנו {1}'
             AND PredefinedIsActive = 1 THEN N'PASS' ELSE N'FAIL' END
FROM #P WHERE IsManual = 0;

INSERT @Out SELECT N'the typed remark comes back as typed', N'R0=+2.013092E+02, AL=+3.846645E-03', TextHEB,
       CASE WHEN TextHEB = N'R0=+2.013092E+02, AL=+3.846645E-03' AND PredefinedRemarkId IS NULL THEN N'PASS' ELSE N'FAIL' END
FROM #P WHERE IsManual = 1;

/* a later calibration, B, with its own remarks: B is now the one offered, with its report and date */
SET @T = N'[{"Text":"after adjustment"}]';
WAITFOR DELAY '00:00:01';
DELETE #S; INSERT #S EXEC dbo.SaveCalibrationRemarks @Email, @B, N'Report', NULL, @T, 1;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'the last calibration wins, with its report number and date',
       CONCAT(@B, N' TEST-B 2026-03-04 after adjustment'),
       CONCAT(MIN(SourceOrderDetailsItemId), N' ', MIN(SourceReportNumber), N' ',
              CONVERT(NVARCHAR(10), MIN(SourceCalibrationDate), 23), N' ', MIN(TextHEB)),
       CASE WHEN COUNT(*) = 1 AND MIN(SourceOrderDetailsItemId) = @B AND MIN(SourceReportNumber) = N'TEST-B'
             AND CONVERT(DATE, MIN(SourceCalibrationDate)) = '2026-03-04' AND MIN(TextHEB) = N'after adjustment'
            THEN N'PASS' ELSE N'FAIL' END FROM #P;

/* the line's own remarks are never offered back to it */
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @B;
INSERT @Out SELECT N'a line is never offered its own remarks', CAST(@A AS NVARCHAR(12)),CONCAT(MIN(SourceOrderDetailsItemId), N''),
       CASE WHEN COUNT(*) > 0 AND MIN(SourceOrderDetailsItemId) = @A AND MAX(SourceOrderDetailsItemId) = @A
            THEN N'PASS' ELSE N'FAIL' END FROM #P;

/* a cancelled calibration is skipped: back to A */
UPDATE dbo.OrderDetailsItems SET IsCancelled = 1 WHERE OrderDetailsItemId = @B;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'a cancelled calibration is skipped', CAST(@A AS NVARCHAR(12)),CONCAT(MIN(SourceOrderDetailsItemId), N''),
       CASE WHEN MIN(SourceOrderDetailsItemId) = @A AND MAX(SourceOrderDetailsItemId) = @A THEN N'PASS' ELSE N'FAIL' END FROM #P;

/* a retired list row is reported, so the app saves the remark as text */
UPDATE dbo.PredefinedRemarks SET IsActive = 0 WHERE PredefinedRemarkId = @Pre;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'a retired list row is flagged as no longer active', N'retired',
       CASE WHEN MIN(CAST(PredefinedIsActive AS INT)) = 0 THEN N'retired' ELSE N'active' END,
       CASE WHEN MIN(CAST(PredefinedIsActive AS INT)) = 0 THEN N'PASS' ELSE N'FAIL' END
FROM #P WHERE IsManual = 0;

/* a different serial, and no serial at all, find nothing */
UPDATE dbo.OrderDetailsItems SET SerialNumber = CONCAT(@Serial, N'-other') WHERE OrderDetailsItemId = @C;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'another serial number finds nothing', N'0', CONCAT(COUNT(*), N''),
       CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #P;

UPDATE dbo.OrderDetailsItems SET SerialNumber = N'  ' WHERE OrderDetailsItemId = @C;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'a line with no serial number finds nothing', N'0', CONCAT(COUNT(*), N''),
       CASE WHEN COUNT(*) = 0 THEN N'PASS' ELSE N'FAIL' END FROM #P;

/* surrounding spaces do not make a different serial */
UPDATE dbo.OrderDetailsItems SET SerialNumber = CONCAT(N' ', @Serial, N' ') WHERE OrderDetailsItemId = @C;
DELETE #P; INSERT #P EXEC dbo.GetPreviousCalibrationRemarks @C;
INSERT @Out SELECT N'spaces around the serial number are ignored', CAST(@A AS NVARCHAR(12)),CONCAT(MIN(SourceOrderDetailsItemId), N''),
       CASE WHEN MIN(SourceOrderDetailsItemId) = @A THEN N'PASS' ELSE N'FAIL' END FROM #P;

ROLLBACK TRANSACTION;

SELECT Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
SELECT Summary = CASE WHEN EXISTS (SELECT 1 FROM @Out WHERE Result <> N'PASS')
                      THEN CONCAT((SELECT COUNT(*) FROM @Out WHERE Result <> N'PASS'), N' FAILING')
                      ELSE N'ALL PASS' END,
       Cases = (SELECT COUNT(*) FROM @Out), LineA = @A, LineB = @B, LineC = @C;
