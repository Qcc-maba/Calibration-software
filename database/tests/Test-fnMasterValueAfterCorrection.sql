/*
    Tests for dbo.fnMasterValueAfterCorrection                                         MBA-811
    ---------------------------------------------------------------------------------------------
    Run against STAGE. Anything other than 'PASS' in Result is a failure.

    These tests replaced an earlier set that asserted the wrong metrology. That set computed its
    own expected values by interpolating between (Value1, Deviation) points and clamping past the
    ends - the same model the function used - so the two agreed with each other and the file passed
    while the answers were wrong. A test that derives its expectation the same way as the code
    cannot find that class of fault. Nofar found it by hand on 31-98 instead.

    So the expectations here come from three independent places, in descending order of value:

      section 1   a PROPERTY that must hold over every certificate row in the database, checked
                  against the stored Deviation column, which the function does not read
      section 2   Nofar's measured numbers, as literals. External truth, not derived from anything
      section 3   the certificate arithmetic worked by hand for one master, printed in the comment

    Section 1 is the one that matters. It calls the function 30,000-odd times on live data and
    compares each answer with a value produced by whoever generated the certificates years ago.
    Nothing in this file and nothing in the function influences it.
*/
SET NOCOUNT ON;

DECLARE @Fail INT = 0;
DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(12), Test NVARCHAR(70),
                    Expected NVARCHAR(40), Actual NVARCHAR(40), Result NVARCHAR(60));


/* =============================================================================================
   Section 1 - the property, over every master in the database

   Deviation is the row's own Equation evaluated at Value1. The function parses Equation and never
   looks at Deviation, so calling it AT Value1 must reproduce the stored column. If the parser
   mishandles any of the nine equation formats, or the range matching picks the neighbouring row,
   this fails and names the device.

   Restricted to masters whose latest version carries a single quantity, because for those the
   function's own choice of quantity is not in question - that is section 3's job, not this one.
   ============================================================================================= */
WITH Ranked AS
(
    SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value1, c.Deviation,
           Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    WHERE ISNULL(c.IsDeleted, 0) = 0 AND c.Equation IS NOT NULL AND c.Deviation IS NOT NULL
),
Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
Single AS (SELECT MeasurementDevicesId FROM Newest
           GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1),
Checked AS
(
    SELECT n.MeasurementDevicesId, n.Value1, Stored = n.Deviation, Computed = f.Deviation
    FROM Newest AS n
    JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId
    CROSS APPLY dbo.fnMasterValueAfterCorrection(n.MeasurementDevicesId, n.Value1, n.MeasurementId) AS f
)
INSERT @Out (Section, Test, Expected, Actual, Result)
SELECT N'1 property',
       N'every certificate row reproduces its stored Deviation at Value1',
       N'0 rows differ',
       CAST(SUM(CASE WHEN c.Computed IS NULL
                       OR ABS(c.Computed - c.Stored) > 0.0001 THEN 1 ELSE 0 END) AS NVARCHAR(40)) + N' of '
         + CAST(COUNT(*) AS NVARCHAR(20)) + N' rows',
       CASE WHEN SUM(CASE WHEN c.Computed IS NULL
                            OR ABS(c.Computed - c.Stored) > 0.0001 THEN 1 ELSE 0 END) = 0
            THEN N'PASS' ELSE N'FAIL' END
FROM Checked AS c;

/* name the first few offenders, so a failure above is actionable rather than a count */
WITH Ranked AS
(
    SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value1, c.Deviation, c.Equation,
           Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
    FROM dbo.MeasurementDevicesCorrections AS c
    WHERE ISNULL(c.IsDeleted, 0) = 0 AND c.Equation IS NOT NULL AND c.Deviation IS NOT NULL
),
Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
Single AS (SELECT MeasurementDevicesId FROM Newest
           GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1)
INSERT @Out (Section, Test, Expected, Actual, Result)
SELECT TOP (5) N'1 property',
       LEFT(N'offender: ' + md.MabaID + N'  ' + n.Equation, 70),
       CAST(n.Deviation AS NVARCHAR(40)),
       ISNULL(CAST(f.Deviation AS NVARCHAR(40)), N'(no row)'),
       N'FAIL - see the count above'
FROM Newest AS n
JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId
JOIN dbo.MeasurementDevices AS md ON md.ID = n.MeasurementDevicesId
CROSS APPLY dbo.fnMasterValueAfterCorrection(n.MeasurementDevicesId, n.Value1, n.MeasurementId) AS f
WHERE f.Deviation IS NULL OR ABS(f.Deviation - n.Deviation) > 0.0001;


/* =============================================================================================
   Section 2 - Nofar's numbers on 31-98, MBA-811 31/08

   Her certificate's last range is [150.072, 249.960] with x * (0.001101) - 0.745264.

     249.96   the certificate's own top point. The old half-open match Value1 <= x < Value2 put it
              outside every range and clamped it to 250.540. It is inside, and it is 250.430
     250.00   0.04 above the top - the reading she actually entered. 250.470
     251.00   further out. The equation continues; the old clamp's error grew, this one does not

   These are literals on purpose. Deriving them from the certificate rows here would be deriving
   them the same way the function does, which is exactly the mistake this file is replacing.
   ============================================================================================= */
