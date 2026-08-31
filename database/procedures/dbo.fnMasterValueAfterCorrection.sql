/*
    dbo.fnMasterValueAfterCorrection                                                   MBA-811
    ---------------------------------------------------------------------------------------------
    "מד אב אחרי קיזוז" - a master's reading with its certificate deviation applied. A port of
    CalibrationRepository.CalcDeviationForTemperature from the Hydra/VCT C#, so the wizard and the
    logger cannot disagree: clamp outside the certificate, interpolate the deviation between the two
    bracketing points, subtract. Latest CorVersion only - 21-260 has 33, and mixing them would
    interpolate across certificates taken years apart.

    Three output columns, and the difference between two of them matters
    --------------------------------------------------------------------
    CorrectedExact   full precision. Use this for anything stored or calculated on.
    Corrected        the same number rounded to however many decimals the READING carries.
    OutOfRange       1 when the reading fell outside the certificate and the deviation was clamped.

    Rounding to the reading's own precision was the requested display rule. It has a consequence
    worth knowing before it is switched on: deviations here are small, so the rounding usually
    erases the correction entirely.

        reading 23      deviation -0.001792   exact 23.001792   rounded 23
        reading 50.00   deviation +0.090027   exact 49.909973   rounded 50
        reading 10.5    deviation -0.044330   exact 10.544330   rounded 10.5
        reading 6000    deviation -0.630023   exact 6000.630023 rounded 6001

    A calibrator would see the reading come back unchanged and conclude nothing was compensated.
    Both procedures therefore read CorrectedExact for now; the display rule is still open.

    A related limit: a DECIMAL column cannot tell "10" from "10.00" - both are 10.000000 - so the
    decimals are INFERRED by stripping trailing zeros, and 10.00 infers 0, not 2. Only the front
    end, which holds what was typed, can honour that distinction exactly.

    On the quantity
    ---------------
    An earlier version returned NULL for any master carrying a %RH row, assuming those needed a 2D
    interpolation. 409 masters are %RH ONLY and just 3 carry both units; their rows are ordinary 1D
    ranges. All 1,433 masters with a certificate now answer. @MeasurementId picks the quantity when
    a caller knows it; left NULL the best-covered one in the latest version wins.

    Covered by database/tests/Test-fnMasterValueAfterCorrection.sql - 13 cases, including the
    silent out-of-range clamp.
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
        SELECT c.MeasurementId, c.Value1, c.Value2, c.Deviation,
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Deviation IS NOT NULL
          AND @Reading IS NOT NULL
    ),
    Newest AS (SELECT MeasurementId, Value1, Value2, Deviation FROM Ranked WHERE Rnk = 1),
    Chosen AS
    (
        SELECT TOP (1) MeasurementId FROM Newest
        WHERE @MeasurementId IS NULL OR MeasurementId = @MeasurementId
        GROUP BY MeasurementId ORDER BY COUNT(*) DESC, MeasurementId
    ),
    Pts    AS (SELECT n.Value1, n.Value2, n.Deviation FROM Newest AS n JOIN Chosen AS c ON c.MeasurementId = n.MeasurementId),
    /* Two different upper edges, and confusing them is what made 31-77 look truncated.
       LastPoint is the highest calibrated point - interpolation cannot go past it, so that is
       where the deviation starts being clamped, exactly as the C# does.
       CertTop is the end of the last RANGE, which is how far the certificate actually covers.
       31-77: last point 349.98, certificate top 399.923. A reading of 380 is inside the
       certificate and must not be reported as beyond it. */
    Bounds AS (SELECT LoEdge  = MIN(Value1),
                      HiEdge  = MAX(Value1),
                      CertTop = MAX(COALESCE(Value2, Value1)) FROM Pts),
    Below  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 <= @Reading ORDER BY Value1 DESC),
    Above  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 >  @Reading ORDER BY Value1 ASC),
    Edge   AS (SELECT LoDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 ASC),
                      HiDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 DESC)),
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
        SELECT Deviation =
            CASE
                WHEN b.LoEdge IS NULL     THEN NULL
                WHEN @Reading <  b.LoEdge THEN e.LoDev
                WHEN @Reading >= b.HiEdge THEN e.HiDev
                WHEN a.Value1  IS NULL    THEN lo.Deviation
                WHEN lo.Value1 = @Reading THEN lo.Deviation
                ELSE lo.Deviation
                     + ((a.Deviation - lo.Deviation) / NULLIF(a.Value1 - lo.Value1, 0))
                       * (@Reading - lo.Value1)
            END,
            UsedMeasurementId = (SELECT MeasurementId FROM Chosen),
            OutOfRange = CASE WHEN b.LoEdge IS NULL     THEN NULL
                              WHEN @Reading < b.LoEdge  THEN CAST(1 AS BIT)
                              WHEN @Reading > b.CertTop THEN CAST(1 AS BIT)
                              ELSE CAST(0 AS BIT) END,
            /* the deviation stopped following the curve and is being held flat */
            Extrapolated = CASE WHEN b.LoEdge IS NULL    THEN NULL
                                WHEN @Reading < b.LoEdge THEN CAST(1 AS BIT)
                                WHEN @Reading > b.HiEdge THEN CAST(1 AS BIT)
                                ELSE CAST(0 AS BIT) END,
            CertificateTop = b.CertTop,
            LastCalibratedPoint = b.HiEdge
        FROM Bounds AS b
        CROSS JOIN Edge AS e
        LEFT JOIN Below AS lo ON 1 = 1
        LEFT JOIN Above AS a  ON 1 = 1
    )
    SELECT Deviation = CAST(d.Deviation AS DECIMAL(18,6)),
           /* full precision - use this for anything that is stored or calculated on */
           CorrectedExact = CAST(@Reading - d.Deviation AS DECIMAL(18,6)),
           /* for the screen: as many decimals as the reading itself carries */
           Corrected      = CAST(ROUND(@Reading - d.Deviation, s.Decimals) AS DECIMAL(18,6)),
           ReadingDecimals = s.Decimals,
           d.OutOfRange,
           d.Extrapolated,
           d.CertificateTop,
           d.LastCalibratedPoint,
           d.UsedMeasurementId
    FROM Dev AS d CROSS JOIN Scale AS s
);
