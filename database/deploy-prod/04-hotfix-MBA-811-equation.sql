/*
    dbo.fnMasterValueAfterCorrection                                                   MBA-811
    ---------------------------------------------------------------------------------------------
    "מד אב אחרי קיזוז" - a master's reading with its certificate deviation applied.

    The certificate is a PIECEWISE-LINEAR FIT, not a list of points
    ---------------------------------------------------------------
    Each row of MeasurementDevicesCorrections is a range [Value1, Value2] carrying its own
    equation, e.g.  x * (0.001101) - 0.745264. Compensating a reading is: find the row whose
    range contains it, EVALUATE THAT ROW'S EQUATION, subtract the result.

    The first version of this function did not read Equation at all. It treated (Value1, Deviation)
    as a series of points and interpolated between them. That is a different model and it gave
    different answers - Nofar caught it on master 31-98 (MBA-811, 31/08): a reading of 250 came
    back as 250.580 when the certificate says 250.470.

    Deviation is not an independent column. It is the row's own equation evaluated at Value1:

        row 1 of 31-98    Value1 -80.506   x * (0.02226) + 1.502068   ->  -0.289996 = Deviation
        row 9 of 31-98    Value1 150.072   x * (0.001101) - 0.745264  ->  -0.580035 = Deviation

    Verified across all 30,548 live correction rows: every one reproduces its stored Deviation from
    its own Equation at Value1, worst case 6.7e-5, which is the rounding of the stored copy. So
    using Deviation as if it applied across the whole range - which is what the old clamp did -
    freezes the correction at the range's LEFT EDGE. Inside a range that is merely inaccurate;
    past the last range it is wrong by however far the reading has travelled.

    Two faults that produced Nofar's number, both fixed here
    -------------------------------------------------------
    1. The top of the certificate fell outside it. Ranges were matched Value1 <= x < Value2, so
       31-98's highest calibrated value, 249.96, matched no range at all and was treated as an
       excursion. Ranges are now closed at both ends.
    2. Beyond the last range the deviation was held flat at the last row's Deviation. It now keeps
       evaluating that row's equation, which is the fit's natural continuation:

           reading   before    now       certificate
           249.96    250.540   250.430   inside the range - the old answer was simply wrong
           250.00    250.580   250.470   0.04 above the top. Nofar's expected value
           251.00    251.580   251.469   the old error grows with the distance, this does not

    OutOfRange still marks anything past the certificate, so the screen can warn on a real
    excursion (MBA-475). What changed is that the number it reports alongside the warning is the
    fit continued, not the fit abandoned.

    Equation formats
    ----------------
    Nine shapes occur in the data: 'x * (N)  + N' and 'x * (N)  - N' are 30,283 of the 30,548,
    the rest are the same thing with the spaces or the brackets missing, a bare constant with no
    x term (11 rows), or an x term with no constant (5 rows). The parser below handles all nine;
    it was checked by reconstructing Deviation on every row, with no failures.

    Latest CorVersion only - 21-260 has 33 of them, and mixing versions would compensate against
    two certificates taken years apart.

    Output columns, and the difference between two of them matters
    -------------------------------------------------------------
    CorrectedExact   full precision. Use this for anything stored or calculated on.
    Corrected        rounded to the reading's own decimals, but never to fewer than 3.
    OutOfRange       1 when the reading is outside the certificate's stated coverage.
    Extrapolated     1 when no range contained the reading, so a neighbouring range's equation
                     was continued to reach it. Covers a gap between ranges as well as the ends.

    Rounding to the reading's own precision was the requested display rule, with a floor of 3
    decimals: deviations here run from about 0.001 to 2, so rounding a reading of 23 to 0 decimals
    erased the correction entirely and the calibrator saw nothing happen.

    A DECIMAL column cannot tell "10" from "10.00" - both are 10.000000 - so the decimals are
    INFERRED by stripping trailing zeros, and 10.00 infers 0, not 2. Only the front end, which
    holds what was typed, can honour that distinction exactly.

    On the quantity
    ---------------
    409 masters are %RH only and 3 carry both units; their rows are ordinary 1D ranges, so all
    1,433 masters with a certificate answer. @MeasurementId picks the quantity when a caller knows
    it; left NULL, the best-covered one in the latest version wins.

    Covered by database/tests/Test-fnMasterValueAfterCorrection.sql.
*/

