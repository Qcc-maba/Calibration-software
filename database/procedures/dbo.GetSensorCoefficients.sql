/*
    dbo.GetSensorCoefficients                                                          MBA-816
    ---------------------------------------------------------------------------------------------
    A precision sensor's ITS-90 coefficients (RTP, A4, B4, A7, B7, C7), by MabaID - written by
    dbo.SaveSensorCoefficients. For the calibration screens, and for the station once it stops
    converting every sensor with 21-214's hard-coded values (MBA-831).

    @IncludeHistory 0 (default): the current set only - the sensor's newest row.
                    1: every set, newest first, with IsCurrent marking the one in use.

    No rows means no coefficients on file - that is an answer, not an error. The station will ask
    for every master it serves, and most are not precision resistance sensors, so an unknown or
    coefficient-less MabaID returns empty rather than raising.

    A MabaID held by more than one live device is still refused: returning one of them would be a
    guess, and a station converting with the wrong sensor's coefficients reports a plausible,
    wrong temperature. Pass @MeasurementDevicesId to say which one is meant.

    MBA-831: also the sensor's working range (WorkRangeMin/Max, and the second range where it has
    one), so the station can warn when a master reads outside the range its coefficients were fitted
    over - outside it they can be off by degrees (21-290: about 87 degC at 100 degC, Jira 38168).
    Only a range recorded in Celsius is returned; any other unit comes back NULL, which the station
    reads as "no range on file". STAGE 2026-11: every precision sensor's range is in Celsius, none
    has a second one. The unit is matched by name, not by id, which differs by server: its English long
    name 'Celsius' or its short name (degree sign + C), spaces ignored. PROD's unit row was not checked
    from here - check it before deploying (review of #63).
*/
CREATE OR ALTER PROCEDURE dbo.GetSensorCoefficients
    @MabaID               NVARCHAR(50) = NULL,
    @MeasurementDevicesId INT          = NULL,
    @IncludeHistory       BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Maba NVARCHAR(50) = NULLIF(LTRIM(RTRIM(@MabaID)), N'');

    IF @Maba IS NOT NULL AND @MeasurementDevicesId IS NULL
       AND (SELECT COUNT(*) FROM dbo.MeasurementDevices
            WHERE LTRIM(RTRIM(MabaID)) = @Maba AND IsDeleted = 0) > 1
        THROW 51000, 'That MabaID is held by more than one live device - pass MeasurementDevicesId too.', 1;

    /* both given and naming different devices: an error, as dbo.SaveSensorCoefficients raises - an
       empty result would read as "no coefficients on file", which is a different answer */
    IF @Maba IS NOT NULL AND @MeasurementDevicesId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices
                       WHERE ID = @MeasurementDevicesId AND LTRIM(RTRIM(MabaID)) = @Maba)
        THROW 51000, 'MabaID and MeasurementDevicesId name different devices.', 1;

    WITH Sets AS
    (
        SELECT cp.ConversionParameterId, cp.MeasurementDevicesId,
               MabaID = LTRIM(RTRIM(md.MabaID)),
               cp.RTP, cp.A4, cp.B4, cp.A7, cp.B7, cp.C7,
               cp.OrderDetailsItemId, cp.CreatedDate, cp.UpdateUserID,
               WorkRangeMin  = CASE WHEN u1.IsCelsius = 1 THEN md.WorkRangeMin  END,
               WorkRangeMax  = CASE WHEN u1.IsCelsius = 1 THEN md.WorkRangeMax  END,
               WorkRangeMin2 = CASE WHEN u2.IsCelsius = 1 THEN md.WorkRangeMin2 END,
               WorkRangeMax2 = CASE WHEN u2.IsCelsius = 1 THEN md.WorkRangeMax2 END,
               Rn = ROW_NUMBER() OVER (PARTITION BY cp.MeasurementDevicesId
                                       ORDER BY cp.ConversionParameterId DESC)
        FROM dbo.ConversionParameters AS cp
        JOIN dbo.MeasurementDevices AS md ON md.ID = cp.MeasurementDevicesId AND md.IsDeleted = 0
        OUTER APPLY (SELECT IsCelsius = 1 FROM dbo.MeasurementDeviceUnits AS u
                     WHERE u.MeasurementDeviceUnitId = md.WorkRangeUnitId
                       AND (LTRIM(RTRIM(u.LongNameEn)) = N'Celsius'
                            OR LTRIM(RTRIM(u.ShortNameEn)) = NCHAR(176) + N'C')) AS u1
        OUTER APPLY (SELECT IsCelsius = 1 FROM dbo.MeasurementDeviceUnits AS u
                     WHERE u.MeasurementDeviceUnitId = md.WorkRangeUnitId2
                       AND (LTRIM(RTRIM(u.LongNameEn)) = N'Celsius'
                            OR LTRIM(RTRIM(u.ShortNameEn)) = NCHAR(176) + N'C')) AS u2
        WHERE cp.IsDeleted = 0
          AND (@MeasurementDevicesId IS NULL OR cp.MeasurementDevicesId = @MeasurementDevicesId)
          AND (@Maba IS NULL OR LTRIM(RTRIM(md.MabaID)) = @Maba)
          AND (@Maba IS NOT NULL OR @MeasurementDevicesId IS NOT NULL)
    )
    SELECT ConversionParameterId, MeasurementDevicesId, MabaID,
           RTP, A4, B4, A7, B7, C7,
           OrderDetailsItemId, CreatedDate, UpdateUserID,
           IsCurrent = CAST(CASE WHEN Rn = 1 THEN 1 ELSE 0 END AS BIT),
           WorkRangeMin, WorkRangeMax, WorkRangeMin2, WorkRangeMax2
    FROM Sets
    WHERE @IncludeHistory = 1 OR Rn = 1
    ORDER BY ConversionParameterId DESC;
END;