DECLARE @D98 INT = (SELECT ID FROM dbo.MeasurementDevices WHERE MabaID = N'31-98');

IF @D98 IS NULL
    INSERT @Out (Section, Test, Expected, Actual, Result)
    VALUES (N'2 Nofar', N'master 31-98', N'present', N'missing', N'SKIP - 31-98 is not on this server');
ELSE
BEGIN
    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'2 Nofar', v.Name, CAST(v.Expect AS NVARCHAR(40)), CAST(f.Corrected AS NVARCHAR(40)),
           CASE WHEN f.Corrected IS NULL THEN N'FAIL - no value returned'
                WHEN ABS(f.Corrected - v.Expect) > 0.0005 THEN N'FAIL'
                ELSE N'PASS' END
    FROM (VALUES
            (N'the certificate top point, 249.96',      CAST(249.96 AS DECIMAL(18,6)), CAST(250.430 AS DECIMAL(18,6))),
            (N'0.04 above the top, 250 - Nofar''s case', CAST(250.00 AS DECIMAL(18,6)), CAST(250.470 AS DECIMAL(18,6))),
            (N'a full degree above the top, 251',        CAST(251.00 AS DECIMAL(18,6)), CAST(251.469 AS DECIMAL(18,6))),
            (N'the certificate bottom point, -80.506',   CAST(-80.506 AS DECIMAL(18,6)), CAST(-80.216 AS DECIMAL(18,6)))
         ) AS v(Name, Reading, Expect)
    CROSS APPLY dbo.fnMasterValueAfterCorrection(@D98, v.Reading, 4) AS f;

    /* the flags that go with those numbers. The top point is INSIDE the certificate - reporting it
       as an excursion is what sent 249.96 down the clamp path in the first place. */
    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'2 Nofar', v.Name, v.Expect,
           CAST(f.OutOfRange AS NVARCHAR(4)) + N'/' + CAST(f.Extrapolated AS NVARCHAR(4)),
           CASE WHEN CAST(f.OutOfRange AS NVARCHAR(4)) + N'/' + CAST(f.Extrapolated AS NVARCHAR(4)) = v.Expect
                THEN N'PASS' ELSE N'FAIL' END
    FROM (VALUES
            (N'249.96 is in range      (OutOfRange/Extrapolated)', CAST(249.96 AS DECIMAL(18,6)), N'0/0'),
            (N'250.00 is out of range  (OutOfRange/Extrapolated)', CAST(250.00 AS DECIMAL(18,6)), N'1/1'),
            (N'100.00 is in range      (OutOfRange/Extrapolated)', CAST(100.00 AS DECIMAL(18,6)), N'0/0'),
            (N'-81.00 is out of range  (OutOfRange/Extrapolated)', CAST(-81.00 AS DECIMAL(18,6)), N'1/1')
         ) AS v(Name, Reading, Expect)
    CROSS APPLY dbo.fnMasterValueAfterCorrection(@D98, v.Reading, 4) AS f;
END


/* =============================================================================================
   Section 3 - arithmetic worked by hand, and the behaviours that are not arithmetic

   31-98 range 5 is [50.076, 100.076] with x * (-0.006) + 0.310456.

        at 60      60 * -0.006 + 0.310456 = -0.049544     corrected 60.049544
        at 100     100 * -0.006 + 0.310456 = -0.289544    corrected 100.289544

   Both computed on paper from the printed certificate, not from the table.
   ============================================================================================= */
IF @D98 IS NOT NULL
BEGIN
    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'3 by hand', v.Name, CAST(v.Expect AS NVARCHAR(40)), CAST(f.CorrectedExact AS NVARCHAR(40)),
           CASE WHEN ABS(f.CorrectedExact - v.Expect) > 0.000002 THEN N'FAIL' ELSE N'PASS' END
    FROM (VALUES
            (N'inside range 5, reading 60',  CAST(60.0 AS DECIMAL(18,6)),  CAST(60.049544 AS DECIMAL(18,6))),
            (N'inside range 5, reading 100', CAST(100.0 AS DECIMAL(18,6)), CAST(100.289544 AS DECIMAL(18,6)))
         ) AS v(Name, Reading, Expect)
    CROSS APPLY dbo.fnMasterValueAfterCorrection(@D98, v.Reading, 4) AS f;

    /* The display rule, which is not metrology: as many decimals as the reading carried, floored
       at 3. Without the floor a reading of 23 came back as 23 and the calibrator saw no
       compensation at all. A DECIMAL parameter cannot distinguish 250 from 250.00, so the count
       is inferred from the digits that survive stripping trailing zeros. */
    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'3 display', N'decimals inferred from the reading ' + CAST(v.Reading AS NVARCHAR(20)),
           CAST(v.Expect AS NVARCHAR(4)), CAST(f.ReadingDecimals AS NVARCHAR(4)),
           CASE WHEN f.ReadingDecimals = v.Expect THEN N'PASS' ELSE N'FAIL' END
    FROM (VALUES (CAST(250.0   AS DECIMAL(18,6)), 0),
                 (CAST(250.5   AS DECIMAL(18,6)), 1),
                 (CAST(250.47  AS DECIMAL(18,6)), 2),
                 (CAST(250.125 AS DECIMAL(18,6)), 3)
         ) AS v(Reading, Expect)
    CROSS APPLY dbo.fnMasterValueAfterCorrection(@D98, v.Reading, 4) AS f;

    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'3 display', N'Corrected never shows fewer than 3 decimals',
           N'>= 3 decimals', CAST(f.Corrected AS NVARCHAR(40)),
           CASE WHEN f.Corrected = ROUND(f.Corrected, 0) AND f.CorrectedExact <> ROUND(f.CorrectedExact, 0)
                THEN N'FAIL - the correction was rounded away' ELSE N'PASS' END
    FROM dbo.fnMasterValueAfterCorrection(@D98, 23, 4) AS f;
