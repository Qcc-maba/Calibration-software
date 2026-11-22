/*
    etl schema - retire                                                                    MBA-1001
    ---------------------------------------------------------------------------------------------
    The etl schema belongs to an old AWS -> on-prem sync: rows were loaded into etl.* and merged
    into dbo.*. It is dead and it confuses the schema gate (dbo.Cars vs etl.Cars, MBA-999).
    Applied on STAGE 2026-11-18. PROD keeps its etl objects for now (MBA-1050, due 2027-05-22).

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
      - every etl procedure: CalibGetDataLogGetSet, Merge{Users,Cars,CalendarEvents,
        CalendarEventsToParticipants}ToOnPrem, and on PROD usp_SyncRun{Start,End,Report};
      - stg.MergeCarsToOnPrem (duplicate of the etl one, dead code per DBA/CALIBRATOR-SYNC-PLAN.md);
      - every etl table, then the schema itself (its EXECUTE grant to ed goes with it).
    It does NOT drop dbo.usp_SyncHealthCheck (PROD only). Despite its name it reads only dbo.* and
    stg.stg_* tables, never etl, so it is a working read-only diagnostic and outside this change.
    @KeepSyncMonitoring = 1 leaves etl.SyncRunLog and etl.usp_SyncRun* in place, and with them the
    schema. Those exist on PROD only, so the flag changes nothing on STAGE.

    Before dropping, the script refuses when:
      - @Database is not the current database (the SSMS-tab guard from MBA-999);
      - an etl table it would drop has rows (approximate count here, exact count under an exclusive
        table lock inside the drop transaction);
      - a module or foreign key it does not drop still references one it does, by id or by name;
      - etl holds anything it does not handle (a view, function, synonym, sequence, type or XML
        schema collection), since the schema could then not be dropped as promised.

    @Apply = 0 (default) reports the plan and changes nothing. @Apply = 1 drops everything in one
    transaction: foreign keys between the tables first, then procedures, tables and the schema.
    Replayable: once the objects are gone it reports so and stops.

    Rollback: database/_rollback/STAGE.etl.before-MBA-1001.sql or PROD.etl.before-MBA-1001.sql,
    run against the same database (both tested on a scratch database 2026-11-22).
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

DECLARE @EtlSchemaId INT = SCHEMA_ID(N'etl');

/* The sync-monitoring objects @KeepSyncMonitoring = 1 leaves alone. */
DECLARE @Kept TABLE (ObjectId INT PRIMARY KEY);
IF @KeepSyncMonitoring = 1
    INSERT @Kept (ObjectId)
    SELECT o.object_id FROM sys.objects AS o
    WHERE o.schema_id = @EtlSchemaId
      AND o.name IN (N'SyncRunLog', N'usp_SyncRunStart', N'usp_SyncRunEnd', N'usp_SyncRunReport');

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
  AND (s.name = N'etl' OR (s.name = N'stg' AND o.name = N'MergeCarsToOnPrem'))
  AND o.object_id NOT IN (SELECT ObjectId FROM @Kept);

/* Anything else in etl that this script does not drop. Constraints and other child objects go with
   their table, so only top-level objects count. Kept sync monitoring is expected; the rest blocks. */
DECLARE @Unhandled TABLE (Item NVARCHAR(400) NOT NULL);

INSERT @Unhandled (Item)
SELECT CONCAT(o.type_desc COLLATE DATABASE_DEFAULT, N' etl.', o.name)
FROM sys.objects AS o
WHERE o.schema_id = @EtlSchemaId
  AND o.parent_object_id = 0
  AND o.object_id NOT IN (SELECT ObjectId FROM @Targets)
  AND o.object_id NOT IN (SELECT ObjectId FROM @Kept);

INSERT @Unhandled (Item)
SELECT CONCAT(N'TYPE etl.', t.name) FROM sys.types AS t WHERE t.schema_id = @EtlSchemaId AND t.is_user_defined = 1;

INSERT @Unhandled (Item)
SELECT CONCAT(N'XML SCHEMA COLLECTION etl.', x.name) FROM sys.xml_schema_collections AS x WHERE x.schema_id = @EtlSchemaId;

DECLARE @SchemaWillBeEmpty BIT =
    CASE WHEN @EtlSchemaId IS NULL OR EXISTS (SELECT 1 FROM @Kept) OR EXISTS (SELECT 1 FROM @Unhandled)
         THEN 0 ELSE 1 END;

IF NOT EXISTS (SELECT 1 FROM @Targets)
BEGIN
    IF EXISTS (SELECT 1 FROM @Unhandled)
    BEGIN
        SELECT Blocker = N'etl holds ' + Item + N', which this script does not drop' FROM @Unhandled ORDER BY Item;
        THROW 50002, 'Stopped, nothing changed: the etl schema holds objects this script does not handle (see the Blocker rows).', 1;
    END;
    IF @SchemaWillBeEmpty = 1 AND @Apply = 1
    BEGIN
        EXEC (N'DROP SCHEMA etl;');
        SELECT Outcome = 'Objects already gone; empty etl schema dropped';
        RETURN;
    END;
    SELECT Outcome = CASE WHEN @EtlSchemaId IS NULL THEN 'Already retired'
                          WHEN EXISTS (SELECT 1 FROM @Kept) THEN 'Nothing left to drop (etl schema kept for the sync monitoring)'
                          ELSE 'Nothing left to drop; the empty etl schema is dropped on @Apply = 1' END;
    RETURN;
END;

/* Blockers. */
DECLARE @Blockers TABLE (Blocker NVARCHAR(600) NOT NULL);

INSERT @Blockers (Blocker)
SELECT CONCAT(N'Table ', QualifiedName, N' holds about ', RowsHeld, N' rows')
FROM @Targets WHERE Kind = 'U' AND RowsHeld > 0;

