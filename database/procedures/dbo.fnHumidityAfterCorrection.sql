/*
    dbo.fnHumidityAfterCorrection                                                      MBA-811
    ---------------------------------------------------------------------------------------------
    A faithful port of CalibrationRepository.CalcDeviationForTemperatureAndHumidity (Hydra/VCT C#):
    the deviation on a temperature+humidity master depends on both readings, so it is interpolated
    over a TRIANGLE of correction points rather than along one axis.

      - over every triple of points, compute the query point's barycentric weights w1, w2
      - discard triangles that do not contain it (w1 < 0, w2 < 0, or w1 + w2 > 1)
      - of those left, take the one whose vertices are collectively nearest
      - deviation = d1 + w1*(d2 - d1) + w2*(d3 - d1)
      - result = ROUND(humidity - deviation, 2)     <- it compensates HUMIDITY, not temperature

    @UseSyntheticCorners mirrors CalculateCornersValues, which the C# applies at load time: four
    points at (minTemp-10, 0), (maxTemp+10, 0), (minTemp-10, 100), (maxTemp+10, 100), each given a
    blend of the nearest real extremes so a reading outside the measured region still lands inside
    some triangle. The pairing in the original is asymmetric; it is reproduced literally here
    rather than corrected.

    ---------------------------------------------------------------------------------------------
    READ THIS BEFORE USING IT. The algorithm needs each point to be a (temperature, humidity)
    coordinate. It reads Value1 as temperature and Value2 as humidity, exactly as the C# does.

    OUR DATA IS NOT THAT SHAPE. In MeasurementDevicesCorrections, Value1/Value2 are the two ends
    of a RANGE - 24,508 rows have Value2 equal to the next row's Value1, and only 2 do not. A
    humidity correction is not a second coordinate; it is its own set of rows carrying
    MeasurementId = %RH, ranged over humidity.

    So on today's data every point is collinear, no three of them enclose anything, and with
    @UseSyntheticCorners = 0 this returns no rows at all. With the corners on it returns a number
    interpolated across four synthetic points, which is arithmetic rather than metrology.

    It is committed because it was asked for and because it is the correct port if correction data
    with real (temperature, humidity) coordinates ever arrives. It should NOT be wired to a screen
    against the data as it stands.

    The same mismatch is worth checking on the C# side: LoadCorrectionValues decides
    isTemperatureOnly from HumidityValue == 0, and a range end is rarely 0, so every master
    fed through GetSensorByName would take the 2D path and treat range ends as humidities.
*/

