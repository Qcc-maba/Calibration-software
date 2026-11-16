/*
    dbo.OrderDetailsItems.ControllerType - drop                                             MBA-980
    ---------------------------------------------------------------------------------------------
    The device-level controller type is retired. A chamber can use one controller for heating and
    another for cooling (Nofar, Jira 38264), so the controller is stored per cycle:
    CalibrationCycles.ControllerTypeStatusId / ControllerManufacturer / ControllerModel
    (database/schema/dbo.CalibrationCycles.SummarySettings.sql).

    Why dropping is safe (measured 2026-11-16):
      - PROD: empty on all 10,307 lines. STAGE: 5 test values (3 digital, 2 analog), listed by the
        dry run below so they are on record.
      - Only dbo.AssignProductIdentificationData and dbo.GetOrderDetailsDevices referenced it, and
        this change removes it from both. No index, default or check uses it.
      - No screen ever filled it; the app router leaves out null parameters, so no caller sent
        @ControllerType. No C#, PowerShell or inline SQL reads it.

    Order: deploy the two procedures first. This script refuses while any module still references
    the column (column-level dependencies, not a text search: SaveCalibrationCycleSettings mentions
    the ControllerType status category in a message).

    @Apply = 0 (default) reports and changes nothing. @Apply = 1 drops the column. Replayable: once
    the column is gone it reports that and stops.

    Rollback: ALTER TABLE dbo.OrderDetailsItems ADD ControllerType NVARCHAR(40) NULL; then restore
    the values the dry run listed, and redeploy the previous versions of the two procedures.
*/
DECLARE @Apply BIT = 0;

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NULL
BEGIN
    SELECT Outcome = 'Already dropped';
    RETURN;
END;

/* The values that would be lost. */
EXEC sys.sp_executesql N'
    SELECT OrderDetailsItemId, OrderDetailId, ControllerType
    FROM dbo.OrderDetailsItems
    WHERE ControllerType IS NOT NULL
    ORDER BY OrderDetailsItemId;';

/* Modules that still use the column. */
DECLARE @Referencing TABLE (ObjectName NVARCHAR(300) NOT NULL);

INSERT @Referencing (ObjectName)
SELECT DISTINCT OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id)
FROM sys.sql_expression_dependencies AS d
CROSS APPLY sys.dm_sql_referenced_entities(
        OBJECT_SCHEMA_NAME(d.referencing_id) + N'.' + OBJECT_NAME(d.referencing_id), N'OBJECT') AS r
WHERE d.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems')
  AND r.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems')
  AND r.referenced_minor_name COLLATE DATABASE_DEFAULT = N'ControllerType';

/* Indexes and constraints on the column. */
INSERT @Referencing (ObjectName)
SELECT N'index ' + i.name
FROM sys.index_columns AS ic
JOIN sys.indexes AS i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE c.object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND c.name = N'ControllerType'
UNION ALL
SELECT N'default ' + dc.name
FROM sys.default_constraints AS dc
JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE c.object_id = OBJECT_ID(N'dbo.OrderDetailsItems') AND c.name = N'ControllerType'
UNION ALL
SELECT N'check ' + cc.name
FROM sys.check_constraints AS cc
WHERE cc.parent_object_id = OBJECT_ID(N'dbo.OrderDetailsItems')
  AND cc.definition LIKE N'%ControllerType%';

IF EXISTS (SELECT 1 FROM @Referencing)
BEGIN
    SELECT StillReferencedBy = ObjectName FROM @Referencing ORDER BY ObjectName;
    THROW 51000, 'OrderDetailsItems.ControllerType is still referenced (listed above). Deploy the MBA-980 versions of AssignProductIdentificationData and GetOrderDetailsDevices first.', 1;
END;

IF @Apply = 0
BEGIN
    SELECT Outcome = 'Would drop OrderDetailsItems.ControllerType (dry run, nothing changed)';
    RETURN;
END;

EXEC sys.sp_executesql N'ALTER TABLE dbo.OrderDetailsItems DROP COLUMN ControllerType;';

IF COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NOT NULL
    THROW 51000, 'Drop did not take effect.', 1;

SELECT Outcome = 'Dropped OrderDetailsItems.ControllerType';
GO
