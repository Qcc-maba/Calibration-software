/*
    Test-RetireDeviceControllerType                                         MBA-980   Writes and rolls back.
    ---------------------------------------------------------------------------------------------
    Checks that the device-level controller type is retired:
      1. dbo.OrderDetailsItems has no ControllerType column.
      2. dbo.AssignProductIdentificationData still accepts @ControllerType and ignores it, so an app
         that sends a value keeps saving the page (until the app drops the field, Jira 38267).
      3. dbo.GetOrderDetailsDevices can be described and returns no ControllerType column.
      4. Every module that references dbo.OrderDetailsItems still compiles (sp_refreshsqlmodule):
         a module that still uses the column fails here, however it spells the name.
    Steps 2 and 4 run inside a transaction that is rolled back.
    The rest of the save path is covered by Test-AssignProductIdentificationHumidity.sql and
    Test-AssignProductIdentificationSerialSync.sql.

    Run on STAGE:
        Invoke-CalibratorStageSqlFile.ps1 -Path database\tests\Test-RetireDeviceControllerType.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;   -- steps 2 and 4 catch errors and report them

DECLARE @Results TABLE (Step NVARCHAR(10), Result NVARCHAR(4), Detail NVARCHAR(4000));

/* 1 */
INSERT @Results
SELECT N'1', IIF(COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NULL, N'PASS', N'FAIL'),
       N'OrderDetailsItems.ControllerType is gone';

/* 2. A save that sends @ControllerType succeeds. */
DECLARE @UserEmail NVARCHAR(50) = N'ezequiel_lo@mba.co.il';
DECLARE @ItemId INT, @DetailId INT;
SELECT TOP 1 @ItemId = i.OrderDetailsItemId, @DetailId = i.OrderDetailId
FROM dbo.OrderDetailsItems AS i
JOIN dbo.OrderDetails AS od ON od.OrderDetailId = i.OrderDetailId
WHERE od.OrderWorkPlanId IS NOT NULL
ORDER BY i.OrderDetailsItemId DESC;

DECLARE @Ignore TABLE (OrderDetailsItemId INT);

BEGIN TRAN;
BEGIN TRY
    INSERT INTO @Ignore
    EXEC dbo.AssignProductIdentificationData
         @UserEmail = @UserEmail, @OrderDetailId = @DetailId, @OrderDetailsItemId = @ItemId,
         @ControllerType = N'Digital';
    INSERT @Results VALUES (N'2', N'PASS', CONCAT(N'save with @ControllerType accepted (item ', @ItemId, N')'));
END TRY
BEGIN CATCH
    INSERT @Results VALUES (N'2', N'FAIL', CONCAT(N'item ', @ItemId, N': ', ERROR_MESSAGE()));
END CATCH;
IF XACT_STATE() <> 0 ROLLBACK;

/* 3. GetOrderDetailsDevices: describable, and no ControllerType. An undescribable procedure returns
      one row with error_number set and name NULL, which must not count as a pass. */
DECLARE @DescribeError NVARCHAR(4000), @Columns INT, @Controller INT;
SELECT @DescribeError = MAX(CONCAT(error_number, N': ', error_message)) FROM sys.dm_exec_describe_first_result_set(
        N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0) WHERE error_number IS NOT NULL;
SELECT @Columns = COUNT(*),
       @Controller = SUM(IIF(name COLLATE DATABASE_DEFAULT = N'ControllerType', 1, 0))
FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 1', NULL, 0)
WHERE error_number IS NULL;

INSERT @Results
SELECT N'3',
       IIF(@DescribeError IS NULL AND @Columns > 0 AND @Controller = 0, N'PASS', N'FAIL'),
       COALESCE(N'describe failed: ' + @DescribeError,
                CONCAT(@Columns, N' columns, ', @Controller, N' named ControllerType'));

/* 4. Every module that references the table still compiles. */
DECLARE @Broken TABLE (Module NVARCHAR(300), Error NVARCHAR(4000));
DECLARE @Checked INT = 0, @Name NVARCHAR(300);

DECLARE ModuleCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT QUOTENAME(OBJECT_SCHEMA_NAME(m.object_id)) + N'.' + QUOTENAME(OBJECT_NAME(m.object_id))
    FROM sys.sql_expression_dependencies AS d
    JOIN sys.sql_modules AS m ON m.object_id = d.referencing_id
    WHERE d.referenced_id = OBJECT_ID(N'dbo.OrderDetailsItems');

BEGIN TRAN;
OPEN ModuleCursor;
FETCH NEXT FROM ModuleCursor INTO @Name;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC sys.sp_refreshsqlmodule @name = @Name;
    END TRY
    BEGIN CATCH
        INSERT @Broken VALUES (@Name, ERROR_MESSAGE());
        IF XACT_STATE() = -1 BREAK;
    END CATCH;
    SET @Checked += 1;
    FETCH NEXT FROM ModuleCursor INTO @Name;
END;
CLOSE ModuleCursor;
DEALLOCATE ModuleCursor;
IF XACT_STATE() <> 0 ROLLBACK;

INSERT @Results
SELECT N'4',
       IIF(NOT EXISTS (SELECT 1 FROM @Broken) AND @Checked > 0, N'PASS', N'FAIL'),
       ISNULL((SELECT TOP 1 Module + N': ' + Error FROM @Broken ORDER BY Module),
              CONCAT(@Checked, N' modules that reference OrderDetailsItems compile'));

SELECT * FROM @Results ORDER BY Step;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = N'FAIL')
    THROW 51000, 'Test-RetireDeviceControllerType: at least one step failed.', 1;
