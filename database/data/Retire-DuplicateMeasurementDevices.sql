/*
    Retire-DuplicateMeasurementDevices                                                  MBA-1060
    ---------------------------------------------------------------------------------------------
    Soft-deletes the extra active copies of a MabaID in dbo.MeasurementDevices, keeping the copy
    that is actually in use.

    WHY (measured read-only on 2026-11-26):

    PROD has 36 MabaIDs with more than one active row: 112 rows, 76 of them extra. They come from
    CalibratorDB/ListOfAllEquipment.sql (branch CalibratorDBProject, never on develop), whose
    logger block DELETEs devices classed 'Data logger' and re-INSERTs the same 36 loggers. It was
    run by hand three times (2026-01-05 14:09:46, 2026-01-08 14:16:39, 2026-01-08 14:29:39). The
    first two runs inserted MainClassId NULL, so each following DELETE missed them and the batch
    stacked up. The third set MainClassId 7. STAGE had the same batch twice (2026-05-13/14), and
    MBA-902's dbo.MergeDuplicateLoggerDevices retired 36 copies there on 2026-08-25. That procedure
    only groups rows classed 'Data logger', so on PROD (one classed copy per MabaID) it finds nothing.

    "Keep the lowest ID" is wrong. On PROD the live links of 21-337 and 21-297 sit on the NEWEST
    copy (850: 4 sensor-logger, 35 channel, 9 order-item rows; 849: 1 / 10 / 3). 21-422's two
    order points sit on the oldest copy (807). 21-675's real sensor 740 is referenced by everything,
    while 796/832 are copies of 18-172 (34401A U536140116) that were later re-keyed to 21-675 through
    the equipment edit screen. Corrections were copied identically onto every copy of 21-242
    (19 rows), 21-260 (182) and 21-401 (9) by stg.MergeMeasurementDevicesCorrection, which joins
    on MabaID. STAGE's remaining set (10-30, 21-500, 21-540, 21-675) is test rows re-keyed or
    created in the UI. 21-500's second row and 21-675's 4653 carry their own data, so they are refused.

    THE RULE, per MabaID with more than one active row:
      keep   = an explicit @KeepOverride, else the copy with link rows, else the copy with
               certificate rows, else a copy that has a MainClassId, else the lowest ID;
      retire = every other copy: IsDeleted = 1, RemoveDate = UpdateDate = one shared timestamp.
    The class step is not cosmetic. The VCT server resolves a logger with
    "MabaID = @MabaID AND MainClassId = 7 AND IsDeleted = 0" (CalibratorDeviceConfigFromDb), and
    the logger pickers require class 'Data logger'. On PROD only the third load's copy has class 7,
    so "oldest when nothing is referenced" would have kept the unclassed copy of 31 loggers, and
    those loggers would have vanished from every station. Among the Jan-load copies MainClassId
    is the only column that differs, so keeping the classed one loses nothing.
    Child rows (links, corrections, coefficients) are NOT touched. They stay on the retired copy,
    which is what makes this reversible with one UPDATE.

    A MabaID is REFUSED, and @Apply = 1 does nothing at all, when:
      - link rows sit on more than one copy (someone has to decide which one is real), or
      - a copy that would be retired has link rows, or
      - a copy that would be retired has certificate rows that differ from the kept copy's
        (count + checksum of every certificate table, ignoring ids, dates and the user), or
      - a copy that would be retired is classed 'Data logger' and the kept copy is not.
    A refused MabaID you have looked at can be left alone with @SkipMabaIds; the rest then runs.
    The run also refuses outright when a foreign key to MeasurementDevices comes from a table this
    script does not know about, since its rows would not have been counted.

    Link tables:  SensorToLoggerRelation, ChannelsToSensorRelation (no FK),
                  MeasurmentDeviceToOrderDetailsItems, MeasurmentPointsToOrderDetailsItems,
                  MeasurmentPointsToCalibrationCycles (no FK), MeasurementDevicesToOrderHeaders,
                  CarsToEquipment, LoggerOwnershipTransfer. All rows count, deleted ones included.
    Certificate:  MeasurementDevicesCorrections, MeasurementDevicesHumidityCorrections,
                  ConversionParameters. Active rows only. Tables or columns missing on a server
                  are skipped (PROD has neither the humidity table nor ConversionParameters'
                  device column yet).

    Idempotent: a second run finds no MabaID with two active rows and reports nothing.

    Run it with @Apply = 0 first and read the plan. It returns one row per copy:
    KEEP / RETIRE / REFUSED / SKIPPED, with the reason and the reference counts.

    UNDO (all rows of one run share its RemoveDate, printed as RunStamp in the plan):
        UPDATE dbo.MeasurementDevices SET IsDeleted = 0, RemoveDate = NULL
        WHERE IsDeleted = 1 AND RemoveDate = '<RunStamp>';
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

/* MabaIDs to leave untouched in this run, e.g. a fixture kept on purpose. */
DECLARE @SkipMabaIds TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY);
-- INSERT @SkipMabaIds (MabaID) VALUES (N'21-500');

