/*
    dbo.MergeDuplicateLoggerDevices                                                     MBA-902
    ---------------------------------------------------------------------------------------------
    Collapses the duplicate MeasurementDevices rows that every data logger has.

    All 36 loggers exist twice - 72 rows for 36 MabaIDs - and no other device class is affected.
    21-142 is ID 619 (Connection COM, COM9) and ID 807 (Connection IP, 1.1.1.1:3); 31-83 is 641 and
    829, and so on. The logger picker therefore lists the same logger twice, and worse, a sensor
    configured against one row is invisible when the calibrator happens to pick the other: 619
    carries sensor 21-89 while 807 carries 21-131, and they are the same physical logger.

    A canonical row is chosen per MabaID: the one already carrying sensor assignments, and where
    both do (only 21-142 today) the lower ID, so the choice is repeatable. Assignments on the other
    row are repointed rather than dropped - after the merge that logger holds BOTH sensor sets,
    which is what a logger with several sensors should look like anyway.

    Repointed, in this order: SensorToLoggerRelation, then ChannelsToSensorRelation, which carries
    the logger id too. A repoint that would collide with an existing row for the same
    sensor + logger + channel is skipped rather than duplicated.

    The redundant row is then soft-deleted, never removed, so the merge can be traced and undone.

    Nothing outside the duplicate set is touched. Run with @Apply = 0 first: it reports what would
    move and changes nothing.
*/
CREATE OR ALTER PROCEDURE dbo.MergeDuplicateLoggerDevices
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* every logger MabaID that has more than one active device row */
    SELECT md.MabaID, md.ID,
           IIF(EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation r
                       WHERE r.LoggerMeasurementDeviceId = md.ID AND r.IsDeleted = 0), 1, 0) AS InUse
    INTO #Rows
    FROM dbo.MeasurementDevices AS md
    JOIN dbo.MeasurementDevicesMainClasses AS mc ON mc.Id = md.MainClassId
    WHERE md.IsDeleted = 0
      AND mc.NameEnglish = 'Data logger'
      AND md.MabaID IN (SELECT m2.MabaID
                        FROM dbo.MeasurementDevices AS m2
                        JOIN dbo.MeasurementDevicesMainClasses AS c2 ON c2.Id = m2.MainClassId
                        WHERE m2.IsDeleted = 0 AND c2.NameEnglish = 'Data logger'
                        GROUP BY m2.MabaID HAVING COUNT(*) > 1);

    /* in-use rows win; among equals the lower id, so re-running picks the same winner */
    SELECT MabaID, ID AS KeepId
    INTO #Keep
    FROM (SELECT MabaID, ID,
                 ROW_NUMBER() OVER (PARTITION BY MabaID ORDER BY InUse DESC, ID ASC) AS rn
          FROM #Rows) AS r
    WHERE rn = 1;

    SELECT r.MabaID, r.ID AS DropId, k.KeepId
    INTO #Move
    FROM #Rows AS r
    JOIN #Keep AS k ON k.MabaID = r.MabaID
    WHERE r.ID <> k.KeepId;

    SELECT (SELECT COUNT(*) FROM #Keep)  AS LoggersAffected,
           (SELECT COUNT(*) FROM #Move)  AS RowsToRetire,
           (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation r
              JOIN #Move m ON m.DropId = r.LoggerMeasurementDeviceId WHERE r.IsDeleted = 0)   AS SensorLinksToMove,
           (SELECT COUNT(*) FROM dbo.ChannelsToSensorRelation c
              JOIN #Move m ON m.DropId = c.LoggerMeasurementDeviceId WHERE c.IsDeleted = 0)   AS ChannelLinksToMove;

    IF @Apply = 1
    BEGIN
        BEGIN TRAN;

            /* skip a move that would collide with a link the canonical row already has */
            UPDATE r
            SET LoggerMeasurementDeviceId = m.KeepId, UpdatedDate = GETDATE()
            FROM dbo.SensorToLoggerRelation AS r
            JOIN #Move AS m ON m.DropId = r.LoggerMeasurementDeviceId
            WHERE r.IsDeleted = 0
              AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS x
                              WHERE x.LoggerMeasurementDeviceId = m.KeepId
                                AND x.SensorMeasurementDeviceId = r.SensorMeasurementDeviceId
                                AND x.IsDeleted = 0);

            UPDATE c
            SET LoggerMeasurementDeviceId = m.KeepId, UpdatedDate = GETDATE()
            FROM dbo.ChannelsToSensorRelation AS c
            JOIN #Move AS m ON m.DropId = c.LoggerMeasurementDeviceId
            WHERE c.IsDeleted = 0
              AND NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS x
                              WHERE x.LoggerMeasurementDeviceId = m.KeepId
                                AND x.SensorMeasurementDeviceId = c.SensorMeasurementDeviceId
                                AND x.ChannelNumber = c.ChannelNumber
                                AND x.IsDeleted = 0);

            /* anything that could not move would otherwise be orphaned on a retired row */
            UPDATE r SET IsDeleted = 1, UpdatedDate = GETDATE()
            FROM dbo.SensorToLoggerRelation AS r
            JOIN #Move AS m ON m.DropId = r.LoggerMeasurementDeviceId WHERE r.IsDeleted = 0;

            UPDATE c SET IsDeleted = 1, UpdatedDate = GETDATE()
            FROM dbo.ChannelsToSensorRelation AS c
            JOIN #Move AS m ON m.DropId = c.LoggerMeasurementDeviceId WHERE c.IsDeleted = 0;

            UPDATE md SET IsDeleted = 1, UpdateDate = GETDATE()
            FROM dbo.MeasurementDevices AS md
            JOIN #Move AS m ON m.DropId = md.ID;

        COMMIT;

        SELECT (SELECT COUNT(*) FROM #Move) AS RowsRetired;
    END
    ELSE
        SELECT m.MabaID, m.KeepId, m.DropId,
               keep.Connection AS KeepConnection, drop_.Connection AS DropConnection,
               (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation r
                 WHERE r.LoggerMeasurementDeviceId = m.DropId AND r.IsDeleted = 0) AS SensorLinksOnDropped
        FROM #Move AS m
        JOIN dbo.MeasurementDevices AS keep  ON keep.ID  = m.KeepId
        JOIN dbo.MeasurementDevices AS drop_ ON drop_.ID = m.DropId
        ORDER BY SensorLinksOnDropped DESC, m.MabaID;
END
