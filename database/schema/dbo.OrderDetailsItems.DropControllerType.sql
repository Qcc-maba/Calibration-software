/*
    dbo.OrderDetailsItems.ControllerType - drop                                             MBA-980
    ---------------------------------------------------------------------------------------------
    The device-level controller type is retired. A chamber can use one controller for heating and
    another for cooling (Nofar, Jira 38264), so the controller is stored per cycle:
    CalibrationCycles.ControllerTypeStatusId / ControllerManufacturer / ControllerModel
    (database/schema/dbo.CalibrationCycles.SummarySettings.sql).

    Why dropping is safe (measured 2026-11-16):
      - PROD: empty on all 10,307 lines. STAGE: 5 test values (3 digital, 2 analog).
      - Only dbo.AssignProductIdentificationData and dbo.GetOrderDetailsDevices referenced it, and
        this change removes it from both (the procedure keeps @ControllerType, accepted and ignored,
        until the app drops the field). No index, statistic, key, default, check, computed column
        or schema-bound object uses it on either server.
      - No screen ever filled it, and no C#, PowerShell or inline SQL reads it.

    Order: deploy the two procedures first.

    Before the drop, the script refuses when anything still uses the column:
      - a module that references it. This uses column-level dependencies, not a text search,
        because SaveCalibrationCycleSettings mentions the ControllerType status category in a
        message. Each module is looked up on its own: one whose references cannot be resolved
        (drift between servers) is reported as a warning instead of stopping the script.
      - an index, a statistic created by hand, a foreign key, a default, a check, a computed
        column, or a schema-bound object.

    During the drop (@Apply = 1, one transaction):
      1. Any non-NULL values are copied to dbo.Backup_OrderDetailsItems_ControllerType_<yyyymmdd>
         for the rollback. Nothing is created when the column is empty (PROD).
      2. The column is dropped.
      3. Every module that references dbo.OrderDetailsItems is refreshed (sp_refreshsqlmodule).
         A module that still uses the column fails here, however it spells the name (dynamic SQL
         aside), and the whole transaction is rolled back.

    @Apply = 0 (default) reports and changes nothing. Replayable: once the column is gone it says
    so and stops.

    Rollback: ALTER TABLE dbo.OrderDetailsItems ADD ControllerType NVARCHAR(40) NULL; copy the
    values back from the backup table (if one was created), and redeploy the previous versions of
    the two procedures.
*/
DECLARE @Apply BIT = 0;

SET NOCOUNT ON;

IF COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NULL
BEGIN
    SELECT Outcome = 'Already dropped';
    RETURN;
END;

DECLARE @ColumnId INT = COLUMNPROPERTY(OBJECT_ID(N'dbo.OrderDetailsItems'), N'ControllerType', 'ColumnId');

/* The values that would be lost (they go to the backup table on @Apply = 1). */
EXEC sys.sp_executesql N'
    SELECT OrderDetailsItemId, OrderDetailId, ControllerType
    FROM dbo.OrderDetailsItems
    WHERE ControllerType IS NOT NULL
    ORDER BY OrderDetailsItemId;';

DECLARE @Blockers TABLE (Blocker NVARCHAR(400) NOT NULL);
DECLARE @Warnings TABLE (Module NVARCHAR(300) NOT NULL, Warning NVARCHAR(4000) NOT NULL);

/* Modules that reference the table: the ones to check now and to refresh after the drop. */
DECLARE @Modules TABLE (ObjectId INT PRIMARY KEY, QualifiedName NVARCHAR(300) NOT NULL);

INSERT @Modules (ObjectId, QualifiedName)
SELECT DISTINCT m.object_id, QUOTENAME(OBJECT_SCHEMA_NAME(m.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(m.object_id))
FROM sys.sql_expression_dependencies AS d
JOIN sys.sql_modules AS m ON m.object_id = d.referencing_id
WHERE d.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems');

/* 1. Modules that use the column, looked up one at a time. */
DECLARE @Name NVARCHAR(300);
DECLARE ModuleCursor CURSOR LOCAL FAST_FORWARD FOR SELECT QualifiedName FROM @Modules ORDER BY QualifiedName;
OPEN ModuleCursor;
FETCH NEXT FROM ModuleCursor INTO @Name;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1
                   FROM sys.dm_sql_referenced_entities(@Name, N'OBJECT') AS r
                   WHERE r.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems')
                     AND r.referenced_minor_name COLLATE DATABASE_DEFAULT = N'ControllerType')
            INSERT @Blockers VALUES (N'module ' + @Name);
    END TRY
    BEGIN CATCH
        INSERT @Warnings VALUES (@Name, N'references could not be resolved: ' + ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM ModuleCursor INTO @Name;
END;
CLOSE ModuleCursor;
DEALLOCATE ModuleCursor;

/* 2. Objects that make DROP COLUMN fail. */
INSERT @Blockers (Blocker)
SELECT N'index ' + i.name
FROM sys.index_columns AS ic
JOIN sys.indexes AS i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE ic.object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND ic.column_id = @ColumnId
UNION ALL
SELECT N'statistic ' + s.name
FROM sys.stats_columns AS sc
JOIN sys.stats AS s ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id
WHERE sc.object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND sc.column_id = @ColumnId
  AND s.user_created = 1
UNION ALL
SELECT N'foreign key ' + OBJECT_NAME(fkc.constraint_object_id)
FROM sys.foreign_key_columns AS fkc
WHERE (fkc.parent_object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND fkc.parent_column_id = @ColumnId)
   OR (fkc.referenced_object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND fkc.referenced_column_id = @ColumnId)
UNION ALL
SELECT N'default ' + dc.name
FROM sys.default_constraints AS dc
WHERE dc.parent_object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND dc.parent_column_id = @ColumnId
UNION ALL
SELECT N'check ' + cc.name
FROM sys.check_constraints AS cc
WHERE cc.parent_object_id = OBJECT_ID(N'dbo.OrderDetailsItems')
  AND (cc.parent_column_id = @ColumnId OR cc.definition LIKE N'%ControllerType%')
UNION ALL
SELECT N'computed column ' + c.name
FROM sys.computed_columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND c.definition LIKE N'%ControllerType%'
UNION ALL
SELECT N'schema-bound ' + OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id)
FROM sys.sql_expression_dependencies AS d
WHERE d.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems')
  AND d.is_schema_bound_reference = 1
  AND d.referenced_minor_id = @ColumnId;

