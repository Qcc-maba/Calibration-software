/*
    dbo.ClassifyUnclassifiedMeasurementDevices                                         MBA-902
    ---------------------------------------------------------------------------------------------
    Sets MainClassId on measurement devices that never had one.

    1,828 of the 2,032 active devices carry MainClassId = NULL, so every picker that filters by
    device class silently offered a fraction of the fleet - 31-21 ("מד חום ספרתי עם רגש") looked
    like a missing device when it was only a missing classification.

    Two rules, both approved explicitly, both read off the Hebrew description:
        contains אוגר or לוגר  -> 7  Data logger   (419 devices)
        contains רגש           -> 2  Sensor         (68 devices)

    Logger is tested FIRST and wins on its own. Nine devices read 'אוגר נתונים לטמפ' ולחות עם רגש'
    - a data logger that has a sensor in it - and they are loggers, not sensors. That is why the
    counts come out 419 + 68 and not 419 + 77.

    UPDATE only, and only where MainClassId IS NULL. It never reclassifies a device that somebody
    already classified, so it is safe to re-run and cannot undo a manual correction.

    Deliberately NOT applied to the other 1,341 unclassified devices. Their descriptions carry no
    keyword that maps to a class with any confidence, and guessing a device class wrong is worse
    than leaving it blank - the wrong guess puts a device in a picker where a calibrator may
    actually select it. Those need the reviewed spreadsheet pass.

    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ClassifyUnclassifiedMeasurementDevices
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DataLogger INT = 7, @Sensor INT = 2;

    SELECT md.ID AS MeasurementDeviceId, md.MabaID, md.Description, md.Connection,
           CASE
               WHEN md.Description LIKE N'%אוגר%' OR md.Description LIKE N'%לוגר%' THEN @DataLogger
               WHEN md.Description LIKE N'%רגש%'                                   THEN @Sensor
           END AS NewMainClassId
    INTO #Apply
    FROM dbo.MeasurementDevices AS md
    WHERE md.IsDeleted = 0
      AND md.MainClassId IS NULL
      AND (md.Description LIKE N'%אוגר%' OR md.Description LIKE N'%לוגר%' OR md.Description LIKE N'%רגש%');

    SELECT c.Id AS MainClassId, c.NameEnglish, c.NameHebrew,
           COUNT(a.MeasurementDeviceId) AS WouldClassify,
           (SELECT COUNT(*) FROM dbo.MeasurementDevices m
             WHERE m.IsDeleted = 0 AND m.MainClassId = c.Id) AS ClassifiedAlready
    FROM dbo.MeasurementDevicesMainClasses AS c
    LEFT JOIN #Apply AS a ON a.NewMainClassId = c.Id
    WHERE c.Id IN (@DataLogger, @Sensor)
    GROUP BY c.Id, c.NameEnglish, c.NameHebrew;

    IF @Apply = 1
    BEGIN
        UPDATE md
        SET MainClassId = a.NewMainClassId,
            UpdateDate  = GETDATE()
        FROM dbo.MeasurementDevices AS md
        INNER JOIN #Apply AS a ON a.MeasurementDeviceId = md.ID
        WHERE md.MainClassId IS NULL;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
        SELECT MabaID, Description, Connection, NewMainClassId FROM #Apply ORDER BY NewMainClassId, MabaID;
END