CREATE OR ALTER FUNCTION dbo.fnHumidityAfterCorrection
(
    @MeasurementDevicesId INT,
    @Temperature          FLOAT,
    @Humidity             FLOAT,
    @UseSyntheticCorners  BIT = 1
)
RETURNS TABLE
AS
RETURN
(
    WITH Ranked AS
    (
        SELECT T = CAST(c.Value1 AS FLOAT),
               H = CAST(c.Value2 AS FLOAT),
               D = CAST(c.Deviation AS FLOAT),
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Deviation IS NOT NULL
          AND c.Value2    IS NOT NULL
          AND @Temperature IS NOT NULL
          AND @Humidity    IS NOT NULL
    ),
    Actual AS (SELECT T, H, D FROM Ranked WHERE Rnk = 1),
    Ext  AS (SELECT MinT = MIN(T), MaxT = MAX(T), MinH = MIN(H), MaxH = MAX(H) FROM Actual),
    E AS
    (
        SELECT
          d_TminHmin = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(H/5)*5 ASC,  T ASC),
          t_TminHmin = (SELECT TOP (1) T FROM Actual ORDER BY FLOOR(H/5)*5 ASC,  T ASC),
          d_TmaxHmin = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(H/5)*5 ASC,  T DESC),
          t_TmaxHmin = (SELECT TOP (1) T FROM Actual ORDER BY FLOOR(H/5)*5 ASC,  T DESC),
          d_TminHmax = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(H/5)*5 DESC, T ASC),
          t_TminHmax = (SELECT TOP (1) T FROM Actual ORDER BY FLOOR(H/5)*5 DESC, T ASC),
          d_TmaxHmax = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(H/5)*5 DESC, T DESC),
          t_TmaxHmax = (SELECT TOP (1) T FROM Actual ORDER BY FLOOR(H/5)*5 DESC, T DESC),
          d_HminTmin = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(T) ASC,  FLOOR(H/5)*5 ASC),
          h_HminTmin = (SELECT TOP (1) H FROM Actual ORDER BY FLOOR(T) ASC,  FLOOR(H/5)*5 ASC),
          d_HmaxTmin = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(T) ASC,  FLOOR(H/5)*5 DESC),
          h_HmaxTmin = (SELECT TOP (1) H FROM Actual ORDER BY FLOOR(T) ASC,  FLOOR(H/5)*5 DESC),
          d_HminTmax = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(T) DESC, FLOOR(H/5)*5 ASC),
          h_HminTmax = (SELECT TOP (1) H FROM Actual ORDER BY FLOOR(T) DESC, FLOOR(H/5)*5 ASC),
          d_HmaxTmax = (SELECT TOP (1) D FROM Actual ORDER BY FLOOR(T) DESC, FLOOR(H/5)*5 DESC),
          h_HmaxTmax = (SELECT TOP (1) H FROM Actual ORDER BY FLOOR(T) DESC, FLOOR(H/5)*5 DESC)
    ),
    W AS
    (
        SELECT TempRange = NULLIF(x.MaxT - x.MinT, 0),
               HumRange  = NULLIF(x.MaxH - x.MinH, 0),
               x.MinT, x.MaxT, x.MinH, x.MaxH, e.*
        FROM Ext AS x CROSS JOIN E AS e
    ),
    Corners AS
    (
        SELECT T = w.MinT - 10, H = CAST(0 AS FLOAT),
               D = ((a.w1et * w.d_HminTmin) + (a.w1eh * w.d_TminHmin)) / NULLIF(a.w1et + a.w1eh, 0)
        FROM W AS w
        CROSS APPLY (SELECT w1et = (w.MaxH - w.h_HminTmin) / w.HumRange,
                            w1eh = (w.MaxT - w.t_TminHmin) / w.TempRange) AS a
        WHERE @UseSyntheticCorners = 1
        UNION ALL
        SELECT w.MaxT + 10, CAST(0 AS FLOAT),
               ((a.w3et * w.d_HminTmax) + (a.w2eh * w.d_TmaxHmin)) / NULLIF(a.w3et + a.w2eh, 0)
        FROM W AS w
        CROSS APPLY (SELECT w3et = (w.MaxH - w.h_HminTmax) / w.HumRange,
                            w2eh = (w.t_TmaxHmin - w.MinT) / w.TempRange) AS a
        WHERE @UseSyntheticCorners = 1
        UNION ALL
        SELECT w.MinT - 10, CAST(100 AS FLOAT),
               ((a.w2et * w.d_HmaxTmin) + (a.w3eh * w.d_TminHmax)) / NULLIF(a.w2et + a.w3eh, 0)
        FROM W AS w
        CROSS APPLY (SELECT w2et = (w.h_HmaxTmin - w.MinH) / w.HumRange,
                            w3eh = (w.MaxT - w.t_TminHmax) / w.TempRange) AS a
        WHERE @UseSyntheticCorners = 1
        UNION ALL
        SELECT w.MaxT + 10, CAST(100 AS FLOAT),
               ((a.w4et * w.d_HmaxTmax) + (a.w4eh * w.d_TmaxHmax)) / NULLIF(a.w4et + a.w4eh, 0)
        FROM W AS w
        CROSS APPLY (SELECT w4et = (w.h_HmaxTmax - w.MinH) / w.HumRange,
                            w4eh = (w.MaxT - w.t_TmaxHmax) / w.TempRange) AS a
        WHERE @UseSyntheticCorners = 1
    ),
    P AS
    (
        SELECT T, H, D, Idx = ROW_NUMBER() OVER (ORDER BY T, H)
        FROM (SELECT T, H, D FROM Actual
              UNION ALL
              SELECT T, H, D FROM Corners WHERE D IS NOT NULL) AS u
    ),
    Tri AS
    (
        SELECT p1.D AS d1, p2.D AS d2, p3.D AS d3,
               p1.H AS h1, p2.H AS h2, p3.H AS h3,
               w1 = a.x1 / a.x2,
               w3 = SQRT(SQUARE(p1.H - @Humidity) + SQUARE(p1.T - @Temperature))
                  + SQRT(SQUARE(p2.H - @Humidity) + SQUARE(p2.T - @Temperature))
                  + SQRT(SQUARE(p3.H - @Humidity) + SQUARE(p3.T - @Temperature))
        FROM P AS p1
        JOIN P AS p2 ON p2.Idx > p1.Idx
        JOIN P AS p3 ON p3.Idx > p2.Idx
        CROSS APPLY (SELECT
              x1 = ((p1.T * (p3.H - p1.H)) + (@Humidity - p1.H) * (p3.T - p1.T))
                   - (@Temperature * (p3.H - p1.H)),
              x2 = NULLIF(((p2.H - p1.H) * (p3.T - p1.T)) - ((p2.T - p1.T) * (p3.H - p1.H)), 0)
        ) AS a
        WHERE a.x2 IS NOT NULL
    ),
    Valid AS
    (
        SELECT t.d1, t.d2, t.d3, t.w1, t.w3, b.w2
        FROM Tri AS t
        CROSS APPLY (SELECT w2 = (@Humidity - t.h1 - (t.w1 * (t.h2 - t.h1)))
                                 / NULLIF(t.h3 - t.h1, 0)) AS b
        WHERE t.w1 >= 0 AND b.w2 >= 0 AND t.w1 + b.w2 <= 1
    ),
    Best AS (SELECT TOP (1) d1, d2, d3, w1, w2, w3 FROM Valid ORDER BY w3)
    SELECT Deviation = CAST(c.dev AS DECIMAL(18,6)),
           Corrected = CAST(ROUND(@Humidity - c.dev, 2) AS DECIMAL(18,6)),
           Triangles = (SELECT COUNT(*) FROM Valid)
    FROM Best AS b
    CROSS APPLY (SELECT dev = b.d1 + (b.w1 * (b.d2 - b.d1)) + (b.w2 * (b.d3 - b.d1))) AS c
);
