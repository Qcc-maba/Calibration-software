/*
    Chamber reference documents: names, descriptions, English names, calculation case   (MBA-623)
    ---------------------------------------------------------------------------------------------
    Loads the table attached to MBA-623 ("mesmachei yichus.xlsx", from Nofar) into the chamber rows
    of dbo.SpecificationReference (SecondaryCategoryId = 2, "chambers"):

        Name            column A - the Hebrew name, shown in the picker and on a Hebrew report
        Description     column B - shown under the name in the picker
        NameEn          column C - shown on an English report
        CalculationCase what the summary computes: 1 = mean of averages, 2 = extreme values.
                        Until now the app guessed this by searching the name for known strings
                        (get-calculation-case.ts); the values below are what that guess returned
                        for each row, so no calculation changes.

    Names are NOT changed: the table spells four of them differently (AMS-2750, the Israeli
    standard 17665-1, ASTM D1238, ISO 1133, DKD-R 5-7), but renaming is a separate round after
    the app change is deployed. #Target.Name below is that future spelling, used only for
    matching; the UPDATE leaves Name as it is.

    ISO 11135 is not in the table and is soft-deleted (IsDeleted = 1), never removed: 7 cycles on
    STAGE point at it (2026-10-28) and keep showing its name, but it leaves the picker.

    Outside chambers only CalculationCase is set, and only on the two rows the old guess resolved
    (customer data, manufacturer tolerance -> 2), so those summaries keep working once the app
    stops reading names. Every other non-chamber row stays NULL, which the app reports exactly as
    it reported an unmatched name before.

    ADDRESSED BY NAME, NOT BY ID. Ids are identities and may differ between STAGE and PROD. Each
    target lists every spelling it is known by - the STAGE name, the new name (so a second run
    still finds it), and the keys of the app's old English map, which may be what PROD holds.
    The plan lists any live chamber row that matched nothing, and any target found in no row;
    @Apply = 1 refuses to run while either exists.

    Needs dbo.SpecificationReference.Description-NameEn-CalculationCase.sql first.
    Run with @Apply = 0: the last result set is the plan. @Apply = 1 writes in one transaction.
    A second run reports nothing to change. Hebrew literals: deploy with
    Invoke-CalibratorStageSqlFile.ps1 or sqlcmd -f 65001, never plain sqlcmd -i.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

DECLARE @Chambers INT = 2;

DROP TABLE IF EXISTS #Target;
CREATE TABLE #Target
(
    TargetKey       INT           NOT NULL PRIMARY KEY,
    Name            NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
    Description     NVARCHAR(200) COLLATE DATABASE_DEFAULT NULL,
    NameEn          NVARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
    CalculationCase TINYINT       NULL,
    IsDeleted       BIT           NOT NULL
);

INSERT INTO #Target (TargetKey, Name, Description, NameEn, CalculationCase, IsDeleted) VALUES
    ( 1, N'נתוני לקוח- ממוצע ממוצעים', N'ממוצע ממוצעים',            N'Customer Data - Mean of Averages', 1, 0),
    ( 2, N'נתוני לקוח',                N'נתוני לקוח לפי ערכי קצה',   N'Customer Data',                    2, 0),
    ( 3, N'סיבולת יצרן',               N'מפרט יצרן',                 N'Manufacturer Specification',       2, 0),
    ( 4, N'DIN 12880',                 N'ממוצע ממוצעים בתא מבוקר',   N'DIN 12880',                        1, 0),
    ( 5, N'AMS-2750',                  N'טיפולים תרמיים',            N'AMS-2750',                         2, 0),
    ( 6, N'תקן ישראלי 17665-1',        N'אוטוקלאב חום לח',           N'ISO 17665-1',                      2, 0),
    ( 7, N'ASTM D1238, ISO 1133',      N'MFI',                       N'ASTM D1238, ISO 1133',             2, 0),
    ( 8, N'נוהל 126 משרד הבריאות',     N'אחסון תרופות',              N'MOH Procedure 126',                2, 0),
    ( 9, N'DKD-R 5-7',                 N'תאי אקלים',                 N'DKD-R 5-7',                        2, 0),
    (10, N'ISO 11135',                 NULL,                         NULL,                                2, 1);

DROP TABLE IF EXISTS #Alias;
CREATE TABLE #Alias
(
    TargetKey INT           NOT NULL,
    MatchName NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY
);

INSERT INTO #Alias (TargetKey, MatchName)
SELECT TargetKey, Name FROM #Target;

INSERT INTO #Alias (TargetKey, MatchName) VALUES
    (1, N'נתוני לקוח- ממוצע'),
    (5, N'AMS 2750'),
    (6, N'ISO 17665'),
    (7, N'ISO 1133, ASTM D1238'),
    (7, N'MFI ASTM D1238, ISO 1133'),
    (8, N'נוהל 126 משרד הבריאות אחסון תרופות'),
    (9, N'DKD-R-5-7');

/* Chamber rows, live or soft-deleted, paired with their target by any known spelling. */
DROP TABLE IF EXISTS #Plan;
SELECT
    sr.ID,
    sr.SecondaryCategoryId,
    sr.Name             AS OldName,
    sr.Description      AS OldDescription,
    sr.NameEn           AS OldNameEn,
    sr.CalculationCase  AS OldCalculationCase,
    sr.IsDeleted        AS OldIsDeleted,
    t.TargetKey,
    t.Name,
    t.Description,
    t.NameEn,
    t.CalculationCase,
    t.IsDeleted