/* Keep this copy instead of the rule's choice. KeepId must be an active copy of that MabaID on
   the server being run, or the run refuses, so an id written for one server cannot reach an
   unrelated row on the other. */
DECLARE @KeepOverride TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY, KeepId INT NOT NULL);
-- INSERT @KeepOverride (MabaID, KeepId) VALUES (N'21-401', 805);

DECLARE @RunStamp DATETIME2(0) = SYSDATETIME();

/* ---- every active copy of a MabaID that has more than one ---------------------------------- */
CREATE TABLE #Copy
(
    ID     INT PRIMARY KEY,
    MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL
);
INSERT #Copy (ID, MabaID)
SELECT md.ID, md.MabaID
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0
  AND md.MabaID IN (SELECT m2.MabaID FROM dbo.MeasurementDevices AS m2
                    WHERE m2.IsDeleted = 0 GROUP BY m2.MabaID HAVING COUNT(*) > 1);

/* ---- where a device id can be referenced ---------------------------------------------------- */
DECLARE @Src TABLE (Tbl SYSNAME, Col SYSNAME, Kind VARCHAR(4), PRIMARY KEY (Tbl, Col));
INSERT @Src (Tbl, Col, Kind) VALUES
    (N'SensorToLoggerRelation',                N'LoggerMeasurementDeviceId', 'link'),
    (N'SensorToLoggerRelation',                N'SensorMeasurementDeviceId', 'link'),
    (N'ChannelsToSensorRelation',              N'LoggerMeasurementDeviceId', 'link'),
    (N'ChannelsToSensorRelation',              N'SensorMeasurementDeviceId', 'link'),
    (N'MeasurmentDeviceToOrderDetailsItems',   N'LoggerMeasurementDeviceId', 'link'),
    (N'MeasurmentDeviceToOrderDetailsItems',   N'SensorMeasurementDeviceId', 'link'),
    (N'MeasurmentPointsToOrderDetailsItems',   N'SensorMeasurementDeviceId', 'link'),
    (N'MeasurmentPointsToCalibrationCycles',   N'SensorMeasurementDeviceId', 'link'),
    (N'MeasurementDevicesToOrderHeaders',      N'MeasurementDeviceId',       'link'),
    (N'CarsToEquipment',                       N'MeasurementDeviceId',       'link'),
    (N'LoggerOwnershipTransfer',               N'LoggerMeasurementDeviceId', 'link'),
    (N'MeasurementDevicesCorrections',         N'MeasurementDevicesId',      'cert'),
    (N'MeasurementDevicesHumidityCorrections', N'MeasurementDevicesId',      'cert'),
    (N'ConversionParameters',                  N'MeasurementDevicesId',      'cert');

/* a foreign key this script does not know about means uncounted references */
DECLARE @UnknownFks NVARCHAR(MAX) =
(
    SELECT STRING_AGG(OBJECT_NAME(fk.parent_object_id) + N'.' + COL_NAME(fkc.parent_object_id, fkc.parent_column_id), N', ')
    FROM sys.foreign_keys AS fk
    JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
    WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.MeasurementDevices')
      AND NOT EXISTS (SELECT 1 FROM @Src AS s
                      WHERE s.Tbl = OBJECT_NAME(fk.parent_object_id)
                        AND s.Col = COL_NAME(fkc.parent_object_id, fkc.parent_column_id))
);

