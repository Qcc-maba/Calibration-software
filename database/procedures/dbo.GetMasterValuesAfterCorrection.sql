/*
    dbo.GetMasterValuesAfterCorrection                                                   MBA-950
    ---------------------------------------------------------------------------------------------
    "מד אב אחרי קיזוז" for values the calibrator is still typing - before anything is saved.

    The sensors table shows the compensated master value as soon as a master number or a reading
    changes ("any change ... shall trigger the relevant compensation calculations automatically",
    MBA-950). Until now the browser worked that out itself, from correction rows it fetched
    (master-sensor-compensation.ts), so the screen and the saved report could disagree, and
    temperature and humidity rows were mixed (MBA-950, 38142 point 3). Humidity needs triangle
    interpolation over (temperature, humidity) points with the pair's compensated temperature as
    input; doing that twice, in two languages, is how the two answers drift apart. This returns
    the same numbers the read procedures return after the save, from the same two functions.

    @Data   JSON array, one entry per table row:
              [{"Key":"row-7","MabaID":"30-1165","UnitId":12,"Reading":45.3,"PairId":"<guid>"}, ...]
            Key       anything; echoed back so the caller can match rows
            MabaID    the row's master
            UnitId    the row's unit (MeasurementDeviceUnitId); decides temperature vs humidity
            Reading   the master's reading
            PairId    optional; the Temperature and RH rows of one position share it. An RH row
                      takes its temperature input from the compensated value of the other row
                      of its pair, exactly as in dbo.GetCalibrationValuesForOrderDetailItem.

    One row per entry: Key, MeasurementDevicesId (NULL = MabaID unknown or ambiguous), IsHumidity,
    Deviation, MasterValueAfterCorrection, MasterValueAfterCorrectionExact,
    BeyondCertificateRange, DeviationExtrapolated, MasterHasCorrectionForQuantity,
    CompensationSource, CompensationMethod, HumidityTemperatureInput. Read-only.
*/
CREATE OR ALTER PROCEDURE dbo.GetMasterValuesAfterCorrection
    @Data NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF ISJSON(@Data) = 0
        THROW 51000, 'Data is not valid JSON.', 1;

    DECLARE @RhId INT = (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'%RH' ORDER BY ID);
    DECLARE @TempId INT = (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'°C' ORDER BY ID);

    DROP TABLE IF EXISTS #Row;
    SELECT j.[Key], j.MabaID, j.UnitId, j.Reading,
           PairId = TRY_CONVERT(UNIQUEIDENTIFIER, NULLIF(LTRIM(RTRIM(j.PairId)), N'')),
           /* a MabaID held by two live devices is not guessed at: no device, no compensation */
           DeviceId = (SELECT CASE WHEN COUNT(*) = 1 THEN MIN(md.ID) END
                       FROM dbo.MeasurementDevices AS md
                       WHERE LTRIM(RTRIM(md.MabaID)) = LTRIM(RTRIM(j.MabaID)) AND md.IsDeleted = 0),
           QuantityId = (SELECT TOP (1) m.ID
                         FROM dbo.Measurements AS m
                         JOIN dbo.MeasurementDeviceUnits AS u
                           ON LTRIM(RTRIM(u.ShortNameEn)) = LTRIM(RTRIM(m.NameEn))
                          AND ISNULL(u.IsDeleted, 0) = 0
                         WHERE u.MeasurementDeviceUnitId = j.UnitId)
    INTO #Row
    FROM OPENJSON(@Data)
    WITH ([Key]   NVARCHAR(200)  '$.Key',
          MabaID  NVARCHAR(50)   '$.MabaID',
          UnitId  INT            '$.UnitId',
          Reading DECIMAL(18,6)  '$.Reading',
          PairId  NVARCHAR(50)   '$.PairId') AS j;

    /* temperature rows (and rows of unknown quantity) first: an RH row needs its pair's answer */
    DROP TABLE IF EXISTS #Temp;
    SELECT r.[Key], r.PairId, f.Deviation, f.Corrected, f.CorrectedExact, f.OutOfRange, f.Extrapolated
    INTO #Temp
    FROM #Row AS r
    OUTER APPLY dbo.fnMasterValueAfterCorrection(r.DeviceId, r.Reading, r.QuantityId) AS f
    WHERE r.QuantityId IS NULL OR r.QuantityId <> @RhId;

    SELECT r.[Key],
           MeasurementDevicesId = r.DeviceId,
           IsHumidity = CAST(CASE WHEN r.QuantityId = @RhId THEN 1 ELSE 0 END AS BIT),
           Deviation                       = IIF(r.QuantityId = @RhId, h.Deviation, t.Deviation),
           MasterValueAfterCorrection      = IIF(r.QuantityId = @RhId, h.Corrected, t.Corrected),
           MasterValueAfterCorrectionExact = IIF(r.QuantityId = @RhId, h.CorrectedExact, t.CorrectedExact),
           BeyondCertificateRange          = IIF(r.QuantityId = @RhId, h.OutOfRange, t.OutOfRange),
           DeviationExtrapolated           = IIF(r.QuantityId = @RhId, h.Extrapolated, t.Extrapolated),
           MasterHasCorrectionForQuantity  = CAST(CASE
               WHEN r.DeviceId IS NULL THEN NULL
               WHEN r.QuantityId = @RhId AND EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS hc
                                                     WHERE hc.MeasurementDevicesId = r.DeviceId AND hc.IsDeleted = 0) THEN 1
               WHEN EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS mc
                            WHERE mc.MeasurementDevicesId = r.DeviceId
                              AND ISNULL(mc.IsDeleted, 0) = 0
                              AND mc.Equation IS NOT NULL
                              AND (r.QuantityId IS NULL OR mc.MeasurementId = r.QuantityId)
                              AND mc.CorVersion = (SELECT MAX(m2.CorVersion) FROM dbo.MeasurementDevicesCorrections AS m2
                                                   WHERE m2.MeasurementDevicesId = r.DeviceId
                                                     AND ISNULL(m2.IsDeleted, 0) = 0
                                                     AND m2.Equation IS NOT NULL)) THEN 1
               ELSE 0 END AS BIT),
           CompensationSource = IIF(r.QuantityId = @RhId, h.Source, IIF(t.Deviation IS NOT NULL, N'curve', NULL)),
           CompensationMethod = IIF(r.QuantityId = @RhId, h.Method, IIF(t.Deviation IS NOT NULL, N'range', NULL)),
           HumidityTemperatureInput = h.TemperatureUsed
    FROM #Row AS r
    LEFT JOIN #Temp AS t ON t.[Key] = r.[Key] AND (r.QuantityId IS NULL OR r.QuantityId <> @RhId)
    /* the other row of the pair, compensated against ITS master's °C curve - as the read
       procedures do, so a pair row with no unit is never given a humidity curve */
    OUTER APPLY (SELECT TOP (1) pt.CorrectedExact
                 FROM #Row AS p
                 CROSS APPLY dbo.fnMasterValueAfterCorrection(p.DeviceId, p.Reading, @TempId) AS pt
                 WHERE r.QuantityId = @RhId AND r.PairId IS NOT NULL
                   AND p.PairId = r.PairId AND p.[Key] <> r.[Key]
                   AND (p.QuantityId IS NULL OR p.QuantityId <> @RhId)
                 ORDER BY p.[Key]) AS pair
    OUTER APPLY dbo.fnHumidityAfterCorrection(
        CASE WHEN r.QuantityId = @RhId THEN r.DeviceId END,
        pair.CorrectedExact,
        r.Reading) AS h;
END;