CREATE OR ALTER FUNCTION dbo.fnMasterValueAfterCorrection
(
    @MeasurementDevicesId INT,
    @Reading              DECIMAL(18,6),
    @MeasurementId        INT = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH Ranked AS
    (
        SELECT c.MeasurementId, c.Value1, c.Value2, c.Equation,
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Equation IS NOT NULL
          AND @Reading IS NOT NULL
    ),
    Newest AS (SELECT MeasurementId, Value1, Value2, Equation FROM Ranked WHERE Rnk = 1),
    Chosen AS
    (
        SELECT TOP (1) MeasurementId FROM Newest
        WHERE @MeasurementId IS NULL OR MeasurementId = @MeasurementId
        GROUP BY MeasurementId ORDER BY COUNT(*) DESC, MeasurementId
    ),
    Pts AS
    (
        SELECT n.Value1, Value2 = COALESCE(n.Value2, n.Value1), n.Equation
        FROM Newest AS n JOIN Chosen AS c ON c.MeasurementId = n.MeasurementId
    ),
    /*  Split "x * (0.001101) - 0.745264" into its coefficient and its constant.

        Spaces go first, so every shape reduces to one of: x*(C)K, x*CK, x*(C), x*C, K - where a
        glued K carries its own sign. With brackets the coefficient ends at the ')'. Without them
        it ends at the first + or - that is not the coefficient's own leading sign, hence the
        search starting at character 2.  */
    Parsed AS
    (
        SELECT p.Value1, p.Value2,
               Coef  = TRY_CAST(t.CoefTxt AS FLOAT),
               Const = CASE WHEN t.ConstTxt = '' THEN 0 ELSE TRY_CAST(t.ConstTxt AS FLOAT) END
        FROM Pts AS p
        CROSS APPLY (SELECT s = REPLACE(p.Equation, ' ', '')) AS a
        CROSS APPLY (SELECT HasX = CASE WHEN LOWER(LEFT(a.s, 2)) = 'x*' THEN 1 ELSE 0 END) AS x
        CROSS APPLY (SELECT r = CASE WHEN x.HasX = 1 THEN SUBSTRING(a.s, 3, LEN(a.s)) ELSE '' END) AS q
        CROSS APPLY (SELECT Paren = CASE WHEN LEFT(q.r, 1) = '(' THEN CHARINDEX(')', q.r) ELSE 0 END) AS b
        CROSS APPLY (SELECT Sign1 = CASE WHEN x.HasX = 0 OR b.Paren > 0 THEN 0
                                         ELSE PATINDEX('%[+-]%', SUBSTRING(q.r, 2, LEN(q.r))) END) AS g
        CROSS APPLY (SELECT CoefTxt  = CASE WHEN x.HasX  = 0 THEN '0'
                                            WHEN b.Paren > 0 THEN SUBSTRING(q.r, 2, b.Paren - 2)
                                            WHEN g.Sign1 > 0 THEN LEFT(q.r, g.Sign1)
                                            ELSE q.r END,
                            ConstTxt = CASE WHEN x.HasX  = 0 THEN a.s
                                            WHEN b.Paren > 0 THEN SUBSTRING(q.r, b.Paren + 1, LEN(q.r))
                                            WHEN g.Sign1 > 0 THEN SUBSTRING(q.r, g.Sign1 + 1, LEN(q.r))
                                            ELSE '' END) AS t
    ),
    /*  LastCalibratedPoint is the highest Value1; CertTop is the end of the last range, which is
        how far the certificate actually covers. Confusing them is what made 31-77 look truncated:
        its last point is 349.98 but its certificate runs to 399.923, so a reading of 380 is inside
        it and must not be reported as an excursion.  */
    Bounds AS (SELECT LoEdge = MIN(Value1), HiEdge = MAX(Value1), CertTop = MAX(Value2) FROM Parsed),
    /*  the range that contains the reading - closed at BOTH ends, so the certificate's own top
        point is inside it. Where two ranges meet they agree to the last decimal, so preferring the
        upper one at a join changes nothing.  */
    Seg  AS (SELECT TOP (1) Coef, Const FROM Parsed
             WHERE @Reading >= Value1 AND @Reading <= Value2 ORDER BY Value1 DESC),
    /*  nothing contained it: continue the nearest range below, or the lowest range if the reading
        is beneath the whole certificate  */
    Near AS (SELECT TOP (1) Coef, Const FROM Parsed WHERE Value1 <= @Reading ORDER BY Value1 DESC),
    Low  AS (SELECT TOP (1) Coef, Const FROM Parsed ORDER BY Value1 ASC),
    /* how many decimals the reading itself carries, once trailing zeros are dropped */
    Scale AS
    (
        SELECT Decimals = CASE WHEN CHARINDEX('.', t.txt) = 0 THEN 0
                               ELSE LEN(t.txt) - CHARINDEX('.', t.txt) END
        FROM (SELECT s1 = CAST(@Reading AS NVARCHAR(40))) AS a
        CROSS APPLY (SELECT txt = CASE WHEN CHARINDEX('.', a.s1) = 0 THEN a.s1
                                       ELSE LEFT(a.s1, LEN(REPLACE(RTRIM(REPLACE(a.s1,'0',' ')),' ','0'))) END) AS b
        CROSS APPLY (SELECT txt = CASE WHEN RIGHT(b.txt,1) = '.' THEN LEFT(b.txt, LEN(b.txt)-1) ELSE b.txt END) AS t
    ),
    Dev AS
    (
        /*  one COALESCE over three whole evaluations, not over the coefficients: a half-parsed row
            would otherwise contribute its coefficient and the next row's constant  */
        SELECT Deviation = COALESCE(s.Coef * @Reading + s.Const,
                                    n.Coef * @Reading + n.Const,
                                    l.Coef * @Reading + l.Const),
               UsedMeasurementId = (SELECT MeasurementId FROM Chosen),
               OutOfRange = CASE WHEN b.LoEdge IS NULL     THEN NULL
                                 WHEN @Reading < b.LoEdge  THEN CAST(1 AS BIT)
                                 WHEN @Reading > b.CertTop THEN CAST(1 AS BIT)
                                 ELSE CAST(0 AS BIT) END,
               Extrapolated = CASE WHEN b.LoEdge IS NULL     THEN NULL
                                   WHEN s.Coef IS NOT NULL   THEN CAST(0 AS BIT)
                                   ELSE CAST(1 AS BIT) END,
               CertificateTop = b.CertTop,
               LastCalibratedPoint = b.HiEdge
        FROM Bounds AS b
        LEFT JOIN Seg  AS s ON 1 = 1
        LEFT JOIN Near AS n ON 1 = 1
        LEFT JOIN Low  AS l ON 1 = 1
    )
    SELECT Deviation = CAST(d.Deviation AS DECIMAL(18,6)),
           /* full precision - use this for anything that is stored or calculated on */
           CorrectedExact = CAST(@Reading - d.Deviation AS DECIMAL(18,6)),
           /* for the screen: as many decimals as the reading carries, never fewer than 3 */
           Corrected      = CAST(ROUND(@Reading - d.Deviation,
                                       CASE WHEN s.Decimals < 3 THEN 3 ELSE s.Decimals END)
                                 AS DECIMAL(18,6)),
           ReadingDecimals = s.Decimals,
           d.OutOfRange,
           d.Extrapolated,
           d.CertificateTop,
           d.LastCalibratedPoint,
           d.UsedMeasurementId
    FROM Dev AS d CROSS JOIN Scale AS s
);