END

/* Latest CorVersion only. 21-260 carries 33 of them; compensating against a mixture would blend
   certificates taken years apart. The function must use rows from the highest version alone, so
   its answer at that version's lowest point must match that version's own first Deviation. */
DECLARE @D260 INT = (SELECT TOP (1) c.MeasurementDevicesId
                     FROM dbo.MeasurementDevicesCorrections AS c
                     WHERE ISNULL(c.IsDeleted,0) = 0
                     GROUP BY c.MeasurementDevicesId
                     HAVING COUNT(DISTINCT c.CorVersion) > 1
                     ORDER BY COUNT(DISTINCT c.CorVersion) DESC);

IF @D260 IS NOT NULL
BEGIN
    DECLARE @Ver INT, @P DECIMAL(18,6), @PD DECIMAL(18,6), @Q INT;
    SELECT @Ver = MAX(CorVersion) FROM dbo.MeasurementDevicesCorrections
     WHERE MeasurementDevicesId = @D260 AND ISNULL(IsDeleted,0) = 0;
    SELECT TOP (1) @P = Value1, @PD = Deviation, @Q = MeasurementId
      FROM dbo.MeasurementDevicesCorrections
     WHERE MeasurementDevicesId = @D260 AND CorVersion = @Ver AND ISNULL(IsDeleted,0) = 0
     ORDER BY Value1 ASC;

    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'3 version', N'a master with many versions answers from the newest only',
           CAST(@PD AS NVARCHAR(40)), CAST(f.Deviation AS NVARCHAR(40)),
           CASE WHEN f.Deviation IS NULL THEN N'FAIL - no value returned'
                WHEN ABS(f.Deviation - @PD) > 0.0001 THEN N'FAIL - an older version leaked in'
                ELSE N'PASS' END
    FROM dbo.fnMasterValueAfterCorrection(@D260, @P, @Q) AS f;
END

/* A master with no certificate must come back empty-handed rather than with a plausible zero -
   1,220 of the 2,653 masters are still in that state and the screen shows them a dash. */
DECLARE @DNone INT = (SELECT TOP (1) md.ID FROM dbo.MeasurementDevices AS md
                      WHERE ISNULL(md.IsDeleted,0) = 0
                        AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c
                                        WHERE c.MeasurementDevicesId = md.ID AND ISNULL(c.IsDeleted,0) = 0));

IF @DNone IS NOT NULL
    INSERT @Out (Section, Test, Expected, Actual, Result)
    SELECT N'3 empty', N'a master with no certificate returns NULL, not 0',
           N'NULL', ISNULL(CAST(f.CorrectedExact AS NVARCHAR(40)), N'NULL'),
           CASE WHEN f.CorrectedExact IS NULL THEN N'PASS' ELSE N'FAIL' END
    FROM dbo.fnMasterValueAfterCorrection(@DNone, 100, NULL) AS f;

/* A NULL reading must not be treated as zero and silently compensated. */
INSERT @Out (Section, Test, Expected, Actual, Result)
SELECT N'3 empty', N'a NULL reading returns NULL, not the deviation at zero',
       N'NULL', ISNULL(CAST(f.CorrectedExact AS NVARCHAR(40)), N'NULL'),
       CASE WHEN f.CorrectedExact IS NULL THEN N'PASS' ELSE N'FAIL' END
FROM dbo.fnMasterValueAfterCorrection(@D98, NULL, 4) AS f;


/* ============================================================================================= */
SELECT Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;

SELECT @Fail = COUNT(*) FROM @Out WHERE Result LIKE N'FAIL%';
SELECT Summary = CASE WHEN @Fail = 0 THEN N'ALL PASS'
                      ELSE CAST(@Fail AS NVARCHAR(10)) + N' FAILING' END,
       Cases   = (SELECT COUNT(*) FROM @Out);
