/*
    Plan-RetireDuplicateMeasurementDevices-PROD                                         MBA-1060
    ---------------------------------------------------------------------------------------------
    The plan of database/data/Retire-DuplicateMeasurementDevices.sql as ONE read-only SELECT, so it
    can run through the SELECT-only PROD query helper (no temp tables, no dynamic SQL, no CTE).

    Same rule, same refusals, no @KeepOverride / @SkipMabaIds. It counts only the reference
    tables PROD has today. UnknownFks lists any foreign key to MeasurementDevices outside them.
    If it is not empty, this plan is incomplete: run the real script's dry run instead.

    It is a cross-check, not the thing that writes. Before @Apply = 1 on PROD, run the real
    script with @Apply = 0 there too: its counts must equal this plan's.

    Run (drop this header first; the helper requires the text to start with SELECT):
        $q = (Get-Content -Raw -Encoding UTF8 <this file>) -replace '(?s)^.*?(?=^SELECT)', ''
        & C:\Users\skulas\dev\local-scripts\Invoke-CalibratorProdQuery.ps1 -Query $q
*/
SELECT
    q.MabaID, q.ID,
    CASE WHEN q.Refused = 1 THEN 'REFUSED' WHEN q.ID = q.KeepId THEN 'KEEP' ELSE 'RETIRE' END AS Action,
    CASE WHEN q.Refused = 1 THEN CONCAT_WS(N'; ',
             IIF(q.LinkedCopies > 1, CONCAT(N'links on ', q.LinkedCopies, N' copies'), NULL),
             IIF(q.LinkedDrops > 0 AND q.LinkedCopies <= 1, N'links on a copy that would be retired', NULL),
             IIF(q.CertMismatch > 0, N'certificate on a retired copy differs from the kept copy', NULL),
             IIF(q.LoggerDrops > 0, N'a retired copy is the Data logger, the kept copy is not', NULL))
         WHEN q.ID = q.KeepId THEN
             CASE WHEN q.Links > 0 THEN N'has the links'
                  WHEN q.Certs > 0 THEN N'has the certificate'
                  WHEN q.HasClass = 1 THEN N'nothing referenced, the classed copy'
                  ELSE N'nothing referenced, lowest id' END
         ELSE CONCAT(N'duplicate of ', q.KeepId, IIF(q.Certs > 0, N', identical certificate stays on it', N''))
    END AS Reason,
    q.Links, q.Certs,
    CONCAT_WS(N' ',
        IIF(q.s2l > 0, CONCAT(N'SensorToLoggerRelation=', q.s2l), NULL),
        IIF(q.ch  > 0, CONCAT(N'ChannelsToSensorRelation=', q.ch), NULL),
        IIF(q.odi > 0, CONCAT(N'MeasurmentDeviceToOrderDetailsItems=', q.odi), NULL),
        IIF(q.pts > 0, CONCAT(N'MeasurmentPointsToOrderDetailsItems=', q.pts), NULL),
        IIF(q.cyc > 0, CONCAT(N'MeasurmentPointsToCalibrationCycles=', q.cyc), NULL),
        IIF(q.oh  > 0, CONCAT(N'MeasurementDevicesToOrderHeaders=', q.oh), NULL),
        IIF(q.car > 0, CONCAT(N'CarsToEquipment=', q.car), NULL),
        IIF(q.Certs > 0, CONCAT(N'MeasurementDevicesCorrections=', q.Certs), NULL)) AS Detail,
    CONVERT(VARCHAR(16), q.CreateDate, 120) AS CreateDate,
    q.MainClassId, q.Model, q.SerialNumber,
    SUM(IIF(q.ID = q.KeepId, 1, 0)) OVER () AS DupMabaIds,
    SUM(IIF(q.Refused = 0 AND q.ID <> q.KeepId, 1, 0)) OVER () AS ToRetire,
    ISNULL((SELECT STRING_AGG(OBJECT_NAME(fk.parent_object_id) + N'.' + COL_NAME(fkc.parent_object_id, fkc.parent_column_id), N', ')
            FROM sys.foreign_keys AS fk
            JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
            WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.MeasurementDevices')
              AND OBJECT_NAME(fk.parent_object_id) + N'.' + COL_NAME(fkc.parent_object_id, fkc.parent_column_id) NOT IN (
                  N'SensorToLoggerRelation.LoggerMeasurementDeviceId', N'SensorToLoggerRelation.SensorMeasurementDeviceId',
                  N'MeasurmentDeviceToOrderDetailsItems.LoggerMeasurementDeviceId', N'MeasurmentDeviceToOrderDetailsItems.SensorMeasurementDeviceId',
                  N'MeasurmentPointsToOrderDetailsItems.SensorMeasurementDeviceId', N'MeasurementDevicesToOrderHeaders.MeasurementDeviceId',
                  N'CarsToEquipment.MeasurementDeviceId', N'MeasurementDevicesCorrections.MeasurementDevicesId')), N'') AS UnknownFks
