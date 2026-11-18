/*
    etl schema - retire                                                                    MBA-1001
    ---------------------------------------------------------------------------------------------
    The etl schema belongs to an old AWS -> on-prem sync: rows were loaded into etl.* and merged
    into dbo.*. It is dead and it confuses the schema gate (dbo.Cars vs etl.Cars, MBA-999).

    Why dropping is safe (measured 2026-11-18, both servers):
      - Every etl table holds 0 rows.
      - No module outside these objects references them (sys.sql_modules text search; the only
        hits are two comments naming the repo file DBA/sql/02_usp_SyncHealthCheck.sql). No foreign
        key, synonym or trigger touches the schema.
      - No SQL Agent job step references etl, and the hourly StartSyncMasterToAWS.dtsx runs only
        AgentsWaitingListToAWS, DepartmentDelaysToAWS, MeasurmentDevicesSyncToAWS and
        OrdersSyncToAWS (read by the user as sa from msdb and SSISDB, Jira 38308). The
        *AWSToOnPrem packages that loaded etl are still deployed but never run.
      - None of these procedures is in the plan cache on either database.

    What it drops:
      - the etl procedures: CalibGetDataLogGetSet, Merge{Users,Cars,CalendarEvents,
        CalendarEventsToParticipants}ToOnPrem, and on PROD usp_SyncRun{Start,End,Report};
      - stg.MergeCarsToOnPrem (duplicate of the etl one, dead code per DBA/CALIBRATOR-SYNC-PLAN.md);
      - dbo.usp_SyncHealthCheck (PROD only, reads etl.SyncRunLog);
      - every etl table, then the schema itself (its EXECUTE grant to ed goes with it).
    @KeepSyncMonitoring = 1 leaves etl.SyncRunLog, etl.usp_SyncRun* and dbo.usp_SyncHealthCheck in
    place, and with them the schema. Those exist on PROD only, so the flag changes nothing on STAGE.

    Before dropping, the script refuses when:
      - @Database is not the current database (the SSMS-tab guard from MBA-999);
      - an etl table it would drop has rows;
      - a module or foreign key it does not drop still references one it does.

    @Apply = 0 (default) reports the plan and changes nothing. @Apply = 1 drops everything in one
    transaction. Replayable: once the objects are gone it reports so and stops.

    Rollback: database/_rollback/STAGE.etl.before-MBA-1001.sql or PROD.etl.before-MBA-1001.sql,
    run against the same database.
*/
DECLARE @Database           SYSNAME = NULL;   -- N'Calibrator' (STAGE) or N'CalibratorProd' (PROD)
DECLARE @KeepSyncMonitoring BIT     = 0;
DECLARE @Apply              BIT     = 0;

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @Database IS NULL OR @Database <> DB_NAME()
BEGIN
    DECLARE @WrongDb NVARCHAR(300) = CONCAT(N'Stopped, nothing changed: @Database is ', COALESCE(@Database, N'NULL'),
                                            N' but the current database is ', DB_NAME(), N'.');
    THROW 50000, @WrongDb, 1;
END;

/* The objects to drop. */
DECLARE @Targets TABLE (
    ObjectId      INT PRIMARY KEY,
    QualifiedName NVARCHAR(300) NOT NULL,
    Kind          CHAR(2)       NOT NULL,   -- P or U
    RowsHeld      BIGINT        NULL
);

INSERT @Targets (ObjectId, QualifiedName, Kind, RowsHeld)
SELECT o.object_id,
       QUOTENAME(s.name) + N'.' + QUOTENAME(o.name),
       o.type,
       CASE WHEN o.type = 'U' THEN (SELECT SUM(p.rows) FROM sys.partitions AS p
                                    WHERE p.object_id = o.object_id AND p.index_id IN (0, 1)) END
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'U')
  AND (   s.name = N'etl'
       OR (s.name = N'stg' AND o.name = N'MergeCarsToOnPrem')
       OR (s.name = N'dbo' AND o.name = N'usp_SyncHealthCheck'))
  AND NOT (@KeepSyncMonitoring = 1 AND (
              (s.name = N'etl' AND o.name IN (N'SyncRunLog', N'usp_SyncRunStart', N'usp_SyncRunEnd', N'usp_SyncRunReport'))
           OR (s.name = N'dbo' AND o.name = N'usp_SyncHealthCheck')));

IF NOT EXISTS (SELECT 1 FROM @Targets)
BEGIN
    IF SCHEMA_ID(N'etl') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id = SCHEMA_ID(N'etl'))
       AND @Apply = 1
    BEGIN
        DROP SCHEMA etl;
        SELECT Outcome = 'Objects already gone; empty etl schema dropped';
        RETURN;
    END;
    SELECT Outcome = CASE WHEN SCHEMA_ID(N'etl') IS NULL THEN 'Already retired'
                          ELSE 'Nothing left to drop (etl schema kept: it still holds objects or @Apply = 0)' END;
    RETURN;
