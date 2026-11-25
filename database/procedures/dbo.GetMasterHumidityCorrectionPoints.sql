/*
    dbo.GetMasterHumidityCorrectionPoints                                                MBA-950
    ---------------------------------------------------------------------------------------------
    The humidity certificate points of one master, for the data-entry screen: the newest version
    by default (what dbo.fnHumidityAfterCorrection uses), or every version with @AllVersions = 1.

    Also says whether the master still has a humidity curve entered the old way (one-axis rows in
    dbo.MeasurementDevicesCorrections), so the screen can tell "nothing entered yet" from "entered
    before as a curve": HasLegacyHumidityCurve. Points, once saved, take precedence over that curve.

    @MabaID or @MeasurementDevicesId. A MabaID held by more than one live device is refused.

    ONE result set - Prisma's $queryRaw reads only the first, and INSERT ... EXEC cannot take two:
    one row per point, each carrying the master's columns (MeasurementDevicesId, MabaID,
    NewestVersion, HasLegacyHumidityCurve). A master with no points yet returns a single row whose
    point columns (CorVersion ... UpdatedBy) are NULL.
*/
CREATE OR ALTER PROCEDURE dbo.GetMasterHumidityCorrectionPoints
    @MeasurementDevicesId INT = NULL,
    @MabaID               NVARCHAR(50) = NULL,
    @AllVersions          BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @MeasurementDevicesId IS NULL AND NULLIF(LTRIM(RTRIM(@MabaID)), N'') IS NOT NULL
    BEGIN
        DECLARE @Matches INT;
        SELECT @Matches = COUNT(*), @MeasurementDevicesId = MIN(md.ID)
        FROM dbo.MeasurementDevices AS md
        WHERE LTRIM(RTRIM(md.MabaID)) = LTRIM(RTRIM(@MabaID)) AND md.IsDeleted = 0;

        IF @Matches = 0
            THROW 51000, 'No live master carries that MabaID.', 1;
        IF @Matches > 1
            THROW 51000, 'That MabaID is held by more than one live device - pass MeasurementDevicesId.', 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices WHERE ID = @MeasurementDevicesId AND IsDeleted = 0)
        THROW 51000, 'Unknown or deleted master - give MeasurementDevicesId or MabaID.', 1;

    DECLARE @Newest INT = (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesHumidityCorrections
                           WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0);

    /* the newest version across the device, as dbo.fnMasterValueAfterCorrection ranks it */
    DECLARE @RhId INT = (SELECT TOP (1) ID FROM dbo.Measurements WHERE LTRIM(RTRIM(NameEn)) = N'%RH' ORDER BY ID);
    DECLARE @CurveVersion INT = (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesCorrections
                                 WHERE MeasurementDevicesId = @MeasurementDevicesId
                                   AND ISNULL(IsDeleted, 0) = 0 AND Equation IS NOT NULL);
    DECLARE @HasCurve BIT = CASE WHEN EXISTS (
            SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c
            WHERE c.MeasurementDevicesId = @MeasurementDevicesId AND c.CorVersion = @CurveVersion
              AND c.MeasurementId = @RhId AND ISNULL(c.IsDeleted, 0) = 0 AND c.Equation IS NOT NULL)
        THEN 1 ELSE 0 END;

    SELECT md.ID AS MeasurementDevicesId,
           MabaID = LTRIM(RTRIM(md.MabaID)),
           NewestVersion = @Newest,
           HasLegacyHumidityCurve = @HasCurve,
           hc.CorVersion,
           IsNewest = CAST(CASE WHEN hc.CorVersion IS NULL THEN NULL
                                WHEN hc.CorVersion = @Newest THEN 1 ELSE 0 END AS BIT),
           hc.Temperature, hc.ReferenceHumidity, hc.ReadingHumidity, hc.Deviation,
           hc.Note, hc.CreatedDate,
           UpdatedBy = u.Email
    FROM dbo.MeasurementDevices AS md
    LEFT JOIN dbo.MeasurementDevicesHumidityCorrections AS hc
           ON hc.MeasurementDevicesId = md.ID
          AND hc.IsDeleted = 0
          AND (@AllVersions = 1 OR hc.CorVersion = @Newest)
    LEFT JOIN dbo.Users AS u ON u.ID = hc.UpdateUserID
    WHERE md.ID = @MeasurementDevicesId
    ORDER BY hc.CorVersion DESC, hc.Temperature, hc.ReferenceHumidity;
END;
