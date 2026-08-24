/*
    dbo.ImportMeasurementDeviceClassFromKyulan                                          MBA-902
    ---------------------------------------------------------------------------------------------
    Takes MainClassId from the legacy instrument registry, kyulan.dbo.tblInstr, over the Priority
    linked server. kyulan is the authority; this procedure exists because nothing was carrying that
    column across.

    The class ids are the SAME in both systems - verified, not assumed. Of the devices classified in
    both, kyulan agrees with every logger (106/106) and every bath (17/17).

    That guess is why this procedure exists. Classifying by keyword got 33 devices wrong:
        20 read 'אוגר נתונים ... עם רגש' and were called loggers - kyulan says they are SENSORS
        14 read 'מד חום ... עם רגש'    and were called sensors - kyulan says they are THERMOMETERS
         3 were called sensors         - kyulan says CABLE
    A description that mentions a sensor is not a sensor, and no keyword rule can know that. Where
    kyulan has an opinion it overwrites the guess.

    Scope, and it is narrower than it looks: kyulan holds 1,791 active instruments and AWS holds
    2,032 active devices, but only 401 are in both. 1,631 AWS devices are not in the active registry
    at all and this procedure cannot say anything about them. The reverse gap is worse and is NOT
    addressed here - 1,421 active kyulan instruments have no AWS row whatsoever, which is why a
    device like 31-98 (registered 2026-05-26, calibrated, in date) cannot be found in any picker.
    That is an import, not a classification, and needs its own decision.

    Removed instruments are ignored: kyulan's Removed column marks retirement, and a retired
    instrument must not resurrect a class onto a device someone is still using.

    ONE DEVICE IS NEVER RECLASSIFIED: one that is currently wired into a logger. The first run of
    this procedure moved 21-131 ('חוט TC-R + S') from Sensor to Cable because that is what the
    registry calls it - and 21-131 is attached to logger 21-142 with ten channels assigned. It
    vanished from the sensor picker while a calibrator was using it. A device connected to a logger
    is a sensor in practice whatever the registry calls it, so those are now excluded from the
    update rather than corrected afterwards.

    Sixteen other devices did move out of the sensor class on that run and were left there,
    because nothing is using them: fourteen 'מד חום סיפרתי עם רגש' became Thermometer and two
    'חוט TC' became Cable. Whether the wizard's sensor picker should also offer thermometers is a
    domain question, not a data one - the picker currently asks for MainClassId = 2 only.

    Run with @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.ImportMeasurementDeviceClassFromKyulan
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Kyulan
    (
        MabaID    NVARCHAR(100) COLLATE DATABASE_DEFAULT PRIMARY KEY,
        MainClass INT
    );

    /* OPENQUERY so the scan runs on the remote server rather than dragging tblInstr across. */
    INSERT INTO #Kyulan (MabaID, MainClass)
    SELECT MabaID COLLATE DATABASE_DEFAULT, MainClass
    FROM OPENQUERY([31.168.173.93], '
        SELECT MabaID, MIN(MainClass) AS MainClass
        FROM kyulan.dbo.tblInstr
        WHERE MabaID IS NOT NULL
          AND Removed IS NULL
          AND MainClass IS NOT NULL
        GROUP BY MabaID');

    /* A class kyulan names but this system does not have would be worse than no class at all. */
    DELETE k
    FROM #Kyulan AS k
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesMainClasses AS c WHERE c.Id = k.MainClass);

    SELECT m.ID AS MeasurementDeviceId, m.MabaID, m.Description,
           m.MainClassId AS CurrentClassId, k.MainClass AS KyulanClassId
    INTO #Apply
    FROM dbo.MeasurementDevices AS m
    INNER JOIN #Kyulan AS k ON k.MabaID = m.MabaID
    WHERE m.IsDeleted = 0
      AND (m.MainClassId IS NULL OR m.MainClassId <> k.MainClass)
      /* never demote a sensor that is wired into a logger right now - see the header */
      AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS r
                      WHERE r.IsDeleted = 0
                        AND (r.SensorMeasurementDeviceId = m.ID
                          OR r.LoggerMeasurementDeviceId = m.ID));

    SELECT
        (SELECT COUNT(*) FROM #Kyulan)                                     AS KyulanActiveWithClass,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices WHERE IsDeleted = 0)  AS AwsActiveDevices,
        (SELECT COUNT(*) FROM #Apply)                                      AS WouldChange,
        (SELECT COUNT(*) FROM #Apply WHERE CurrentClassId IS NULL)         AS FillingABlank,
        (SELECT COUNT(*) FROM #Apply WHERE CurrentClassId IS NOT NULL)     AS CorrectingAGuess,
        (SELECT COUNT(*) FROM dbo.MeasurementDevices m WHERE m.IsDeleted = 0
           AND NOT EXISTS (SELECT 1 FROM #Kyulan k WHERE k.MabaID = m.MabaID)) AS AwsRowsKyulanDoesNotKnow;

    IF @Apply = 1
    BEGIN
        UPDATE m
        SET MainClassId = a.KyulanClassId,
            UpdateDate  = GETDATE()
        FROM dbo.MeasurementDevices AS m
        INNER JOIN #Apply AS a ON a.MeasurementDeviceId = m.ID;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
        SELECT a.MabaID, a.Description,
               cc.NameHebrew AS CurrentClass, ck.NameHebrew AS KyulanClass
        FROM #Apply AS a
        LEFT JOIN dbo.MeasurementDevicesMainClasses AS cc ON cc.Id = a.CurrentClassId
        LEFT JOIN dbo.MeasurementDevicesMainClasses AS ck ON ck.Id = a.KyulanClassId
        ORDER BY a.CurrentClassId, a.KyulanClassId, a.MabaID;
END
