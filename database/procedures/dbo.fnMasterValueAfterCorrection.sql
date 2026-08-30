/*
    dbo.fnMasterValueAfterCorrection                                                   MBA-811
    ---------------------------------------------------------------------------------------------
    "מד אב אחרי קיזוז" - a master's reading with its certificate deviation applied.

    This is a port of CalibrationRepository.CalcDeviationForTemperature (the Hydra/VCT C#), which
    is the algorithm MABA has always used, so the wizard and the logger agree:

        below the certificate range   deviation = the first point's
        above it                      deviation = the last point's
        on a point                    that point's deviation
        between two points            linear interpolation on deviation
        corrected                     reading - deviation

    Only the LATEST CorVersion is used. A master accumulates a version per calibration - 21-260
    has 33 - and mixing them would interpolate across certificates years apart.

    TEMPERATURE ONLY, on purpose
    ----------------------------
    Value1/Value2 carry different things depending on the master. For a temperature master they
    are the ends of a range. For a temperature+humidity master, Value2 is the HUMIDITY - that is
    how the C# reads it (Value1 -> TemperatureValue, Value2 -> HumidityValue), and compensation
    there is a barycentric interpolation over triples of points, an O(n^3) triangle search. That
    does not belong in T-SQL: a master with 56 points is 27,720 triangles per reading.

    So a master carrying any %RH row returns NULL here rather than a plausible wrong number.
    1,021 masters are temperature-only and get a value; 412 are temperature+humidity and do not.

    Returns one row, Corrected and Deviation, NULL when it cannot be computed - no certificate,
    no reading, or a humidity master.
*/
CREATE OR ALTER FUNCTION dbo.fnMasterValueAfterCorrection
(
    @MeasurementDevicesId INT,
    @Reading              DECIMAL(18,6)
)
RETURNS TABLE
AS
RETURN
(
    WITH Pts AS
    (
        SELECT c.Value1,
               c.Deviation,
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Deviation IS NOT NULL
          AND @Reading IS NOT NULL
          /* a humidity master needs the 2D algorithm, so take none of its points */
          AND NOT EXISTS (SELECT 1
                          FROM dbo.MeasurementDevicesCorrections AS h
                          JOIN dbo.Measurements AS u ON u.ID = h.MeasurementId
                          WHERE h.MeasurementDevicesId = @MeasurementDevicesId
                            AND ISNULL(h.IsDeleted, 0) = 0
                            AND u.NameEn = N'%RH')
    ),
    Latest AS (SELECT Value1, Deviation FROM Pts WHERE Rnk = 1),
    Bounds AS (SELECT LoEdge = MIN(Value1), HiEdge = MAX(Value1) FROM Latest),
    /* the point at or below the reading, and the first one above it */
    Below AS (SELECT TOP (1) Value1, Deviation FROM Latest
              WHERE Value1 <= @Reading ORDER BY Value1 DESC),
    Above AS (SELECT TOP (1) Value1, Deviation FROM Latest
              WHERE Value1 >  @Reading ORDER BY Value1 ASC),
    Edge  AS (SELECT LoDev = (SELECT TOP (1) Deviation FROM Latest ORDER BY Value1 ASC),
                     HiDev = (SELECT TOP (1) Deviation FROM Latest ORDER BY Value1 DESC)),
    Dev AS
    (
        SELECT Deviation =
            CASE
                WHEN b.LoEdge IS NULL                THEN NULL              /* no certificate */
                WHEN @Reading <  b.LoEdge            THEN e.LoDev           /* clamp low  */
                WHEN @Reading >= b.HiEdge            THEN e.HiDev           /* clamp high */
                WHEN a.Value1 IS NULL                THEN lo.Deviation      /* on the last point */
                WHEN lo.Value1 = @Reading            THEN lo.Deviation      /* exactly on a point */
                ELSE lo.Deviation
                     + ((a.Deviation - lo.Deviation) / NULLIF(a.Value1 - lo.Value1, 0))
                       * (@Reading - lo.Value1)                             /* interpolate */
            END
        FROM Bounds AS b
        CROSS JOIN Edge AS e
        LEFT JOIN Below AS lo ON 1 = 1
        LEFT JOIN Above AS a  ON 1 = 1
    )
    SELECT Deviation = CAST(d.Deviation AS DECIMAL(18,6)),
           Corrected = CAST(@Reading - d.Deviation AS DECIMAL(18,6))
    FROM Dev AS d
);
