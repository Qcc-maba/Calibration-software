/*
    dbo.fnHumidityAfterCorrection                                              MBA-811, MBA-950
    ---------------------------------------------------------------------------------------------
    The master value after compensation for a HUMIDITY reading: the master's humidity with its
    certificate deviation removed. The humidity counterpart of dbo.fnMasterValueAfterCorrection, with the same output
    columns, so a caller can pick one or the other by the row's quantity.

    What the lab defined (Nofar, MBA-950, 25.11.2026)
    -------------------------------------------------
      * Humidity compensation depends strongly on temperature.
      * The temperature input is the master's temperature AFTER its own compensation - not the
        set point.
      * The deviation is found by "triple interpolation": over the triangle of certificate points
        that surrounds the reading, as the legacy Hydra code did
        (CalibrationRepository.CalcDeviationForTemperatureAndHumidity).

    The first version of this function was a literal port of that C# against
    dbo.MeasurementDevicesCorrections, reading Value1 as a temperature and Value2 as a humidity.
    Those columns are the two ends of a one-axis RANGE, so on real data it found no triangle at
    all. The points now live in dbo.MeasurementDevicesHumidityCorrections, where each row really is
    (temperature, reference humidity, deviation). The legacy C# misreads its data the same way; it
    is not changed here.

    How the deviation is found, in this order
    -----------------------------------------
    1. POINTS (dbo.MeasurementDevicesHumidityCorrections, newest version)
       triangle  Every triple of points that encloses an area is a candidate. The query point
                 (temperature, humidity) gets barycentric weights l1, l2, l3 in each; a triangle
                 contains it when all three are >= 0. Of those, the one whose corners are
                 collectively nearest wins - the C#'s rule - and
                     deviation = l1*d1 + l2*d2 + l3*d3.
                 A reading outside every triangle uses the nearest triangle's plane continued
                 (Extrapolated = 1). The C# instead invented four corner points at 0 and 100 %RH;
                 continuing the fit is what dbo.fnMasterValueAfterCorrection does past the last
                 temperature range (MBA-811), and the two should not disagree on what "beyond the
                 certificate" means.
       line      Points on one line enclose no triangle. The common case is a certificate taken
                 at a single temperature: then the deviation is piecewise-linear along humidity,
                 and the temperature cannot change it. The query is projected onto the line.
       single    One point: its deviation, everywhere.
    2. CURVE (dbo.MeasurementDevicesCorrections, %RH rows of the newest version) - a master
       entered the old way, a one-axis curve. Its axis is humidity, except when its ranges go
       below 0, which a humidity cannot: then it is laid over temperature (Nofar, 38472: "for
       30-1165-1 and 30-300-1 both corrections are by temperature"). On STAGE and PROD only
       30-1187-2 is such a curve today (25.11.2026). Computed by dbo.fnMasterValueAfterCorrection
       at the right input, then subtracted from the HUMIDITY reading.
       The axis is not stored anywhere, so this is the only rule the data allows. A curve that goes
       below 0 cannot be over humidity, so that half is certain. A curve within 0..100 is read
       over humidity, as the read procedures have done since MBA-802: that is what the one writer
       of new curves, dbo.SaveMasterSensorCorrectionsBatch, stores (its reference values are the
       quantity's own), and the 409 humidity-only masters measured on 02/09 all fit it. A
       temperature-laid curve starting at or above 0 would be misread; none is known, and new
       humidity certificates go to the points table instead.
    3. Neither: no row. The caller shows a dash, as for a master with no certificate.

    Without a temperature, a temperature-dependent answer is not given: the row comes back with
    Deviation NULL and Method 'needs-temperature', so the screen can say why. A certificate taken
    at one temperature does not need one.

    The lookup is by the READING, while the certificate is laid out over the reference. The two
    differ by the deviation itself, so the answer is off by slope x deviation - the same, accepted
    approximation as the temperature compensation (MBA-816).

    Output
    ------
    Deviation, CorrectedExact, Corrected, ReadingDecimals, OutOfRange, Extrapolated,
    CertificateTop, LastCalibratedPoint   as in dbo.fnMasterValueAfterCorrection. For POINTS the
            "top" is the highest reference humidity; for a curve laid over temperature it is NULL,
            since its top is a temperature and the screen would show it as %RH.
    Source  'points' | 'curve-humidity' | 'curve-temperature'
    Method  'triangle' | 'line' | 'single' | 'range' | 'needs-temperature'
    CorVersion, PointCount   of the points used (POINTS only)
    TemperatureUsed          the temperature passed in (NULL when none was), whenever the answer
                             depends on it

    OutOfRange is 1 when the humidity is outside the certificate's humidity span, or - when the
    certificate spans temperatures at all - the temperature is outside its temperature span.

    A multi-statement function, unlike its inline predecessor; SQL Server cannot ALTER one kind
    into the other, hence the DROP. Nothing referenced the old one.

    Covered by database/tests/Test-fnHumidityAfterCorrection.sql.
*/
IF OBJECT_ID('dbo.fnHumidityAfterCorrection', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fnHumidityAfterCorrection;
GO
CREATE OR ALTER FUNCTION dbo.fnHumidityAfterCorrection
(
    @MeasurementDevicesId INT,
    @Temperature          DECIMAL(18,6),   /* the master's temperature after its own compensation */
    @Humidity             DECIMAL(18,6)    /* the master's humidity reading */
)
RETURNS @R TABLE
(
    Deviation           DECIMAL(18,6) NULL,
    CorrectedExact      DECIMAL(18,6) NULL,
    Corrected           DECIMAL(18,6) NULL,
    ReadingDecimals     INT           NULL,
    OutOfRange          BIT           NULL,
    Extrapolated        BIT           NULL,
    CertificateTop      DECIMAL(18,6) NULL,
    LastCalibratedPoint DECIMAL(18,6) NULL,
    Source              NVARCHAR(20)  NOT NULL,
    Method              NVARCHAR(20)  NOT NULL,
    CorVersion          INT           NULL,
    PointCount          INT           NULL,
    TemperatureUsed     DECIMAL(18,6) NULL
)
AS
BEGIN
    IF @MeasurementDevicesId IS NULL OR @Humidity IS NULL RETURN;

    /* decimals the reading carries once trailing zeros are dropped; shown to at least 3, as the
       temperature compensation is (MBA-811: rounding to fewer erased the correction) */
    DECLARE @Txt NVARCHAR(40) = CAST(@Humidity AS NVARCHAR(40));
    IF CHARINDEX('.', @Txt) > 0
    BEGIN
        SET @Txt = LEFT(@Txt, LEN(REPLACE(RTRIM(REPLACE(@Txt, '0', ' ')), ' ', '0')));
        IF RIGHT(@Txt, 1) = '.' SET @Txt = LEFT(@Txt, LEN(@Txt) - 1);
    END;
    DECLARE @Decimals INT = CASE WHEN CHARINDEX('.', @Txt) = 0 THEN 0 ELSE LEN(@Txt) - CHARINDEX('.', @Txt) END;
    DECLARE @Shown INT = CASE WHEN @Decimals < 3 THEN 3 ELSE @Decimals END;

    DECLARE @Eps FLOAT = 1e-9;
    DECLARE @qH FLOAT = @Humidity, @qT FLOAT = @Temperature;

    /* ---------------------------------------------------------------- 1. POINTS */
    DECLARE @Ver INT = (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesHumidityCorrections
                        WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0);
    IF @Ver IS NOT NULL
    BEGIN
        DECLARE @P TABLE (Seq INT PRIMARY KEY, T FLOAT NOT NULL, H FLOAT NOT NULL, D FLOAT NOT NULL);
        INSERT @P (Seq, T, H, D)
        SELECT ROW_NUMBER() OVER (ORDER BY Temperature, ReferenceHumidity),
               Temperature, ReferenceHumidity, Deviation
        FROM dbo.MeasurementDevicesHumidityCorrections
        WHERE MeasurementDevicesId = @MeasurementDevicesId AND CorVersion = @Ver AND IsDeleted = 0;

        DECLARE @N INT, @MinT FLOAT, @MaxT FLOAT, @MinH FLOAT, @MaxH FLOAT;
        SELECT @N = COUNT(*), @MinT = MIN(T), @MaxT = MAX(T), @MinH = MIN(H), @MaxH = MAX(H) FROM @P;

        /* one temperature on the whole certificate: the temperature cannot change the answer */
        IF @qT IS NULL AND @MaxT - @MinT < @Eps SET @qT = @MinT;

        IF @qT IS NULL
        BEGIN
            INSERT @R (ReadingDecimals, CertificateTop, LastCalibratedPoint, Source, Method, CorVersion, PointCount)
            VALUES (@Decimals, @MaxH, @MaxH, N'points', N'needs-temperature', @Ver, @N);
            RETURN;
        END;

        DECLARE @Dev FLOAT, @Extrap BIT, @Method NVARCHAR(20);

        IF @N = 1
            SELECT @Dev = D, @Method = N'single',
                   @Extrap = CASE WHEN ABS(T - @qT) < @Eps AND ABS(H - @qH) < @Eps THEN 0 ELSE 1 END
            FROM @P;
        ELSE
        BEGIN
            /* every triangle with an area; containing ones first, then by nearness of corners */
            SELECT TOP (1)
                   @Dev    = w.l1 * a.D + w.l2 * b.D + (1 - w.l1 - w.l2) * c.D,
                   @Extrap = CASE WHEN k.Inside = 1 THEN 0 ELSE 1 END,
                   @Method = N'triangle'
            FROM @P AS a
            JOIN @P AS b ON b.Seq > a.Seq
            JOIN @P AS c ON c.Seq > b.Seq
            CROSS APPLY (SELECT Den = (b.H - c.H) * (a.T - c.T) + (c.T - b.T) * (a.H - c.H)) AS g
            CROSS APPLY (SELECT l1 = ((b.H - c.H) * (@qT - c.T) + (c.T - b.T) * (@qH - c.H)) / NULLIF(g.Den, 0),
                                l2 = ((c.H - a.H) * (@qT - c.T) + (a.T - c.T) * (@qH - c.H)) / NULLIF(g.Den, 0)) AS w
            CROSS APPLY (SELECT Inside = CASE WHEN w.l1 >= -@Eps AND w.l2 >= -@Eps AND 1 - w.l1 - w.l2 >= -@Eps
                                              THEN 1 ELSE 0 END,
                                Dist = SQRT(SQUARE(a.T - @qT) + SQUARE(a.H - @qH))
                                     + SQRT(SQUARE(b.T - @qT) + SQUARE(b.H - @qH))
                                     + SQRT(SQUARE(c.T - @qT) + SQUARE(c.H - @qH))) AS k
            WHERE ABS(g.Den) > @Eps
            ORDER BY k.Inside DESC, k.Dist, a.Seq, b.Seq, c.Seq;

            /* no triangle: the points lie on one line - piecewise-linear along it */
            IF @Method IS NULL
            BEGIN
                DECLARE @T0 FLOAT, @H0 FLOAT, @Dx FLOAT, @Dy FLOAT, @Len FLOAT;
                SELECT @T0 = T, @H0 = H FROM @P WHERE Seq = 1;
                SELECT TOP (1) @Dx = T - @T0, @Dy = H - @H0 FROM @P
                ORDER BY SQUARE(T - @T0) + SQUARE(H - @H0) DESC;
                SET @Len = SQRT(@Dx * @Dx + @Dy * @Dy);

                DECLARE @L TABLE (K INT PRIMARY KEY, S FLOAT NOT NULL, D FLOAT NOT NULL);
                INSERT @L (K, S, D)
                SELECT ROW_NUMBER() OVER (ORDER BY x.S), x.S, p.D
                FROM @P AS p
                CROSS APPLY (SELECT S = ((p.T - @T0) * @Dx + (p.H - @H0) * @Dy) / @Len) AS x;

                DECLARE @Sq FLOAT = ((@qT - @T0) * @Dx + (@qH - @H0) * @Dy) / @Len;
                DECLARE @Last INT = (SELECT MAX(K) FROM @L);
                DECLARE @I INT = (SELECT MAX(K) FROM @L WHERE S <= @Sq);
                SET @I = CASE WHEN @I IS NULL THEN 1 WHEN @I >= @Last THEN @Last - 1 ELSE @I END;

                SELECT @Dev = a.D + (b.D - a.D) * (@Sq - a.S) / (b.S - a.S)
                FROM @L AS a JOIN @L AS b ON b.K = a.K + 1
                WHERE a.K = @I;

                SET @Extrap = CASE WHEN @Sq < (SELECT MIN(S) FROM @L) - @Eps
                                     OR @Sq > (SELECT MAX(S) FROM @L) + @Eps THEN 1 ELSE 0 END;
                SET @Method = N'line';
            END;
        END;

        INSERT @R (Deviation, CorrectedExact, Corrected, ReadingDecimals, OutOfRange, Extrapolated,
                   CertificateTop, LastCalibratedPoint, Source, Method, CorVersion, PointCount, TemperatureUsed)
        VALUES (CAST(@Dev AS DECIMAL(18,6)),
                CAST(@qH - @Dev AS DECIMAL(18,6)),
                CAST(ROUND(@qH - @Dev, @Shown) AS DECIMAL(18,6)),
                @Decimals,
                CAST(CASE WHEN @qH < @MinH - @Eps OR @qH > @MaxH + @Eps THEN 1
                          WHEN @MaxT - @MinT >= @Eps AND (@qT < @MinT - @Eps OR @qT > @MaxT + @Eps) THEN 1
                          ELSE 0 END AS BIT),
                @Extrap,
                CAST(@MaxH AS DECIMAL(18,6)), CAST(@MaxH AS DECIMAL(18,6)),
                /* what was passed in, never the certificate's own temperature standing in for it:
                   the column is read as "the master temperature this row was compensated at" */
                N'points', @Method, @Ver, @N, @Temperature);
        RETURN;
    END;

    /* ---------------------------------------------------------------- 2. CURVE */
    /* %RH is 3 on STAGE and 4 on PROD: resolved by name, as the read procedures do */
    DECLARE @RhId INT = (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'%RH' ORDER BY ID);
    DECLARE @CurveMin FLOAT;

    /* the newest version across the device, exactly as dbo.fnMasterValueAfterCorrection ranks it */
    WITH Ranked AS
    (
        SELECT c.MeasurementId, c.Value1, Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Equation IS NOT NULL
    )
    SELECT @CurveMin = MIN(Value1) FROM Ranked WHERE Rnk = 1 AND MeasurementId = @RhId;

    IF @CurveMin IS NULL RETURN;

    DECLARE @ByTemperature BIT = CASE WHEN @CurveMin < 0 THEN 1 ELSE 0 END;
    DECLARE @CurveSource NVARCHAR(20) = CASE WHEN @ByTemperature = 1 THEN N'curve-temperature' ELSE N'curve-humidity' END;
    DECLARE @X DECIMAL(18,6) = CASE WHEN @ByTemperature = 1 THEN @Temperature ELSE @Humidity END;

    IF @X IS NULL
    BEGIN
        INSERT @R (ReadingDecimals, Source, Method) VALUES (@Decimals, @CurveSource, N'needs-temperature');
        RETURN;
    END;

    INSERT @R (Deviation, CorrectedExact, Corrected, ReadingDecimals, OutOfRange, Extrapolated,
               CertificateTop, LastCalibratedPoint, Source, Method, TemperatureUsed)
    SELECT f.Deviation,
           CAST(@Humidity - f.Deviation AS DECIMAL(18,6)),
           CAST(ROUND(@Humidity - f.Deviation, @Shown) AS DECIMAL(18,6)),
           @Decimals,
           f.OutOfRange,
           f.Extrapolated,
           CASE WHEN @ByTemperature = 1 THEN NULL ELSE f.CertificateTop END,
           CASE WHEN @ByTemperature = 1 THEN NULL ELSE f.LastCalibratedPoint END,
           @CurveSource,
           N'range',
           CASE WHEN @ByTemperature = 1 THEN @Temperature END
    FROM dbo.fnMasterValueAfterCorrection(@MeasurementDevicesId, @X, @RhId) AS f
    WHERE f.Deviation IS NOT NULL;

    RETURN;
END;