/* ---- count references, and sign each copy's certificate rows -------------------------------- */
CREATE TABLE #Ref (ID INT NOT NULL, Tbl SYSNAME NOT NULL, Kind VARCHAR(4) NOT NULL, N INT NOT NULL);
CREATE TABLE #Sig (ID INT NOT NULL, Tbl SYSNAME NOT NULL, Sig NVARCHAR(100) NOT NULL);

DECLARE @Tbl SYSNAME, @Col SYSNAME, @Kind VARCHAR(4), @Sql NVARCHAR(MAX), @SigCols NVARCHAR(MAX), @Active NVARCHAR(100);
DECLARE src CURSOR LOCAL FAST_FORWARD FOR SELECT Tbl, Col, Kind FROM @Src;
OPEN src;
FETCH NEXT FROM src INTO @Tbl, @Col, @Kind;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF COL_LENGTH(N'dbo.' + @Tbl, @Col) IS NOT NULL
    BEGIN
        SET @Active = CASE WHEN @Kind = 'cert' AND COL_LENGTH(N'dbo.' + @Tbl, N'IsDeleted') IS NOT NULL
                           THEN N' AND x.IsDeleted = 0' ELSE N'' END;

        SET @Sql = N'INSERT #Ref (ID, Tbl, Kind, N) SELECT x.' + QUOTENAME(@Col) + N', @Tbl, @Kind, COUNT(*)
                     FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                     WHERE x.' + QUOTENAME(@Col) + N' IN (SELECT ID FROM #Copy)' + @Active + N'
                     GROUP BY x.' + QUOTENAME(@Col) + N';';
        EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME, @Kind VARCHAR(4)', @Tbl = @Tbl, @Kind = @Kind;

        IF @Kind = 'cert'
        BEGIN
            /* the content columns: not the identity, the device id, dates, the user or the flag */
            SELECT @SigCols = STRING_AGG(N'x.' + QUOTENAME(c.name), N', ') WITHIN GROUP (ORDER BY c.column_id)
            FROM sys.columns AS c
            WHERE c.object_id = OBJECT_ID(N'dbo.' + @Tbl)
              AND c.is_identity = 0
              AND c.name <> @Col
              AND c.name NOT LIKE N'%Date'
              AND c.name NOT IN (N'UpdateUserID', N'IsDeleted');

            SET @Sql = N'INSERT #Sig (ID, Tbl, Sig) SELECT x.' + QUOTENAME(@Col) + N', @Tbl,
                         CONCAT(COUNT(*), N'':'', CHECKSUM_AGG(BINARY_CHECKSUM(' + @SigCols + N')))
                         FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                         WHERE x.' + QUOTENAME(@Col) + N' IN (SELECT ID FROM #Copy)' + @Active + N'
                         GROUP BY x.' + QUOTENAME(@Col) + N';';
            EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME', @Tbl = @Tbl;
        END
    END
    FETCH NEXT FROM src INTO @Tbl, @Col, @Kind;
END
CLOSE src;
DEALLOCATE src;

/* ---- per copy: totals, a readable breakdown, the certificate signature ---------------------- */
CREATE TABLE #Plan
(
    ID        INT PRIMARY KEY,
    MabaID    NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
    HasClass  BIT NOT NULL,
    IsLogger  BIT NOT NULL,
    Links     INT NOT NULL,
    Certs     INT NOT NULL,
    Detail    NVARCHAR(1000) COLLATE DATABASE_DEFAULT NULL,
    CertSig   NVARCHAR(1000) COLLATE DATABASE_DEFAULT NULL,
    IsKeep    BIT NOT NULL DEFAULT 0,
    Action    VARCHAR(10) NULL,
    Reason    NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL
);
INSERT #Plan (ID, MabaID, HasClass, IsLogger, Links, Certs, Detail, CertSig)
SELECT c.ID, c.MabaID,
       IIF(md.MainClassId IS NULL, 0, 1),
       IIF(mc.NameEnglish = N'Data logger', 1, 0),
       ISNULL((SELECT SUM(r.N) FROM #Ref AS r WHERE r.ID = c.ID AND r.Kind = 'link'), 0),
       ISNULL((SELECT SUM(r.N) FROM #Ref AS r WHERE r.ID = c.ID AND r.Kind = 'cert'), 0),
       (SELECT STRING_AGG(CONCAT(r.Tbl, N'=', r.N), N' ') WITHIN GROUP (ORDER BY r.Kind DESC, r.Tbl)
        FROM (SELECT ID, Tbl, Kind, SUM(N) AS N FROM #Ref GROUP BY ID, Tbl, Kind) AS r WHERE r.ID = c.ID),
       (SELECT STRING_AGG(CONCAT(s.Tbl, N'=', s.Sig), N' ') WITHIN GROUP (ORDER BY s.Tbl)
        FROM #Sig AS s WHERE s.ID = c.ID)
FROM #Copy AS c
JOIN dbo.MeasurementDevices AS md ON md.ID = c.ID
LEFT JOIN dbo.MeasurementDevicesMainClasses AS mc ON mc.Id = md.MainClassId;

/* an override that is not an active copy of its MabaID refuses the whole run */
DECLARE @BadOverrides NVARCHAR(MAX) =
(
    SELECT STRING_AGG(CONCAT(o.MabaID, N'->', o.KeepId), N', ')
    FROM @KeepOverride AS o
    WHERE NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.ID = o.KeepId AND p.MabaID = o.MabaID)
);

UPDATE p SET IsKeep = 1
FROM #Plan AS p
JOIN (SELECT p2.ID,
             ROW_NUMBER() OVER (PARTITION BY p2.MabaID
                                ORDER BY IIF(o.KeepId = p2.ID, 0, 1),
                                         IIF(p2.Links > 0, 0, 1),
                                         IIF(p2.Certs > 0, 0, 1),
                                         IIF(p2.HasClass = 1, 0, 1),
                                         p2.ID) AS rn
      FROM #Plan AS p2
      LEFT JOIN @KeepOverride AS o ON o.MabaID = p2.MabaID) AS k ON k.ID = p.ID AND k.rn = 1;

/* refusals, per MabaID */
CREATE TABLE #Refused (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY, Reason NVARCHAR(400) COLLATE DATABASE_DEFAULT);
INSERT #Refused (MabaID, Reason)
SELECT g.MabaID,
       CONCAT_WS(N'; ',
           IIF(g.LinkedCopies > 1, N'links on ' + CAST(g.LinkedCopies AS NVARCHAR(10)) + N' copies', NULL),
           IIF(g.LinkedDrops > 0 AND g.LinkedCopies <= 1, N'links on a copy that would be retired', NULL),
           IIF(g.CertMismatch > 0, N'certificate on a retired copy differs from the kept copy', NULL),
           IIF(g.LoggerDrops > 0, N'a retired copy is the Data logger, the kept copy is not', NULL))
FROM (SELECT p.MabaID,
             SUM(IIF(p.IsKeep = 0 AND p.IsLogger = 1 AND k.IsLogger = 0, 1, 0)) AS LoggerDrops,
             SUM(IIF(p.Links > 0, 1, 0)) AS LinkedCopies,
             SUM(IIF(p.IsKeep = 0 AND p.Links > 0, 1, 0)) AS LinkedDrops,
             SUM(IIF(p.IsKeep = 0 AND p.Certs > 0
                     AND ISNULL(p.CertSig, N'') <> ISNULL(k.CertSig, N''), 1, 0)) AS CertMismatch
      FROM #Plan AS p
      JOIN #Plan AS k ON k.MabaID = p.MabaID AND k.IsKeep = 1
      GROUP BY p.MabaID) AS g
WHERE g.LinkedCopies > 1 OR g.LinkedDrops > 0 OR g.CertMismatch > 0 OR g.LoggerDrops > 0;

UPDATE p SET
    Action = CASE WHEN s.MabaID IS NOT NULL THEN 'SKIPPED'
                  WHEN r.MabaID IS NOT NULL THEN 'REFUSED'
                  WHEN p.IsKeep = 1          THEN 'KEEP'
                  ELSE 'RETIRE' END,
    Reason = CASE WHEN s.MabaID IS NOT NULL THEN N'listed in @SkipMabaIds' + ISNULL(N' (would refuse: ' + r.Reason + N')', N'')
                  WHEN r.MabaID IS NOT NULL THEN r.Reason
                  WHEN p.IsKeep = 1 THEN
                       CASE WHEN EXISTS (SELECT 1 FROM @KeepOverride AS o WHERE o.KeepId = p.ID) THEN N'override'
                            WHEN p.Links > 0 THEN N'has the links'
                            WHEN p.Certs > 0 THEN N'has the certificate'
                            WHEN p.HasClass = 1 THEN N'nothing referenced, the classed copy'
                            ELSE N'nothing referenced, lowest id' END
                  ELSE CONCAT(N'duplicate of ', (SELECT k.ID FROM #Plan AS k WHERE k.MabaID = p.MabaID AND k.IsKeep = 1),
                              IIF(p.Certs > 0, N', identical certificate stays on it', N'')) END
FROM #Plan AS p
LEFT JOIN @SkipMabaIds AS s ON s.MabaID = p.MabaID
LEFT JOIN #Refused AS r ON r.MabaID = p.MabaID;

DECLARE @RefusedGroups INT = (SELECT COUNT(*) FROM #Refused AS r
                              WHERE NOT EXISTS (SELECT 1 FROM @SkipMabaIds AS s WHERE s.MabaID = r.MabaID));
DECLARE @ToRetire INT = (SELECT COUNT(*) FROM #Plan WHERE Action = 'RETIRE');

/* ---- apply ---------------------------------------------------------------------------------- */
IF @Apply = 1
BEGIN
    IF @UnknownFks IS NOT NULL
        THROW 51060, N'Refused: foreign keys to MeasurementDevices this script does not count. Run with @Apply = 0.', 1;
    IF @BadOverrides IS NOT NULL
        THROW 51061, N'Refused: a @KeepOverride id is not an active copy of its MabaID on this server. Run with @Apply = 0.', 1;
    IF @RefusedGroups > 0
        THROW 51062, N'Refused: some MabaIDs have unexpected references. Run with @Apply = 0, then fix, skip or override them.', 1;

    BEGIN TRAN;
        UPDATE md
        SET IsDeleted = 1, RemoveDate = @RunStamp, UpdateDate = @RunStamp
        FROM dbo.MeasurementDevices AS md
        JOIN #Plan AS p ON p.ID = md.ID
        WHERE p.Action = 'RETIRE'
          AND md.IsDeleted = 0;

        IF @@ROWCOUNT <> @ToRetire
            THROW 51063, N'Row count changed between plan and update; rolled back.', 1;
    COMMIT;
END

/* ---- the plan: one row per copy ------------------------------------------------------------- */
SELECT
    CASE WHEN @Apply = 1 THEN 'APPLIED' ELSE 'DRY RUN' END AS Mode,
    CONVERT(VARCHAR(19), @RunStamp, 120) AS RunStamp,
    DB_NAME() AS DatabaseName,
    (SELECT COUNT(DISTINCT MabaID) FROM #Plan) AS DupMabaIds,
    @ToRetire AS ToRetire,
    @RefusedGroups AS RefusedMabaIds,
    ISNULL(@UnknownFks, N'') AS UnknownFks,
    ISNULL(@BadOverrides, N'') AS BadOverrides,
    p.MabaID, p.ID, p.Action, p.Reason, p.Links, p.Certs, ISNULL(p.Detail, N'') AS Detail,
    CONVERT(VARCHAR(16), md.CreateDate, 120) AS CreateDate,
    md.MainClassId, md.Model, md.SerialNumber, md.Description
FROM #Plan AS p
JOIN dbo.MeasurementDevices AS md ON md.ID = p.ID
ORDER BY p.MabaID, IIF(p.IsKeep = 1, 0, 1), p.ID;