INSERT @Blockers (Blocker)
SELECT N'etl holds ' + Item + N', which this script does not drop' FROM @Unhandled;

/* Referenced by id. referencing_class 1 = objects; a database DDL trigger (class 12) has no schema,
   so name it from sys.triggers. */
INSERT @Blockers (Blocker)
SELECT DISTINCT CONCAT(N'Module ',
                       COALESCE(QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id)) + N'.' + QUOTENAME(OBJECT_NAME(d.referencing_id)),
                                N'(database trigger) ' + (SELECT tr.name FROM sys.triggers AS tr WHERE tr.object_id = d.referencing_id)),
                       N' references ', t.QualifiedName)
FROM sys.sql_expression_dependencies AS d
JOIN @Targets AS t ON t.ObjectId = d.referenced_id
WHERE d.referencing_id NOT IN (SELECT ObjectId FROM @Targets)
  AND NOT EXISTS (SELECT 1 FROM sys.objects AS c   -- a constraint or trigger of a dropped table goes with it
                  WHERE c.object_id = d.referencing_id AND c.parent_object_id IN (SELECT ObjectId FROM @Targets));

/* Referenced by name only (unresolved), from anything that is not itself being dropped - kept etl
   modules included, since they would be broken afterwards. */
INSERT @Blockers (Blocker)
SELECT DISTINCT CONCAT(N'Module ',
                       COALESCE(QUOTENAME(OBJECT_SCHEMA_NAME(d.referencing_id)) + N'.' + QUOTENAME(OBJECT_NAME(d.referencing_id)),
                                N'(database trigger) ' + (SELECT tr.name FROM sys.triggers AS tr WHERE tr.object_id = d.referencing_id)),
                       N' references etl.', d.referenced_entity_name, N' by name')
FROM sys.sql_expression_dependencies AS d
WHERE d.referenced_schema_name = N'etl'
  AND d.referenced_id IS NULL
  AND d.referencing_id NOT IN (SELECT ObjectId FROM @Targets)
  AND NOT EXISTS (SELECT 1 FROM sys.objects AS c   -- a constraint or trigger of a dropped table goes with it
                  WHERE c.object_id = d.referencing_id AND c.parent_object_id IN (SELECT ObjectId FROM @Targets));

INSERT @Blockers (Blocker)
SELECT CONCAT(N'Foreign key ', fk.name, N' on ', QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)), N'.',
              QUOTENAME(OBJECT_NAME(fk.parent_object_id)), N' references ', t.QualifiedName)
FROM sys.foreign_keys AS fk
JOIN @Targets AS t ON t.ObjectId = fk.referenced_object_id
WHERE fk.parent_object_id NOT IN (SELECT ObjectId FROM @Targets);

/* Foreign keys between two tables that are both dropped: removed first, so the drop order does not matter. */
DECLARE @InnerFks TABLE (Statement NVARCHAR(800) NOT NULL);
INSERT @InnerFks (Statement)
SELECT N'ALTER TABLE ' + tp.QualifiedName + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys AS fk
JOIN @Targets AS tp ON tp.ObjectId = fk.parent_object_id
JOIN @Targets AS tr ON tr.ObjectId = fk.referenced_object_id;

/* The plan. */
SELECT Step = ROW_NUMBER() OVER (ORDER BY SortKey, Action), Action, RowsHeld
FROM (
    SELECT 0 AS SortKey, Statement AS Action, CAST(NULL AS BIGINT) AS RowsHeld FROM @InnerFks
    UNION ALL
    SELECT CASE Kind WHEN 'P' THEN 1 ELSE 2 END,
           CASE Kind WHEN 'P' THEN N'DROP PROCEDURE ' ELSE N'DROP TABLE ' END + QualifiedName,
           RowsHeld
    FROM @Targets
    UNION ALL
    SELECT 3, N'DROP SCHEMA etl', NULL WHERE @SchemaWillBeEmpty = 1
) AS plan_rows
ORDER BY Step;

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

/* Exact emptiness check, taken under an exclusive lock held to the end of the transaction, so no row
   can arrive between the check and the drop. sys.partitions above is only an estimate. */
DECLARE @Lock NVARCHAR(MAX) = N'';
SELECT @Lock += N'IF EXISTS (SELECT 1 FROM ' + QualifiedName + N' WITH (TABLOCKX, HOLDLOCK)) '
              + N'THROW 50003, N''Stopped, nothing changed: ' + REPLACE(QualifiedName, N'''', N'''''') + N' holds rows.'', 1;' + CHAR(10)
FROM @Targets WHERE Kind = 'U';

DECLARE @Sql NVARCHAR(MAX) = N'';
SELECT @Sql += Statement + CHAR(10) FROM @InnerFks;
SELECT @Sql += N'DROP PROCEDURE ' + QualifiedName + N';' + CHAR(10) FROM @Targets WHERE Kind = 'P';
SELECT @Sql += N'DROP TABLE '     + QualifiedName + N';' + CHAR(10) FROM @Targets WHERE Kind = 'U';

BEGIN TRANSACTION;
    EXEC sys.sp_executesql @Lock;
    EXEC sys.sp_executesql @Sql;
    IF @SchemaWillBeEmpty = 1 EXEC (N'DROP SCHEMA etl;');
COMMIT;

SELECT Outcome = CASE WHEN SCHEMA_ID(N'etl') IS NULL THEN 'Dropped, etl schema gone'
                      ELSE 'Dropped; etl schema kept for the sync monitoring' END,
       EtlObjectsLeft = (SELECT COUNT(*) FROM sys.objects WHERE schema_id = SCHEMA_ID(N'etl'));
