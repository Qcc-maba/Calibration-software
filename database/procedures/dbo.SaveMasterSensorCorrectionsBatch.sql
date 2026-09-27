/*
    dbo.SaveMasterSensorCorrectionsBatch                                               MBA-816
    ---------------------------------------------------------------------------------------------
    A lab master that has been through the ordinary calibration workflow gets a new certificate
    in MeasurementDevicesCorrections - when the calibrator presses "Save to DB" on the report
    screen, and only then. Not every calibration of a master should become its correction data,
    so nothing here runs on its own (Nofar, MBA-816, 08/09).

    Why not dbo.CreateMeasurementDevicesCorrectionsRecord
    ------------------------------------------------------
    It takes one row per call, and its duplicate check compares Value1/Value2/Deviation across the
    WHOLE table, not per device - two masters that happen to share a point cannot both be saved.
    It is left as it is; nothing in this path calls it.

    Points in, RANGES out
    ---------------------
    The calibration produces points: at each one, the master's reading and the reference value.
    The table does not hold points. Each row is a range [Value1, Value2] with its own straight
    line, 'x * (slope)  + const', and dbo.fnMasterValueAfterCorrection compensates a reading by
    finding the range that contains it and evaluating that row's Equation. Saving the points as
    rows would reproduce the exact fault MBA-811 fixed on 31-98.

    So N points, sorted by reference value, become N-1 ranges, one per neighbouring pair
    (x1,d1)-(x2,d2):

        slope = (d2 - d1) / (x2 - x1)        const = d1 - slope * x1
        Value1 = x1,  Value2 = x2,  Deviation = d1   (the line evaluated at Value1, as on every
                                                      existing row)

    Each point is stored as its REFERENCE value and the deviation there (Nofar, MBA-816, 24/09).
    The live certificates cannot tell this apart from storing the reading - 702's ranges start at
    0.040, 100.109, 249.959, and a measured reference is no rounder than a reading - so it is the
    lab's definition that decides it, not the data.

    Deviation = Reading - Reference, computed here once rather than sent by each caller: the wizard
    already shows a column called Deviation that means something else (MasterValue - NominalValue),
    and the function returns Reading - Deviation as the corrected value, so a flipped sign would
    double every error instead of removing it.

    The function looks a range up by the raw READING while the certificate is laid out over the
    reference. The two differ by the deviation itself, so a correction applied at a reading is off
    by slope x deviation - about 1e-4 for these certificates, far below their resolution. The legacy
    system has always worked this way.

    Versions
    --------
    Rows are never updated. Each save is a new CorVersion = the device's highest + 1, written in one
    transaction, so a half-written certificate can never become the newest one.

    The function ranks CorVersion across the whole DEVICE, not per quantity. A temperature+humidity
    master saved for temperature alone would therefore lose its humidity certificate the moment the
    new version landed. Rows of the previous newest version for any OTHER MeasurementId are carried
    into the new version unchanged, so each quantity keeps answering.

    Saving the same points twice writes nothing: if the new ranges match the newest version's rows
    for this quantity to 1e-9, the outcome is NoChange.

    Parameters
    ----------
    @MabaID the master's MabaID - how the lab identifies it (Nofar, 24/09). Give this or
            @MeasurementDevicesId. A MabaID held by more than one live device is refused rather
            than guessed - STAGE has three such, all test records.
    @Data   JSON array of points, e.g. [{"Reference":0.039,"Reading":0.04}, ...]. At least two,
            no repeated reference, no NULLs. Reading = what the master being calibrated showed.
    @Apply  0 (default) returns the ranges that WOULD be written and touches nothing - the screen
            can show that before the calibrator confirms. 1 writes them.

    One result set: one row per range with Outcome (WouldSave | Saved | NoChange), the CorVersion
    it belongs to, and Source (new | carried forward).

    Deliberately NOT restricted to QCC's devices. Showing the button for QCC only is the screen's
    rule for now, and saving for customer devices is expected later (Nofar, 24/09) - a guard here
    would have to be taken out again.
*/
CREATE OR ALTER PROCEDURE dbo.SaveMasterSensorCorrectionsBatch
    @LoggedInUserEmail    NVARCHAR(255),
    @MeasurementDevicesId INT,          /* this, or @MabaID */
    @Data                 NVARCHAR(MAX),
    @MeasurementId        INT = NULL,   /* NULL = the device's own MeasurementId */
    @UnitID               INT = NULL,
    @OrderDetailsItemId   INT = NULL,   /* the calibration this came from, kept in Note */
    @Apply                BIT = 0,
    @MabaID               NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserId INT = (SELECT ID FROM dbo.Users WHERE Email = @LoggedInUserEmail);
    DECLARE @MainCategoryId INT;

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

    SELECT @MainCategoryId = md.MainCategoryId,
           @MeasurementId  = COALESCE(@MeasurementId, md.MeasurementId)
    FROM dbo.MeasurementDevices AS md
    WHERE md.ID = @MeasurementDevicesId AND md.IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 51000, 'Unknown or deleted master - give MeasurementDevicesId or MabaID.', 1;
    IF @MeasurementId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Measurements WHERE ID = @MeasurementId)
        THROW 51000, 'MeasurementId is missing or unknown, and the device carries none.', 1;
    IF @UnitID IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDeviceUnits WHERE MeasurementDeviceUnitId = @UnitID)
        THROW 51000, 'Unknown UnitID.', 1;
    IF ISJSON(@Data) = 0
        THROW 51000, 'Data is not valid JSON.', 1;

    DROP TABLE IF EXISTS #Pts;
    SELECT Seq = ROW_NUMBER() OVER (ORDER BY p.Reference),
           Ref = p.Reference,
           Dev = p.Reading - p.Reference
    INTO #Pts
    FROM OPENJSON(@Data)
    WITH (Reference DECIMAL(25,15) '$.Reference', Reading DECIMAL(25,15) '$.Reading') AS p;

    IF EXISTS (SELECT 1 FROM #Pts WHERE Ref IS NULL OR Dev IS NULL)
        THROW 51000, 'Every point needs both Reference and Reading.', 1;
    IF (SELECT COUNT(*) FROM #Pts) < 2
        THROW 51000, 'At least two points are needed to form a range.', 1;
    IF (SELECT COUNT(DISTINCT Ref) FROM #Pts) <> (SELECT COUNT(*) FROM #Pts)
        THROW 51000, 'Two points share a reference value, so the range between them has no width.', 1;

    /* one straight line per neighbouring pair; the arithmetic is FLOAT, the stored ends are exact */
    DROP TABLE IF EXISTS #New;
    SELECT a.Seq,
           Value1    = a.Ref,
           Value2    = b.Ref,
           Deviation = a.Dev,
           l.Slope,
           Const     = CAST(a.Dev AS FLOAT) - l.Slope * CAST(a.Ref AS FLOAT)
    INTO #New
    FROM #Pts AS a
    JOIN #Pts AS b ON b.Seq = a.Seq + 1
    CROSS APPLY (SELECT Slope = CAST(b.Dev - a.Dev AS FLOAT)
                              / CAST(b.Ref - a.Ref AS FLOAT)) AS l;

    /* the text the function parses: 'x * (N)  + N' / 'x * (N)  - N', the shape of 30,283 of the
       30,548 live rows. Twelve decimals, trailing zeros dropped. */
    ALTER TABLE #New ADD Equation NVARCHAR(300) COLLATE DATABASE_DEFAULT;
    UPDATE #New
    SET Equation = N'x * (' + FORMAT(CAST(Slope AS DECIMAL(38,12)), N'0.############', 'en-US') + N')  '
                 + CASE WHEN Const < 0 THEN N'- ' ELSE N'+ ' END
                 + FORMAT(CAST(ABS(Const) AS DECIMAL(38,12)), N'0.############', 'en-US');

    BEGIN TRANSACTION;

    /* the lock holds the version number until the insert, so two saves cannot both take it */
    DECLARE @Current INT =
        CASE WHEN @Apply = 1
             THEN (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesCorrections WITH (UPDLOCK, HOLDLOCK)
                   WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0)
             ELSE (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesCorrections
                   WHERE MeasurementDevicesId = @MeasurementDevicesId AND IsDeleted = 0) END;
    DECLARE @NewVersion INT = ISNULL(@Current, 0) + 1;

    DROP TABLE IF EXISTS #Latest;
    SELECT c.Value1, c.Value2, c.Deviation, c.Note, c.MeasurementId, c.UnitID,
           c.MainCategoryId, c.Equation
    INTO #Latest
    FROM dbo.MeasurementDevicesCorrections AS c
    WHERE c.MeasurementDevicesId = @MeasurementDevicesId
      AND c.CorVersion = @Current
      AND c.IsDeleted = 0;

    /* unchanged = same number of ranges, and every one matches to 1e-9 */
    DECLARE @NoChange BIT =
        CASE WHEN (SELECT COUNT(*) FROM #Latest WHERE MeasurementId = @MeasurementId)
                  = (SELECT COUNT(*) FROM #New)
              AND NOT EXISTS (SELECT 1 FROM #New AS n
                              WHERE NOT EXISTS (SELECT 1 FROM #Latest AS l
                                                WHERE l.MeasurementId = @MeasurementId
                                                  AND ABS(l.Value1 - n.Value1) < 1e-9
                                                  AND ABS(ISNULL(l.Value2, l.Value1) - n.Value2) < 1e-9
                                                  AND ABS(ISNULL(l.Deviation, 0) - n.Deviation) < 1e-9))
             THEN 1 ELSE 0 END;

    DECLARE @Outcome NVARCHAR(10) = CASE WHEN @NoChange = 1 THEN N'NoChange'
                                         WHEN @Apply = 1    THEN N'Saved'
                                         ELSE N'WouldSave' END;

    IF @Apply = 1 AND @NoChange = 0
    BEGIN
        INSERT dbo.MeasurementDevicesCorrections
              (Value1, Value2, Deviation, Note, MeasurementDevicesId, MeasurementId, UnitID,
               CorVersion, MainCategoryId, Equation, UpdateUserID, CreatedDate, IsDeleted)
        SELECT n.Value1, n.Value2, n.Deviation,
               CASE WHEN @OrderDetailsItemId IS NULL THEN N'MBA-816 master calibration'
                    ELSE CONCAT(N'MBA-816 master calibration, OrderDetailsItemId ', @OrderDetailsItemId) END,
               @MeasurementDevicesId, @MeasurementId, @UnitID,
               @NewVersion, @MainCategoryId, n.Equation, @UserId, GETDATE(), 0
        FROM #New AS n;

        INSERT dbo.MeasurementDevicesCorrections
              (Value1, Value2, Deviation, Note, MeasurementDevicesId, MeasurementId, UnitID,
               CorVersion, MainCategoryId, Equation, UpdateUserID, CreatedDate, IsDeleted)
        SELECT l.Value1, l.Value2, l.Deviation,
               CONCAT(N'Carried forward from version ', @Current),
               @MeasurementDevicesId, l.MeasurementId, l.UnitID,
               @NewVersion, l.MainCategoryId, l.Equation, @UserId, GETDATE(), 0
        FROM #Latest AS l
        WHERE l.MeasurementId <> @MeasurementId OR l.MeasurementId IS NULL;
    END;

    COMMIT TRANSACTION;

    /* Equation is collated explicitly on both sides: the table column does not necessarily carry
       the database default, and the UNION fails on the conflict when it does not */
    SELECT Outcome    = @Outcome,
           CorVersion = CASE WHEN @NoChange = 1 THEN @Current ELSE @NewVersion END,
           Source     = N'new',
           MeasurementId = @MeasurementId,
           n.Value1, n.Value2, n.Deviation, Equation = n.Equation COLLATE DATABASE_DEFAULT
    FROM #New AS n
    UNION ALL
    SELECT @Outcome, @NewVersion, N'carried forward', l.MeasurementId,
           l.Value1, l.Value2, l.Deviation, l.Equation COLLATE DATABASE_DEFAULT
    FROM #Latest AS l
    WHERE @NoChange = 0 AND (l.MeasurementId <> @MeasurementId OR l.MeasurementId IS NULL)
    ORDER BY Source DESC, MeasurementId, Value1;
END;