INTO #Plan
FROM dbo.SpecificationReference AS sr
LEFT JOIN #Alias  AS a ON a.MatchName = LTRIM(RTRIM(sr.Name))
LEFT JOIN #Target AS t ON t.TargetKey = a.TargetKey
WHERE sr.SecondaryCategoryId = @Chambers;

/* Outside chambers: only the calculation case of the two rows the old name guess resolved. */
INSERT INTO #Plan
SELECT
    sr.ID, sr.SecondaryCategoryId,
    sr.Name, sr.Description, sr.NameEn, sr.CalculationCase, sr.IsDeleted,
    0,
    sr.Name, sr.Description, sr.NameEn, 2, sr.IsDeleted
FROM dbo.SpecificationReference AS sr
WHERE ISNULL(sr.SecondaryCategoryId, 0) <> @Chambers
  AND LTRIM(RTRIM(sr.Name)) IN (N'נתוני לקוח', N'סיבולת יצרן');

DECLARE @Unmatched INT =
    (SELECT COUNT(*) FROM #Plan WHERE TargetKey IS NULL AND OldIsDeleted = 0);
DECLARE @Missing INT =
    (SELECT COUNT(*) FROM #Target AS t
     WHERE t.IsDeleted = 0 AND NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.TargetKey = t.TargetKey));

DECLARE @Changes INT =
    (SELECT COUNT(*) FROM #Plan
     WHERE TargetKey IS NOT NULL
       AND (   ISNULL(OldDescription, N'') <> ISNULL(Description, N'')
            OR ISNULL(OldNameEn, N'')      <> ISNULL(NameEn, N'')
            OR ISNULL(OldCalculationCase, 0) <> ISNULL(CalculationCase, 0)
            OR OldIsDeleted <> IsDeleted));

IF @Apply = 1
BEGIN
    IF @Unmatched > 0 OR @Missing > 0
        THROW 51000, 'A live chamber row matched no target, or a target matched no row - read the plan (@Apply = 0) and add the spelling to #Alias.', 1;

    BEGIN TRANSACTION;

    UPDATE sr
    SET    sr.Description     = p.Description,
           sr.NameEn          = p.NameEn,
           sr.CalculationCase = p.CalculationCase,
           sr.IsDeleted       = p.IsDeleted,
           sr.UpdatedDate     = SYSDATETIME()
    FROM   dbo.SpecificationReference AS sr
    JOIN   #Plan AS p ON p.ID = sr.ID
    WHERE  p.TargetKey IS NOT NULL
      AND (   ISNULL(p.OldDescription, N'') <> ISNULL(p.Description, N'')
           OR ISNULL(p.OldNameEn, N'')      <> ISNULL(p.NameEn, N'')
           OR ISNULL(p.OldCalculationCase, 0) <> ISNULL(p.CalculationCase, 0)
           OR p.OldIsDeleted <> p.IsDeleted);

    IF @@ROWCOUNT <> @Changes
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51000, 'Row count differs from the plan - rolled back.', 1;
    END;

    COMMIT TRANSACTION;
END;

/* The plan (after @Apply = 1: what was planned, now applied). */
SELECT
    CASE
        WHEN TargetKey IS NULL AND OldIsDeleted = 0 THEN 'UNMATCHED - add its spelling to #Alias'
        WHEN TargetKey IS NULL                      THEN 'unmatched, already deleted - left alone'
        WHEN ISNULL(OldDescription, N'') <> ISNULL(Description, N'')
          OR ISNULL(OldNameEn, N'')      <> ISNULL(NameEn, N'')
          OR ISNULL(OldCalculationCase, 0) <> ISNULL(CalculationCase, 0)
          OR OldIsDeleted <> IsDeleted              THEN CASE WHEN @Apply = 1 THEN 'changed' ELSE 'will change' END
        ELSE 'up to date'
    END AS Action,
    ID, SecondaryCategoryId,
    OldName AS Name, Description, NameEn,
    OldCalculationCase, CalculationCase,
    OldIsDeleted, IsDeleted
FROM #Plan
UNION ALL
SELECT 'MISSING - no row has this name', NULL, @Chambers, t.Name, t.Description, t.NameEn,
       NULL, t.CalculationCase, NULL, t.IsDeleted
FROM #Target AS t
WHERE t.IsDeleted = 0 AND NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.TargetKey = t.TargetKey)
ORDER BY SecondaryCategoryId, ID;