FROM (
    SELECT g.*,
           IIF(g.LinkedCopies > 1 OR g.LinkedDrops > 0 OR g.CertMismatch > 0 OR g.LoggerDrops > 0, 1, 0) AS Refused
    FROM (
        SELECT k.*,
               SUM(IIF(k.ID <> k.KeepId AND k.Links > 0, 1, 0)) OVER (PARTITION BY k.MabaID) AS LinkedDrops,
               SUM(IIF(k.ID <> k.KeepId AND k.Certs > 0 AND ISNULL(k.CertSig, N'') <> ISNULL(k.KeepSig, N''), 1, 0))
                   OVER (PARTITION BY k.MabaID) AS CertMismatch,
               SUM(IIF(k.ID <> k.KeepId AND k.IsLogger = 1 AND k.KeepIsLogger = 0, 1, 0))
                   OVER (PARTITION BY k.MabaID) AS LoggerDrops
        FROM (
            SELECT r.*,
                   SUM(IIF(r.Links > 0, 1, 0)) OVER (PARTITION BY r.MabaID) AS LinkedCopies,
                   FIRST_VALUE(r.ID) OVER (PARTITION BY r.MabaID
                       ORDER BY IIF(r.Links > 0, 0, 1), IIF(r.Certs > 0, 0, 1), IIF(r.HasClass = 1, 0, 1), r.ID
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS KeepId,
                   FIRST_VALUE(r.CertSig) OVER (PARTITION BY r.MabaID
                       ORDER BY IIF(r.Links > 0, 0, 1), IIF(r.Certs > 0, 0, 1), IIF(r.HasClass = 1, 0, 1), r.ID
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS KeepSig,
                   FIRST_VALUE(r.IsLogger) OVER (PARTITION BY r.MabaID
                       ORDER BY IIF(r.Links > 0, 0, 1), IIF(r.Certs > 0, 0, 1), IIF(r.HasClass = 1, 0, 1), r.ID
                       ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS KeepIsLogger
            FROM (
                SELECT md.ID, md.MabaID, md.CreateDate, md.MainClassId, md.Model, md.SerialNumber,
                       IIF(md.MainClassId IS NULL, 0, 1) AS HasClass,
                       IIF(EXISTS (SELECT 1 FROM dbo.MeasurementDevicesMainClasses mc
                                   WHERE mc.Id = md.MainClassId AND mc.NameEnglish = N'Data logger'), 1, 0) AS IsLogger,
                       n.s2l, n.ch, n.odi, n.pts, n.cyc, n.oh, n.car,
                       n.s2l + n.ch + n.odi + n.pts + n.cyc + n.oh + n.car AS Links,
                       n.cor AS Certs,
                       IIF(n.cor > 0, CONCAT(n.cor, N':', n.corSig), NULL) AS CertSig
                FROM dbo.MeasurementDevices AS md
                CROSS APPLY (SELECT
                    (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation x WHERE x.LoggerMeasurementDeviceId = md.ID)
                  + (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation x WHERE x.SensorMeasurementDeviceId = md.ID) AS s2l,
                    (SELECT COUNT(*) FROM dbo.ChannelsToSensorRelation x WHERE x.LoggerMeasurementDeviceId = md.ID)
                  + (SELECT COUNT(*) FROM dbo.ChannelsToSensorRelation x WHERE x.SensorMeasurementDeviceId = md.ID) AS ch,
                    (SELECT COUNT(*) FROM dbo.MeasurmentDeviceToOrderDetailsItems x WHERE x.LoggerMeasurementDeviceId = md.ID)
                  + (SELECT COUNT(*) FROM dbo.MeasurmentDeviceToOrderDetailsItems x WHERE x.SensorMeasurementDeviceId = md.ID) AS odi,
                    (SELECT COUNT(*) FROM dbo.MeasurmentPointsToOrderDetailsItems x WHERE x.SensorMeasurementDeviceId = md.ID) AS pts,
                    (SELECT COUNT(*) FROM dbo.MeasurmentPointsToCalibrationCycles x WHERE x.SensorMeasurementDeviceId = md.ID) AS cyc,
                    (SELECT COUNT(*) FROM dbo.MeasurementDevicesToOrderHeaders x WHERE x.MeasurementDeviceId = md.ID) AS oh,
                    (SELECT COUNT(*) FROM dbo.CarsToEquipment x WHERE x.MeasurementDeviceId = md.ID) AS car,
                    (SELECT COUNT(*) FROM dbo.MeasurementDevicesCorrections x WHERE x.MeasurementDevicesId = md.ID AND x.IsDeleted = 0) AS cor,
                    (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(x.Value1, x.Value2, x.Deviation, x.Note, x.MeasurementId, x.UnitID,
                                                         x.CorVersion, x.MainCategoryId, x.Equation, x.MeasurementDevicesCorrectionsSourceId))
                     FROM dbo.MeasurementDevicesCorrections x WHERE x.MeasurementDevicesId = md.ID AND x.IsDeleted = 0) AS corSig
                ) AS n
                WHERE md.IsDeleted = 0
                  AND md.MabaID IN (SELECT m2.MabaID FROM dbo.MeasurementDevices AS m2
                                    WHERE m2.IsDeleted = 0 GROUP BY m2.MabaID HAVING COUNT(*) > 1)
            ) AS r
        ) AS k
    ) AS g
) AS q
ORDER BY q.MabaID, IIF(q.ID = q.KeepId, 0, 1), q.ID;
