/*
    dbo.fnMasterValueAfterCorrection                                                   MBA-811
    ---------------------------------------------------------------------------------------------
    "מד אב אחרי קיזוז" - a master's reading with its certificate deviation applied. A port of
    CalibrationRepository.CalcDeviationForTemperature from the Hydra/VCT C#, so the wizard and the
    logger cannot disagree:

        below the certificate range   deviation = the first point's
        above it                      deviation = the last point's
        on a point                    that point's deviation
        between two points            linear interpolation on deviation
        corrected                     reading - deviation

    Only the LATEST CorVersion is used. A master gains a version per calibration - 21-260 has 33 -
    and mixing them interpolates across certificates taken years apart.

    On the quantity, and why this no longer refuses humidity masters
    ----------------------------------------------------------------
    An earlier version returned NULL for any master carrying a %RH row, on the assumption that
    those were temperature+humidity masters needing a 2D interpolation. The data says otherwise:
    409 masters are %RH ONLY and just 3 carry both units. Their rows are ordinary 1D ranges - the
    %RH ones happen to be ranged from about -32 to 60, the same axis as the temperature ones - so
    they interpolate exactly like any other certificate. Refusing them cost 412 masters for
    nothing. All 1,433 masters with a certificate now return a value.

    @MeasurementId picks the quantity when a caller knows it. Left NULL, the best-covered quantity
    in the latest version wins, with the id as a tie-break so repeated calls agree. That only
    matters for the 3 masters holding two units in one version; interpolating across both would
    mix scales.

    Verified on STAGE: 31-77 at 23.0 gives 23.001792, which is 23.0 less the deviation interpolated
    between its points at 0.018 (-0.080) and 49.963 (+0.090005); 31-90 clamps to 0.449988 below
    -79.315; 30-1165-1, previously NULL, now returns 25.118567 at 25.0.
*/

CREATE OR ALTER FUNCTION dbo.fnMasterValueAfterCorrection
(
    @MeasurementDevicesId INT,
    @Reading              DECIMAL(18,6),
    @MeasurementId        INT = NULL   /* which quantity; NULL = the best-covered one */
)
RETURNS TABLE
AS
RETURN
(
    WITH Ranked AS
    (
        SELECT c.MeasurementId,
               c.Value1,
               c.Deviation,
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Deviation IS NOT NULL
          AND @Reading IS NOT NULL
    ),
    Newest AS (SELECT MeasurementId, Value1, Deviation FROM Ranked WHERE Rnk = 1),
    /* A certificate normally covers one quantity. Three masters carry two in the same version;
       interpolating across both would mix scales, so pick one - the caller's, or the better
       covered, and tie-break on the id so the answer never changes between calls. */
    Chosen AS
    (
        SELECT TOP (1) MeasurementId
        FROM Newest
        WHERE @MeasurementId IS NULL OR MeasurementId = @MeasurementId
        GROUP BY MeasurementId
        ORDER BY COUNT(*) DESC, MeasurementId
    ),
    Pts    AS (SELECT n.Value1, n.Deviation FROM Newest AS n JOIN Chosen AS c ON c.MeasurementId = n.MeasurementId),
    Bounds AS (SELECT LoEdge = MIN(Value1), HiEdge = MAX(Value1) FROM Pts),
    Below  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 <= @Reading ORDER BY Value1 DESC),
    Above  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 >  @Reading ORDER BY Value1 ASC),
    Edge   AS (SELECT LoDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 ASC),
                      HiDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 DESC)),
    Dev AS
    (
        SELECT Deviation =
            CASE
                WHEN b.LoEdge IS NULL     THEN NULL         /* no certificate */
                WHEN @Reading <  b.LoEdge THEN e.LoDev      /* clamp low  */
                WHEN @Reading >= b.HiEdge THEN e.HiDev      /* clamp high */
                WHEN a.Value1  IS NULL    THEN lo.Deviation
                WHEN lo.Value1 = @Reading THEN lo.Deviation /* exactly on a point */
                ELSE lo.Deviation
                     + ((a.Deviation - lo.Deviation) / NULLIF(a.Value1 - lo.Value1, 0))
                       * (@Reading - lo.Value1)             /* interpolate */
            END,
            UsedMeasurementId = (SELECT MeasurementId FROM Chosen)
        FROM Bounds AS b
        CROSS JOIN Edge AS e
        LEFT JOIN Below AS lo ON 1 = 1
        LEFT JOIN Above AS a  ON 1 = 1
    )
    SELECT Deviation = CAST(d.Deviation AS DECIMAL(18,6)),
           Corrected = CAST(@Reading - d.Deviation AS DECIMAL(18,6)),
           d.UsedMeasurementId
    FROM Dev AS d
);
