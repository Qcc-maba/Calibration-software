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
    copy (850: 4 sensor-logger, 35 channel, 9 order-item rows; 849: 1 / 10 / 3). 21-675's real
    sensor 740 is referenced by everything, while 796/832 are copies of 18-172 (34401A U536140116)
    that were later re-keyed to 21-675 through the equipment edit screen. Corrections were copied
    identically onto every copy of 21-242 (19 rows), 21-260 (182) and 21-401 (9) by
    stg.MergeMeasurementDevicesCorrection, which joins on MabaID. STAGE's set (10-30, 21-500,
    21-540, 21-675) is test rows re-keyed or created in the UI.

    THE RULE, per MabaID with more than one active row:
      keep   = the copy with link rows, else the copy with certificate rows, else a copy that has
               a MainClassId, else the lowest ID;
      retire = every other copy: IsDeleted = 1, RemoveDate = UpdateDate = one shared timestamp.
    The class step is not cosmetic. The VCT server resolves a logger with
    "MabaID = @MabaID AND MainClassId = 7 AND IsDeleted = 0" (CalibratorDeviceConfigFromDb), and
    the logger pickers require class 'Data logger'. On PROD only the third load's copy has class 7,
    so "oldest when nothing is referenced" would have kept the unclassed copy of 31 loggers, and
    those loggers would have vanished from every station. Among the Jan-load copies MainClassId
    is the only column that differs, so keeping the classed one loses nothing.
    Child rows are NOT touched, except for the MabaIDs listed in @MoveLinksMabaIds below.

    A MabaID is REFUSED, and @Apply = 1 does nothing at all, when:
      - link rows sit on more than one copy (someone has to decide which one is real), or
      - a copy that would be retired has link rows, or
      - a copy that would be retired has certificate rows that differ from the kept copy's
        (count + checksum of every certificate table, ignoring ids, dates and the user), or
      - a copy that would be retired is classed 'Data logger' and the kept copy is not.
    The run also refuses outright when a foreign key to MeasurementDevices comes from a table this
    script does not know about, since its rows would not have been counted.

    DECIDED PER MabaID (2026-11-26, after reading the refused groups; MabaIDs, so they are stable):
      @MoveLinksMabaIds  - keep by the rule WITHOUT the links step (certificate, class, lowest id)
                           and repoint the link rows of the retired copies onto the kept one.
          PROD  21-422 (TTI-22): its 2 order points (test entries: serial 1234, channel 99,
                Sept 2026) sit on unclassed 807; the Data logger copy 879 is kept and gets them.
          STAGE 21-500: the Hart PT-100 691 (certificate, coefficients, 20 points) is kept and
                gets the 1 point of test record 4645 ("test third"; not an MBA-831 fixture -
                Save-Lab-Sensor-Coefficients.sql calls it a test record and works around it).
      @RetireDifferingCertMabaIds - retire even though the retired copy has its own certificate;
                           those correction rows stay on the retired copy, dormant.
          STAGE 21-675: 4653 ("check", created 2026-09-24) has a 6-range test curve from
                2026-10-06; the real sensor 801 keeps its own 35 rows.
      @RescueCertMabaIds - move a certificate stranded on a copy retired before this run.
          STAGE 21-260: 182 corrections on 622 (retired by MBA-902, 2026-08-25), active 810 has none.
      @SkipMabaIds - leave alone. None today.
    The lists are filled per database below, so a tab on the other database cannot apply them.

    Link tables:  SensorToLoggerRelation, ChannelsToSensorRelation (no FK),
                  MeasurmentDeviceToOrderDetailsItems, MeasurmentPointsToOrderDetailsItems,
                  MeasurmentPointsToCalibrationCycles (no FK), MeasurementDevicesToOrderHeaders,
                  CarsToEquipment, LoggerOwnershipTransfer. All rows count, deleted ones included.
    Certificate:  MeasurementDevicesCorrections, MeasurementDevicesHumidityCorrections,
                  ConversionParameters. Active rows only. Tables or columns missing on a server
                  are skipped (PROD has neither the humidity table nor ConversionParameters'
                  device column yet).

    STRANDED CERTIFICATES: for a MabaID of this run's duplicate groups, or one listed in
    @RescueCertMabaIds, when the one surviving active copy has no rows in a certificate table and
    exactly one retired copy (retired earlier, or by this run) has some, those rows move to the
    surviving copy (MOVE CERT rows in the plan). Never for any other MabaID: a number reused after
    its device was deleted must not inherit the old device's certificate. The readers skip retired devices, so
    otherwise the certificate is lost to the station. STAGE 2026-11-26: 21-260's 182 corrections
    sit on 622, retired by MBA-902's merge, while the active 810 has none. PROD: none. Two retired
    copies with rows for the same table refuse the MabaID instead.

    Idempotent: a second run finds no MabaID with two active rows and reports nothing.

    Run it with @Apply = 0 first and read the plan. It returns one row per copy:
    KEEP / RETIRE / REFUSED / SKIPPED, the reason, the reference counts, and in Moves the primary
    keys of every link row that @Apply = 1 repoints.

    UNDO (all rows of one run share its RemoveDate, printed as RunStamp in the plan):
        UPDATE dbo.MeasurementDevices SET IsDeleted = 0, RemoveDate = NULL
        WHERE IsDeleted = 1 AND RemoveDate = '<RunStamp>';
    and, for a moved link or certificate row, set its column back to the old id, using the keys
    listed in Moves.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

