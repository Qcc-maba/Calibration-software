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

    WITH Sets AS
    (
        SELECT cp.ConversionParameterId, cp.MeasurementDevicesId,
               MabaID = LTRIM(RTRIM(md.MabaID)),
               cp.RTP, cp.A4, cp.B4, cp.A7, cp.B7, cp.C7,
               cp.OrderDetailsItemId, cp.CreatedDate, cp.UpdateUserID,
               Rn = ROW_NUMBER() OVER (PARTITION BY cp.MeasurementDevicesId
                                       ORDER BY cp.ConversionParameterId DESC)
        FROM dbo.ConversionParameters AS cp
        JOIN dbo.MeasurementDevices AS md ON md.ID = cp.MeasurementDevicesId AND md.IsDeleted = 0
        WHERE cp.IsDeleted = 0
          AND (@MeasurementDevicesId IS NULL OR cp.MeasurementDevicesId = @MeasurementDevicesId)
          AND (@Maba IS NULL OR LTRIM(RTRIM(md.MabaID)) = @Maba)
          AND (@Maba IS NOT NULL OR @MeasurementDevicesId IS NOT NULL)
    )
    SELECT ConversionParameterId, MeasurementDevicesId, MabaID,
           RTP, A4, B4, A7, B7, C7,
           OrderDetailsItemId, CreatedDate, UpdateUserID,
           IsCurrent = CAST(CASE WHEN Rn = 1 THEN 1 ELSE 0 END AS BIT)
    FROM Sets
    WHERE @IncludeHistory = 1 OR Rn = 1
    ORDER BY ConversionParameterId DESC;
END;
