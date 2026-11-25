/*
    dbo.SaveMasterHumidityCorrectionPoints                                               MBA-950
    ---------------------------------------------------------------------------------------------
    The data entry of a humidity master's certificate: points of (chamber temperature, reference
    humidity, what the master read). Written to dbo.MeasurementDevicesHumidityCorrections as a new
    version; dbo.fnHumidityAfterCorrection interpolates over the newest one.

    Why points, and why three values each: humidity compensation depends on temperature and is
    found by interpolating over the triangle of points around the reading (Nofar, MBA-950,
    25.11.2026). A certificate that does not say the temperature of each point cannot feed that.
    A certificate taken at a single temperature is entered with that temperature on every point.

    The temperature certificate of the same master is not touched. It stays in
    dbo.MeasurementDevicesCorrections and keeps its own versions, so a master holding both
    (Nofar, 35012 - and every logger once MBA-1019 merges 30-1000-1 / 30-1000-2) is saved one
    quantity at a time without either save retiring the other.

    Deviation = Reading - Reference, computed here once rather than sent by the screen, exactly as
    dbo.SaveMasterSensorCorrectionsBatch does: the function subtracts it, so a flipped sign would
    double every error instead of removing it.

    Parameters
    ----------
    @MabaID or @MeasurementDevicesId   the master. A MabaID held by more than one live device is
                                       refused rather than guessed.
    @Data   JSON array, e.g. [{"Temperature":23,"Reference":10.2,"Reading":10.6}, ...]. At least
            one point; no NULLs; reference humidity within 0..100; no two points at the same
            (temperature, reference).
    @Note   free text kept on every row (certificate number, lab, ...). Compared as given: saving the
            same points with a different note - or with none - writes a new version.
    @Apply  0 (default) returns what WOULD be written and touches nothing - the screen can show it
            before the calibrator confirms. 1 writes it.

    One result set, one row per point: Outcome (WouldSave | Saved | NoChange), CorVersion,
    Temperature, ReferenceHumidity, ReadingHumidity, Deviation. Saving the same points again writes
    nothing (NoChange), so a double click cannot create a second identical version.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the
    client that deploys it (sqlcmd defaults QUOTED_IDENTIFIER to OFF). The table's filtered unique
    index needs them ON when it is created and in every session that writes the table - a
    procedure keeps the settings it was created with. Same convention as
    dbo.CustomerDevices.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE dbo.SaveMasterHumidityCorrectionPoints
    @LoggedInUserEmail    NVARCHAR(255),
    @Data                 NVARCHAR(MAX),
    @MeasurementDevicesId INT = NULL,
    @MabaID               NVARCHAR(50) = NULL,
    @Note                 NVARCHAR(500) = NULL,
    @Apply                BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);
    /* a certificate saved under no one cannot be traced back to who entered it */
    IF @UserId IS NULL
        THROW 51000, 'No user has that e-mail address.', 1;

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
    IF ISJSON(@Data) = 0
        THROW 51000, 'Data is not valid JSON.', 1;

    DROP TABLE IF EXISTS #New;
    SELECT Temperature       = p.Temperature,
           ReferenceHumidity = p.Reference,
           ReadingHumidity   = p.Reading,
           Deviation         = p.Reading - p.Reference
    INTO #New
    FROM OPENJSON(@Data)
    WITH (Temperature DECIMAL(18,6) '$.Temperature',
          Reference   DECIMAL(18,6) '$.Reference',
          Reading     DECIMAL(18,6) '$.Reading') AS p;

    IF NOT EXISTS (SELECT 1 FROM #New)
        THROW 51000, 'At least one point is needed.', 1;
    IF EXISTS (SELECT 1 FROM #New WHERE Temperature IS NULL OR ReferenceHumidity IS NULL OR ReadingHumidity IS NULL)
        THROW 51000, 'Every point needs Temperature, Reference and Reading.', 1;
    IF EXISTS (SELECT 1 FROM #New WHERE ReferenceHumidity < 0 OR ReferenceHumidity > 100)
        /* no percent sign in the text: THROW then returns an empty message */
        THROW 51000, 'A reference humidity must be between 0 and 100 (percent RH).', 1;
    IF EXISTS (SELECT 1 FROM #New GROUP BY Temperature, ReferenceHumidity HAVING COUNT(*) > 1)
        THROW 51000, 'Two points share a temperature and a reference humidity.', 1;

    BEGIN TRANSACTION;

    /* the lock holds the version number until the insert, so two saves cannot both take it */
    DECLARE @Current INT =
        CASE WHEN @Apply = 1
             THEN (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesHumidityCorrections WITH (UPDLOCK, HOLDLOCK)
                   WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0)
             ELSE (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesHumidityCorrections
                   WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0) END;

    /* unchanged = the same points exactly, no more and no fewer, and the same note. A corrected
       note alone (a fixed certificate number) is a change and writes a new version. */
    DECLARE @NoChange BIT =
        CASE WHEN @Current IS NOT NULL
              AND NOT EXISTS (SELECT Temperature, ReferenceHumidity, ReadingHumidity FROM #New
                              EXCEPT
                              SELECT Temperature, ReferenceHumidity, ReadingHumidity
                              FROM dbo.MeasurementDevicesHumidityCorrections
                              WHERE MeasurementDevicesId = @MeasurementDevicesId AND CorVersion = @Current AND IsDeleted = 0)
              AND NOT EXISTS (SELECT Temperature, ReferenceHumidity, ReadingHumidity
                              FROM dbo.MeasurementDevicesHumidityCorrections
                              WHERE MeasurementDevicesId = @MeasurementDevicesId AND CorVersion = @Current AND IsDeleted = 0
                              EXCEPT
                              SELECT Temperature, ReferenceHumidity, ReadingHumidity FROM #New)
              AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections
                              WHERE MeasurementDevicesId = @MeasurementDevicesId AND CorVersion = @Current AND IsDeleted = 0
                                AND ISNULL(Note, N'') <> ISNULL(@Note, N''))
             THEN 1 ELSE 0 END;

    DECLARE @Version INT = CASE WHEN @NoChange = 1 THEN @Current ELSE ISNULL(@Current, 0) + 1 END;
    DECLARE @Outcome NVARCHAR(10) = CASE WHEN @NoChange = 1 THEN N'NoChange'
                                         WHEN @Apply = 1    THEN N'Saved'
                                         ELSE N'WouldSave' END;

    IF @Apply = 1 AND @NoChange = 0
        INSERT dbo.MeasurementDevicesHumidityCorrections
              (MeasurementDevicesId, CorVersion, Temperature, ReferenceHumidity, ReadingHumidity, Deviation,
               Note, UpdateUserID)
        SELECT @MeasurementDevicesId, @Version, n.Temperature, n.ReferenceHumidity, n.ReadingHumidity, n.Deviation,
               @Note, @UserId
        FROM #New AS n;

    COMMIT TRANSACTION;

    SELECT Outcome = @Outcome, CorVersion = @Version,
           n.Temperature, n.ReferenceHumidity, n.ReadingHumidity, n.Deviation
    FROM #New AS n
    ORDER BY n.Temperature, n.ReferenceHumidity;
END;