DECLARE @SkipMabaIds                TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY);
DECLARE @MoveLinksMabaIds           TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY);
DECLARE @RetireDifferingCertMabaIds TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY);
DECLARE @RescueCertMabaIds          TABLE (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY);

IF DB_NAME() = N'CalibratorProd'
BEGIN
    INSERT @MoveLinksMabaIds (MabaID) VALUES (N'21-422');
END
ELSE IF DB_NAME() = N'Calibrator'
BEGIN
    INSERT @MoveLinksMabaIds (MabaID) VALUES (N'21-500');
    INSERT @RetireDifferingCertMabaIds (MabaID) VALUES (N'21-675');
    INSERT @RescueCertMabaIds (MabaID) VALUES (N'21-260');
END

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
CREATE TABLE #Ref (ID INT NOT NULL, Tbl SYSNAME NOT NULL, Col SYSNAME NOT NULL, Kind VARCHAR(4) NOT NULL, N INT NOT NULL);
CREATE TABLE #Sig (ID INT NOT NULL, Tbl SYSNAME NOT NULL, Sig NVARCHAR(100) NOT NULL);

DECLARE @Tbl SYSNAME, @Col SYSNAME, @Kind VARCHAR(4), @Sql NVARCHAR(MAX), @SigCols NVARCHAR(MAX), @Active NVARCHAR(100), @Pk SYSNAME;
DECLARE src CURSOR LOCAL FAST_FORWARD FOR SELECT Tbl, Col, Kind FROM @Src;
OPEN src;
FETCH NEXT FROM src INTO @Tbl, @Col, @Kind;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF COL_LENGTH(N'dbo.' + @Tbl, @Col) IS NOT NULL
    BEGIN
        SET @Active = CASE WHEN @Kind = 'cert' AND COL_LENGTH(N'dbo.' + @Tbl, N'IsDeleted') IS NOT NULL
                           THEN N' AND x.IsDeleted = 0' ELSE N'' END;

        SET @Sql = N'INSERT #Ref (ID, Tbl, Col, Kind, N) SELECT x.' + QUOTENAME(@Col) + N', @Tbl, @Col, @Kind, COUNT(*)
                     FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                     WHERE x.' + QUOTENAME(@Col) + N' IN (SELECT ID FROM #Copy)' + @Active + N'
                     GROUP BY x.' + QUOTENAME(@Col) + N';';
        EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME, @Col SYSNAME, @Kind VARCHAR(4)', @Tbl = @Tbl, @Col = @Col, @Kind = @Kind;

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
    MoveLinks BIT NOT NULL,
    Links     INT NOT NULL,
    Certs     INT NOT NULL,
    Detail    NVARCHAR(1000) COLLATE DATABASE_DEFAULT NULL,
    CertSig   NVARCHAR(1000) COLLATE DATABASE_DEFAULT NULL,
    IsKeep    BIT NOT NULL DEFAULT 0,
    Action    VARCHAR(10) NULL,
    Reason    NVARCHAR(400) COLLATE DATABASE_DEFAULT NULL,
    Moves     NVARCHAR(2000) COLLATE DATABASE_DEFAULT NULL
);
INSERT #Plan (ID, MabaID, HasClass, IsLogger, MoveLinks, Links, Certs, Detail, CertSig)
SELECT c.ID, c.MabaID,
       IIF(md.MainClassId IS NULL, 0, 1),
       IIF(mc.NameEnglish = N'Data logger', 1, 0),
       IIF(EXISTS (SELECT 1 FROM @MoveLinksMabaIds AS ml WHERE ml.MabaID = c.MabaID), 1, 0),
       ISNULL((SELECT SUM(r.N) FROM #Ref AS r WHERE r.ID = c.ID AND r.Kind = 'link'), 0),
       ISNULL((SELECT SUM(r.N) FROM #Ref AS r WHERE r.ID = c.ID AND r.Kind = 'cert'), 0),
       (SELECT STRING_AGG(CONCAT(r.Tbl, N'=', r.N), N' ') WITHIN GROUP (ORDER BY r.Kind DESC, r.Tbl)
        FROM (SELECT ID, Tbl, Kind, SUM(N) AS N FROM #Ref GROUP BY ID, Tbl, Kind) AS r WHERE r.ID = c.ID),
       (SELECT STRING_AGG(CONCAT(s.Tbl, N'=', s.Sig), N' ') WITHIN GROUP (ORDER BY s.Tbl)
        FROM #Sig AS s WHERE s.ID = c.ID)
FROM #Copy AS c
JOIN dbo.MeasurementDevices AS md ON md.ID = c.ID
LEFT JOIN dbo.MeasurementDevicesMainClasses AS mc ON mc.Id = md.MainClassId;

UPDATE p SET IsKeep = 1
FROM #Plan AS p
JOIN (SELECT p2.ID,
             ROW_NUMBER() OVER (PARTITION BY p2.MabaID
                                ORDER BY IIF(p2.MoveLinks = 0 AND p2.Links > 0, 0, 1),
                                         IIF(p2.Certs > 0, 0, 1),
                                         IIF(p2.HasClass = 1, 0, 1),
                                         p2.ID) AS rn
      FROM #Plan AS p2) AS k ON k.ID = p.ID AND k.rn = 1;

/* refusals, per MabaID */
CREATE TABLE #Refused (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY, Reason NVARCHAR(400) COLLATE DATABASE_DEFAULT);
INSERT #Refused (MabaID, Reason)
SELECT g.MabaID,
       CONCAT_WS(N'; ',
           IIF(g.MoveLinks = 0 AND g.LinkedCopies > 1, N'links on ' + CAST(g.LinkedCopies AS NVARCHAR(10)) + N' copies', NULL),
           IIF(g.MoveLinks = 0 AND g.LinkedDrops > 0 AND g.LinkedCopies <= 1, N'links on a copy that would be retired', NULL),
           IIF(g.CertMismatch > 0, N'certificate on a retired copy differs from the kept copy', NULL),
           IIF(g.LoggerDrops > 0, N'a retired copy is the Data logger, the kept copy is not', NULL))
FROM (SELECT p.MabaID,
             MAX(CAST(p.MoveLinks AS INT)) AS MoveLinks,
             SUM(IIF(p.IsKeep = 0 AND p.IsLogger = 1 AND k.IsLogger = 0, 1, 0)) AS LoggerDrops,
             SUM(IIF(p.Links > 0, 1, 0)) AS LinkedCopies,
             SUM(IIF(p.IsKeep = 0 AND p.Links > 0, 1, 0)) AS LinkedDrops,
             SUM(IIF(p.IsKeep = 0 AND p.Certs > 0
                     AND ISNULL(p.CertSig, N'') <> ISNULL(k.CertSig, N'')
                     AND rd.MabaID IS NULL, 1, 0)) AS CertMismatch
      FROM #Plan AS p
      JOIN #Plan AS k ON k.MabaID = p.MabaID AND k.IsKeep = 1
      LEFT JOIN @RetireDifferingCertMabaIds AS rd ON rd.MabaID = p.MabaID
      GROUP BY p.MabaID) AS g
WHERE (g.MoveLinks = 0 AND (g.LinkedCopies > 1 OR g.LinkedDrops > 0)) OR g.CertMismatch > 0 OR g.LoggerDrops > 0;

UPDATE p SET
    Action = CASE WHEN s.MabaID IS NOT NULL THEN 'SKIPPED'
                  WHEN r.MabaID IS NOT NULL THEN 'REFUSED'
                  WHEN p.IsKeep = 1          THEN 'KEEP'
                  ELSE 'RETIRE' END,
    Reason = CASE WHEN s.MabaID IS NOT NULL THEN N'listed in @SkipMabaIds' + ISNULL(N' (would refuse: ' + r.Reason + N')', N'')
                  WHEN r.MabaID IS NOT NULL THEN r.Reason
                  WHEN p.IsKeep = 1 THEN
                       CASE WHEN p.MoveLinks = 0 AND p.Links > 0 THEN N'has the links'
                            WHEN p.Certs > 0 THEN N'has the certificate'
                            WHEN p.HasClass = 1 THEN N'the classed copy'
                            ELSE N'nothing referenced, lowest id' END
                       + IIF(p.MoveLinks = 1, N'; receives the retired copies'' links', N'')
                  ELSE CONCAT(N'duplicate of ', (SELECT k.ID FROM #Plan AS k WHERE k.MabaID = p.MabaID AND k.IsKeep = 1),
                              CASE WHEN p.Certs = 0 THEN N''
                                   WHEN EXISTS (SELECT 1 FROM @RetireDifferingCertMabaIds AS rd WHERE rd.MabaID = p.MabaID)
                                        AND ISNULL(p.CertSig, N'') <> ISNULL((SELECT k.CertSig FROM #Plan AS k WHERE k.MabaID = p.MabaID AND k.IsKeep = 1), N'')
                                        THEN N', its own certificate stays on it, dormant'
                                   ELSE N', identical certificate stays on it' END,
                              IIF(p.MoveLinks = 1 AND p.Links > 0, N', links move to the kept copy', N'')) END
FROM #Plan AS p
LEFT JOIN @SkipMabaIds AS s ON s.MabaID = p.MabaID
LEFT JOIN #Refused AS r ON r.MabaID = p.MabaID;

/* ---- the link rows to repoint: retired copies of @MoveLinksMabaIds groups ---------------------
   Their primary keys are listed in the plan (Moves), so a move can be undone row by row. */
CREATE TABLE #Move (DropId INT PRIMARY KEY, KeepId INT NOT NULL);
INSERT #Move (DropId, KeepId)
SELECT p.ID, k.ID
FROM #Plan AS p
JOIN #Plan AS k ON k.MabaID = p.MabaID AND k.IsKeep = 1
WHERE p.Action = 'RETIRE' AND p.MoveLinks = 1 AND p.Links > 0;

CREATE TABLE #Moved (Tbl SYSNAME NOT NULL, Col SYSNAME NOT NULL, DropId INT NOT NULL, KeepId INT NOT NULL, N INT NOT NULL, Pks NVARCHAR(MAX) NULL);
DECLARE mv CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT r.Tbl, r.Col FROM #Ref AS r JOIN #Move AS m ON m.DropId = r.ID WHERE r.Kind = 'link';
OPEN mv;
FETCH NEXT FROM mv INTO @Tbl, @Col;
WHILE @@FETCH_STATUS = 0
BEGIN
    /* the row's key for the undo list: a single-column primary key, else the identity column */
    SET @Pk = COALESCE(
              (SELECT TOP (1) COL_NAME(ic.object_id, ic.column_id)
               FROM sys.indexes AS i
               JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
               WHERE i.object_id = OBJECT_ID(N'dbo.' + @Tbl) AND i.is_primary_key = 1
                 AND (SELECT COUNT(*) FROM sys.index_columns AS c2
                      WHERE c2.object_id = i.object_id AND c2.index_id = i.index_id) = 1),
              (SELECT TOP (1) c.name FROM sys.columns AS c
               WHERE c.object_id = OBJECT_ID(N'dbo.' + @Tbl) AND c.is_identity = 1));

    SET @Sql = N'INSERT #Moved (Tbl, Col, DropId, KeepId, N, Pks)
                 SELECT @Tbl, @Col, m.DropId, m.KeepId, COUNT(*), '
             + CASE WHEN @Pk IS NULL THEN N'NULL'
                    ELSE N'STRING_AGG(CAST(x.' + QUOTENAME(@Pk) + N' AS NVARCHAR(MAX)), N'','')' END + N'
                 FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                 JOIN #Move AS m ON m.DropId = x.' + QUOTENAME(@Col) + N'
                 GROUP BY m.DropId, m.KeepId;';
    EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME, @Col SYSNAME', @Tbl = @Tbl, @Col = @Col;

    FETCH NEXT FROM mv INTO @Tbl, @Col;
END
CLOSE mv;
DEALLOCATE mv;

UPDATE p SET Moves = (SELECT STRING_AGG(CONCAT(mv.Tbl, N'.', mv.Col, N' [', ISNULL(mv.Pks, CONCAT(mv.N, N' rows')), N'] -> ', mv.KeepId), N'; ')
                      FROM #Moved AS mv WHERE mv.DropId = p.ID)
FROM #Plan AS p;

/* ---- certificates stranded on a retired copy -------------------------------------------------
   A MabaID of this run's duplicate groups, or listed in @RescueCertMabaIds, whose one surviving
   active copy has no rows in a certificate table, while a retired copy (retired earlier, or by
   this run) has some: those rows move to the surviving copy.
   Otherwise the certificate is unreachable, because the readers skip retired devices
   (dbo.GetMeasurementDevicesCorrections since MBA-1060). Found on STAGE: 21-260's 182 corrections
   sit on 622, which MBA-902's merge retired on 2026-08-25, while the active 810 has none.
   When two retired copies both have rows for that table, nothing moves and the MabaID is refused. */
CREATE TABLE #Survivor (MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT PRIMARY KEY, ID INT NOT NULL);
INSERT #Survivor (MabaID, ID)
SELECT md.MabaID, MIN(md.ID)
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0
  AND NOT EXISTS (SELECT 1 FROM #Plan AS p WHERE p.ID = md.ID AND p.Action = 'RETIRE')
  /* only this run's duplicate groups, and MabaIDs named on purpose: a number reused after its old
     device was deleted (CreateEquipmentRecord allows that) must never inherit the old certificate */
  AND (md.MabaID IN (SELECT MabaID FROM #Plan) OR md.MabaID IN (SELECT MabaID FROM @RescueCertMabaIds))
GROUP BY md.MabaID
HAVING COUNT(*) = 1;

CREATE TABLE #CertMove (Tbl SYSNAME NOT NULL, Col SYSNAME NOT NULL, MabaID NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
                        FromId INT NOT NULL, ToId INT NOT NULL, N INT NOT NULL, Pks NVARCHAR(MAX) NULL, Ambiguous BIT NOT NULL DEFAULT 0);
DECLARE cm CURSOR LOCAL FAST_FORWARD FOR SELECT Tbl, Col FROM @Src WHERE Kind = 'cert';
OPEN cm;
FETCH NEXT FROM cm INTO @Tbl, @Col;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF COL_LENGTH(N'dbo.' + @Tbl, @Col) IS NOT NULL
    BEGIN
        SET @Active = CASE WHEN COL_LENGTH(N'dbo.' + @Tbl, N'IsDeleted') IS NOT NULL THEN N' AND x.IsDeleted = 0' ELSE N'' END;
        SET @Pk = COALESCE(
                  (SELECT TOP (1) COL_NAME(ic.object_id, ic.column_id)
                   FROM sys.indexes AS i
                   JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
                   WHERE i.object_id = OBJECT_ID(N'dbo.' + @Tbl) AND i.is_primary_key = 1
                     AND (SELECT COUNT(*) FROM sys.index_columns AS c2
                          WHERE c2.object_id = i.object_id AND c2.index_id = i.index_id) = 1),
                  (SELECT TOP (1) c.name FROM sys.columns AS c
                   WHERE c.object_id = OBJECT_ID(N'dbo.' + @Tbl) AND c.is_identity = 1));

        SET @Sql = N'INSERT #CertMove (Tbl, Col, MabaID, FromId, ToId, N, Pks)
                     SELECT @Tbl, @Col, s.MabaID, d.ID, s.ID, COUNT(*), '
                 + CASE WHEN @Pk IS NULL THEN N'NULL'
                        ELSE N'STRING_AGG(CAST(x.' + QUOTENAME(@Pk) + N' AS NVARCHAR(MAX)), N'','')' END + N'
                     FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                     JOIN dbo.MeasurementDevices AS d ON d.ID = x.' + QUOTENAME(@Col) + N'
                     JOIN #Survivor AS s ON s.MabaID = d.MabaID AND s.ID <> d.ID
                     WHERE (d.IsDeleted = 1 OR EXISTS (SELECT 1 FROM #Plan AS p WHERE p.ID = d.ID AND p.Action = ''RETIRE''))' + @Active + N'
                       AND NOT EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@Tbl) + N' AS y
                                       WHERE y.' + QUOTENAME(@Col) + N' = s.ID' + REPLACE(@Active, N'x.', N'y.') + N')
                     GROUP BY s.MabaID, d.ID, s.ID;';
        EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME, @Col SYSNAME', @Tbl = @Tbl, @Col = @Col;
    END
    FETCH NEXT FROM cm INTO @Tbl, @Col;
END
CLOSE cm;
DEALLOCATE cm;

UPDATE c SET Ambiguous = 1
FROM #CertMove AS c
WHERE (SELECT COUNT(*) FROM #CertMove AS c2 WHERE c2.Tbl = c.Tbl AND c2.MabaID = c.MabaID) > 1;

DECLARE @RefusedGroups INT = (SELECT COUNT(*) FROM #Refused AS r
                              WHERE NOT EXISTS (SELECT 1 FROM @SkipMabaIds AS s WHERE s.MabaID = r.MabaID))
                           + (SELECT COUNT(DISTINCT MabaID) FROM #CertMove WHERE Ambiguous = 1);
DECLARE @ToRetire INT = (SELECT COUNT(*) FROM #Plan WHERE Action = 'RETIRE');
DECLARE @ToMove INT = ISNULL((SELECT SUM(N) FROM #Moved), 0);
DECLARE @CertsToMove INT = ISNULL((SELECT SUM(N) FROM #CertMove WHERE Ambiguous = 0), 0);

/* ---- apply ---------------------------------------------------------------------------------- */
IF @Apply = 1
BEGIN
    IF @UnknownFks IS NOT NULL
        THROW 51060, N'Refused: foreign keys to MeasurementDevices this script does not count. Run with @Apply = 0.', 1;
    IF @RefusedGroups > 0
        THROW 51062, N'Refused: some MabaIDs have unexpected references. Run with @Apply = 0 and read the REFUSED rows.', 1;

    DECLARE @Moved INT = 0, @n INT;

    BEGIN TRAN;
        DECLARE ap CURSOR LOCAL FAST_FORWARD FOR SELECT DISTINCT Tbl, Col FROM #Moved;
        OPEN ap;
        FETCH NEXT FROM ap INTO @Tbl, @Col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Sql = N'UPDATE x SET ' + QUOTENAME(@Col) + N' = m.KeepId
                         FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                         JOIN #Move AS m ON m.DropId = x.' + QUOTENAME(@Col) + N';
                         SET @n = @@ROWCOUNT;';
            EXEC sys.sp_executesql @Sql, N'@n INT OUTPUT', @n = @n OUTPUT;
            SET @Moved += @n;
            FETCH NEXT FROM ap INTO @Tbl, @Col;
        END
        CLOSE ap;
        DEALLOCATE ap;

        IF @Moved <> @ToMove
            THROW 51064, N'Moved link count changed between plan and update; rolled back.', 1;

        SET @Moved = 0;
        DECLARE ac CURSOR LOCAL FAST_FORWARD FOR SELECT DISTINCT Tbl, Col FROM #CertMove WHERE Ambiguous = 0;
        OPEN ac;
        FETCH NEXT FROM ac INTO @Tbl, @Col;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Active = CASE WHEN COL_LENGTH(N'dbo.' + @Tbl, N'IsDeleted') IS NOT NULL THEN N' AND x.IsDeleted = 0' ELSE N'' END;
            SET @Sql = N'UPDATE x SET ' + QUOTENAME(@Col) + N' = c.ToId
                         FROM dbo.' + QUOTENAME(@Tbl) + N' AS x
                         JOIN #CertMove AS c ON c.FromId = x.' + QUOTENAME(@Col) + N' AND c.Tbl = @Tbl AND c.Col = @Col AND c.Ambiguous = 0
                         WHERE 1 = 1' + @Active + N';
                         SET @n = @@ROWCOUNT;';
            EXEC sys.sp_executesql @Sql, N'@Tbl SYSNAME, @Col SYSNAME, @n INT OUTPUT', @Tbl = @Tbl, @Col = @Col, @n = @n OUTPUT;
            SET @Moved += @n;
            FETCH NEXT FROM ac INTO @Tbl, @Col;
        END
        CLOSE ac;
        DEALLOCATE ac;

        IF @Moved <> @CertsToMove
            THROW 51065, N'Moved certificate row count changed between plan and update; rolled back.', 1;

        UPDATE md
        SET IsDeleted = 1, RemoveDate = @RunStamp, UpdateDate = @RunStamp
        FROM dbo.MeasurementDevices AS md
        JOIN #Plan AS p ON p.ID = md.ID
        WHERE p.Action = 'RETIRE'
          AND md.IsDeleted = 0;

        IF @@ROWCOUNT <> @ToRetire
            THROW 51063, N'Retired row count changed between plan and update; rolled back.', 1;
    COMMIT;
END

/* ---- the plan: one row per copy, then one row per stranded certificate ---------------------- */
SELECT
    CASE WHEN @Apply = 1 THEN 'APPLIED' ELSE 'DRY RUN' END AS Mode,
    CONVERT(VARCHAR(19), @RunStamp, 120) AS RunStamp,
    DB_NAME() AS DatabaseName,
    (SELECT COUNT(DISTINCT MabaID) FROM #Plan) AS DupMabaIds,
    @ToRetire AS ToRetire,
    @ToMove AS LinksToMove,
    @CertsToMove AS CertRowsToMove,
    @RefusedGroups AS RefusedMabaIds,
    ISNULL(@UnknownFks, N'') AS UnknownFks,
    r.MabaID, r.ID, r.Action, r.Reason, r.Links, r.Certs, r.Detail, r.Moves,
    CONVERT(VARCHAR(16), md.CreateDate, 120) AS CreateDate,
    md.MainClassId, md.Model, md.SerialNumber, md.Description
FROM (
    SELECT p.MabaID, p.ID, p.Action, p.Reason, p.Links, p.Certs, ISNULL(p.Detail, N'') AS Detail, ISNULL(p.Moves, N'') AS Moves,
           0 AS Part, IIF(p.IsKeep = 1, 0, 1) AS Ord
    FROM #Plan AS p
    UNION ALL
    SELECT c.MabaID, c.FromId,
           IIF(c.Ambiguous = 1, 'REFUSED', 'MOVE CERT'),
           IIF(c.Ambiguous = 1,
               CONCAT(N'certificate rows on more than one retired copy, active ', c.ToId, N' has none: decide by hand'),
               CONCAT(N'certificate stranded on retired copy; active ', c.ToId, N' has none in ', c.Tbl)) COLLATE DATABASE_DEFAULT,
           0, c.N, N'',
           CONCAT(c.Tbl, N'.', c.Col, N' [', ISNULL(c.Pks, CONCAT(c.N, N' rows')), N'] -> ', c.ToId) COLLATE DATABASE_DEFAULT,
           1, 0
    FROM #CertMove AS c
) AS r
JOIN dbo.MeasurementDevices AS md ON md.ID = r.ID
ORDER BY r.Part, r.MabaID, r.Ord, r.ID;