IF EXISTS (SELECT 1 FROM @Warnings)
    SELECT Module, Warning FROM @Warnings ORDER BY Module;

IF EXISTS (SELECT 1 FROM @Blockers)
BEGIN
    SELECT StillUsedBy = Blocker FROM @Blockers ORDER BY Blocker;
    THROW 51000, 'OrderDetailsItems.ControllerType is still in use (listed above). Deploy the MBA-980 versions of AssignProductIdentificationData and GetOrderDetailsDevices first.', 1;
END;

IF @Apply = 0
BEGIN
    SELECT Outcome = 'Would drop OrderDetailsItems.ControllerType (dry run, nothing changed)';
    RETURN;
END;

/* ---- Apply ---------------------------------------------------------------------------------- */
DECLARE @BackupName SYSNAME = N'Backup_OrderDetailsItems_ControllerType_' + CONVERT(NCHAR(8), GETDATE(), 112);
DECLARE @Sql NVARCHAR(MAX);
DECLARE @Refreshed INT = 0;
DECLARE @Broken TABLE (Module NVARCHAR(300) NOT NULL, Error NVARCHAR(4000) NOT NULL);

BEGIN TRY
    BEGIN TRAN;

    /* 1. Backup, only when there is something to keep. */
    DECLARE @HasValues BIT;
    EXEC sys.sp_executesql
         N'SELECT @HasValues = IIF(EXISTS (SELECT 1 FROM dbo.OrderDetailsItems WHERE ControllerType IS NOT NULL), 1, 0);',
         N'@HasValues BIT OUTPUT', @HasValues = @HasValues OUTPUT;

    IF @HasValues = 1
    BEGIN
        IF OBJECT_ID(N'dbo.' + @BackupName, N'U') IS NOT NULL
            THROW 51000, 'The backup table for today already exists; check it before running again.', 1;

        SET @Sql = N'SELECT OrderDetailsItemId, OrderDetailId, ControllerType, BackedUpAt = SYSDATETIME()
                     INTO dbo.' + QUOTENAME(@BackupName) + N'
                     FROM dbo.OrderDetailsItems
                     WHERE ControllerType IS NOT NULL;';
        EXEC sys.sp_executesql @Sql;
    END;

    /* 2. Drop. */
    EXEC sys.sp_executesql N'ALTER TABLE dbo.OrderDetailsItems DROP COLUMN ControllerType;';

    /* 3. Refresh every module that references the table; one that still uses the column fails. */
    DECLARE RefreshCursor CURSOR LOCAL FAST_FORWARD FOR SELECT QualifiedName FROM @Modules ORDER BY QualifiedName;
    OPEN RefreshCursor;
    FETCH NEXT FROM RefreshCursor INTO @Name;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC sys.sp_refreshsqlmodule @name = @Name;
            SET @Refreshed += 1;
        END TRY
        BEGIN CATCH
            INSERT @Broken VALUES (@Name, ERROR_MESSAGE());
            IF XACT_STATE() = -1 BREAK;   -- the transaction can no longer commit
        END CATCH;
        FETCH NEXT FROM RefreshCursor INTO @Name;
    END;
    CLOSE RefreshCursor;
    DEALLOCATE RefreshCursor;

    IF EXISTS (SELECT 1 FROM @Broken)
    BEGIN
        IF XACT_STATE() <> 0 ROLLBACK;
        SELECT Module, Error FROM @Broken ORDER BY Module;
        THROW 51000, 'A module failed to refresh after the drop (listed above); everything was rolled back.', 1;
    END;

    IF COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NOT NULL
        THROW 51000, 'Drop did not take effect.', 1;

    COMMIT;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    THROW;
END CATCH;

SELECT Outcome = 'Dropped OrderDetailsItems.ControllerType',
       ModulesRefreshed = @Refreshed,
       BackupTable = IIF(@HasValues = 1, N'dbo.' + @BackupName, N'(none, the column was empty)');
GO