END;

/* Blockers. */
DECLARE @Blockers TABLE (Blocker NVARCHAR(600) NOT NULL);

INSERT @Blockers (Blocker)
SELECT CONCAT(N'Table ', QualifiedName, N' holds ', RowsHeld, N' rows')
FROM @Targets WHERE Kind = 'U' AND RowsHeld > 0;

INSERT @Blockers (Blocker)
SELECT DISTINCT CONCAT(N'Module ', QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id)), N'.', QUOTENAME(OBJECT_NAME(d.referencing_id)),
                       N' references ', t.QualifiedName)
FROM sys.sql_expression_dependencies AS d
JOIN @Targets AS t ON t.ObjectId = d.referenced_id
WHERE d.referencing_id NOT IN (SELECT ObjectId FROM @Targets);

/* By name too: a reference to a kept etl object from a dropped one is fine, the reverse is not. */
INSERT @Blockers (Blocker)
SELECT DISTINCT CONCAT(N'Module ', QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id)), N'.', QUOTENAME(OBJECT_NAME(d.referencing_id)),
                       N' references etl.', d.referenced_entity_name, N' by name')
FROM sys.sql_expression_dependencies AS d
WHERE d.referenced_schema_name = N'etl'
  AND d.referenced_id IS NULL
  AND d.referencing_id NOT IN (SELECT ObjectId FROM @Targets)
  AND OBJECT_SCHEMA_NAME(d.referencing_id) <> N'etl';

INSERT @Blockers (Blocker)
SELECT CONCAT(N'Foreign key ', fk.name, N' on ', QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)), N'.',
              QUOTENAME(OBJECT_NAME(fk.parent_object_id)), N' references ', t.QualifiedName)
FROM sys.foreign_keys AS fk
JOIN @Targets AS t ON t.ObjectId = fk.referenced_object_id
WHERE fk.parent_object_id NOT IN (SELECT ObjectId FROM @Targets);

/* The plan. */
SELECT Step = ROW_NUMBER() OVER (ORDER BY CASE Kind WHEN 'P' THEN 1 ELSE 2 END, QualifiedName),
       Action = CASE Kind WHEN 'P' THEN N'DROP PROCEDURE ' ELSE N'DROP TABLE ' END + QualifiedName,
       RowsHeld
FROM @Targets
ORDER BY Step;

DECLARE @SchemaWillBeEmpty BIT =
    CASE WHEN EXISTS (SELECT 1 FROM sys.objects AS o
                      WHERE o.schema_id = SCHEMA_ID(N'etl') AND o.parent_object_id = 0
                        AND o.object_id NOT IN (SELECT ObjectId FROM @Targets))
         THEN 0 ELSE 1 END;

SELECT DatabaseName = DB_NAME(),
       KeepSyncMonitoring = @KeepSyncMonitoring,
       ProceduresToDrop = (SELECT COUNT(*) FROM @Targets WHERE Kind = 'P'),
       TablesToDrop     = (SELECT COUNT(*) FROM @Targets WHERE Kind = 'U'),
       DropSchema       = @SchemaWillBeEmpty,
       Blockers         = (SELECT COUNT(*) FROM @Blockers),
       Mode             = CASE @Apply WHEN 1 THEN 'APPLY' ELSE 'DRY RUN - nothing changed' END;

IF EXISTS (SELECT 1 FROM @Blockers)
BEGIN
    SELECT Blocker FROM @Blockers ORDER BY Blocker;
    THROW 50001, 'Stopped, nothing changed: something still uses the objects to drop (see the Blocker rows).', 1;
END;

IF @Apply = 0 RETURN;

/* Drop: procedures first, then tables, then the schema. */
DECLARE @Sql NVARCHAR(MAX) = N'';
SELECT @Sql += N'DROP PROCEDURE ' + QualifiedName + N';' + CHAR(10) FROM @Targets WHERE Kind = 'P';
SELECT @Sql += N'DROP TABLE '     + QualifiedName + N';' + CHAR(10) FROM @Targets WHERE Kind = 'U';

BEGIN TRANSACTION;
    EXEC sys.sp_executesql @Sql;
    IF @SchemaWillBeEmpty = 1 EXEC (N'DROP SCHEMA etl;');
COMMIT;

SELECT Outcome = 'Dropped',
       EtlObjectsLeft = (SELECT COUNT(*) FROM sys.objects WHERE schema_id = SCHEMA_ID(N'etl')),
       EtlSchemaExists = CASE WHEN SCHEMA_ID(N'etl') IS NULL THEN 0 ELSE 1 END;
