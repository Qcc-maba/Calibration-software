/*
    dbo.ImportMissingDevicesFromKyulan                                                  MBA-902
    ---------------------------------------------------------------------------------------------
    Creates a MeasurementDevices row for every active kyulan instrument that has none.

    1,421 instruments are registered, calibrated and in date in kyulan.dbo.tblInstr and simply do
    not exist in this database - 1,216 of them sensors, 769 of those still within calibration date,
    the newest registered 12.08.2026. A calibrator cannot select them anywhere, which is what
    "I cannot see sensor 31-98" actually means: 31-98 was registered 26.05.2026, calibrated the
    same day, valid until 2028, and has no row here at all.

    This is not a re-sync of the whole registry. It INSERTS only, never updates and never deletes,
    and skips any MabaID that already exists - a device that is already here, however stale, is not
    this procedure's business. Re-running it inserts nothing the second time.

    WHAT IS COPIED, and only what could be verified against devices present in both systems:
        MabaID, Description, Model, SerialNumber, Note
        Manufacturer      - resolved to its name through kyulan.tblInstrMnf
        MainClassId       - same ids in both systems; kyulan agrees with every logger and bath
                            already classified here
        WorkRangeMin/Max  - and WorkRangeUnitId through MeasurementDeviceUnits.
                            MeasurementDeviceUnitSourceId, the mapping the work-range import proved
        CalibrationDate, NextCalibration, CreateDate

    WHAT IS DELIBERATELY LEFT NULL, because the mapping does not hold:
        MainCategoryId  - kyulan's Department has 7 values against 15 categories here, and every
                          instrument sits in Department 4 while this system spreads the same
                          devices across six categories. Guessing would mis-file them.
        MeasurementId   - checked on the 186 devices present in both: 3 agree. Not a mapping.
        SubClassId, UnitId - never populated on this side, so there is nothing to verify against.
        Connection, ConnectionPoints, IP - kyulan does not know how a device attaches to THIS
                          system. An imported logger therefore has no connection and will NOT
                          appear in the wizard's logger picker until someone configures it, which
                          is correct: the picker offers loggers the system can actually talk to.

    DisplayToCoordinator is set so imported devices behave like the existing ones in the equipment
    screens, which filter on it.

    Run with @Apply = 0 first: it reports what would be created and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ImportMissingDevicesFromKyulan
    @Apply BIT = 0,
    @OnlyInCalibrationDate BIT = 0   /* 1 = skip instruments whose calibration has expired */
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #K
    (
        MabaID          NVARCHAR(100) COLLATE DATABASE_DEFAULT PRIMARY KEY,
        Description     NVARCHAR(400) COLLATE DATABASE_DEFAULT,
        Manufacturer    NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        Model           NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        SerialNumber    NVARCHAR(200) COLLATE DATABASE_DEFAULT,
        Note            NVARCHAR(1000) COLLATE DATABASE_DEFAULT,
        MainClass       INT,
        WorkRangeUnit   INT,
        WorkRangeMin    DECIMAL(18,6),
        WorkRangeMax    DECIMAL(18,6),
        Added           DATETIME,
        Calibrated      DATETIME,
        NextCalibration DATETIME
    );

    /* OPENQUERY so the join to the manufacturer table runs on the remote server. */
    INSERT INTO #K
    SELECT MabaID, Description, Manufacturer, Model, SerialNumber, Note, MainClass,
           WorkRangeUnit, WorkRangeMin, WorkRangeMax, Added, Calibrated, NextCalibration
    FROM OPENQUERY([31.168.173.93], '
        SELECT i.MabaID,
               i.Description,
               mnf.Name AS Manufacturer,
               i.Model,
               i.SerialNumber,
               i.Note,
               i.MainClass,
               i.WorkRangeUnit,
               i.WorkRangeMin,
               i.WorkRangeMax,
               i.Added,
               i.Calibrated,
               i.NextCalibration
        FROM kyulan.dbo.tblInstr AS i
        LEFT JOIN kyulan.dbo.tblInstrMnf AS mnf ON mnf.ID = i.Manufacturer
        WHERE i.MabaID IS NOT NULL
          AND i.Removed IS NULL');

    SELECT k.*,
           u.MeasurementDeviceUnitId AS WorkRangeUnitId
    INTO #New
    FROM #K AS k
    LEFT JOIN dbo.MeasurementDeviceUnits AS u
           ON u.MeasurementDeviceUnitSourceId = k.WorkRangeUnit
          AND u.IsDeleted = 0
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevices AS m
                      WHERE m.MabaID = k.MabaID AND m.IsDeleted = 0)
      AND (k.MainClass IS NULL
           OR EXISTS (SELECT 1 FROM dbo.MeasurementDevicesMainClasses AS c WHERE c.Id = k.MainClass))
      AND (@OnlyInCalibrationDate = 0 OR k.NextCalibration > GETDATE());

    SELECT COUNT(*)                                                   AS WouldCreate,
           SUM(IIF(NextCalibration > GETDATE(), 1, 0))                AS StillInCalibrationDate,
           SUM(IIF(MainClass = 2, 1, 0))                              AS Sensors,
           SUM(IIF(MainClass = 7, 1, 0))                              AS DataLoggers,
           SUM(IIF(WorkRangeMin IS NOT NULL, 1, 0))                   AS WithWorkRange,
           SUM(IIF(WorkRangeUnit IS NOT NULL AND WorkRangeUnitId IS NULL, 1, 0)) AS UnitCouldNotBeMapped
    FROM #New;

    IF @Apply = 1
    BEGIN
        INSERT INTO dbo.MeasurementDevices
            (MabaID, Description, Manufacturer, Model, SerialNumber, Note,
             MainClassId, WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
             CalibrationDate, NextCalibration, CreateDate, UpdateDate,
             DisplayToCoordinator, IsDeleted)
        SELECT n.MabaID, n.Description, n.Manufacturer, n.Model, n.SerialNumber, n.Note,
               n.MainClass, n.WorkRangeMin, n.WorkRangeMax, n.WorkRangeUnitId,
               n.Calibrated, n.NextCalibration, ISNULL(n.Added, GETDATE()), GETDATE(),
               1, 0
        FROM #New AS n;

        SELECT @@ROWCOUNT AS RowsCreated;
    END
    ELSE
        SELECT TOP (200) MabaID, Description, Manufacturer, Model, MainClass,
               WorkRangeMin, WorkRangeMax, WorkRangeUnitId,
               CONVERT(VARCHAR(10), Calibrated, 104)      AS Calibrated,
               CONVERT(VARCHAR(10), NextCalibration, 104) AS NextCalibration
        FROM #New ORDER BY MabaID;
END
