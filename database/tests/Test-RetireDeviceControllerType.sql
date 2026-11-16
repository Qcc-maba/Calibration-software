/*
    Test-RetireDeviceControllerType                                                         MBA-980
    ---------------------------------------------------------------------------------------------
    Read-only. Checks that the device-level controller type is fully retired:
      1. dbo.OrderDetailsItems has no ControllerType column.
      2. dbo.AssignProductIdentificationData has no @ControllerType parameter.
      3. dbo.GetOrderDetailsDevices returns no ControllerType column.
      4. No module references OrderDetailsItems.ControllerType.
    The saving path itself is covered by Test-AssignProductIdentificationHumidity.sql and
    Test-AssignProductIdentificationSerialSync.sql, which run AssignProductIdentificationData.
*/
SET NOCOUNT ON;

DECLARE @Results TABLE (Step NVARCHAR(10), Result NVARCHAR(4), Detail NVARCHAR(400));

INSERT @Results
SELECT N'1', IIF(COL_LENGTH('dbo.OrderDetailsItems', 'ControllerType') IS NULL, N'PASS', N'FAIL'),
       N'OrderDetailsItems.ControllerType is gone';

INSERT @Results
SELECT N'2',
       IIF(EXISTS (SELECT 1 FROM sys.parameters
                   WHERE object_id = OBJECT_ID(N'dbo.AssignProductIdentificationData')
                     AND name = N'@ControllerType'), N'FAIL', N'PASS'),
       N'AssignProductIdentificationData has no @ControllerType';

INSERT @Results
SELECT N'3',
       IIF(EXISTS (SELECT 1
                   FROM sys.dm_exec_describe_first_result_set_for_object(
                            OBJECT_ID(N'dbo.GetOrderDetailsDevices'), 0)
                   WHERE name COLLATE DATABASE_DEFAULT = N'ControllerType'), N'FAIL', N'PASS'),
       N'GetOrderDetailsDevices returns no ControllerType';

INSERT @Results
SELECT N'4',
       /* Code, not comments: no module takes the parameter, and none names the bracketed column
          the way the two procedures did (odi.[ControllerType], ,[ControllerType]). */
       IIF(EXISTS (SELECT 1 FROM sys.parameters WHERE name = N'@ControllerType')
           OR EXISTS (SELECT 1 FROM sys.sql_modules
                      WHERE definition LIKE N'%odi.[[]ControllerType]%'
                         OR definition LIKE N'%,[[]ControllerType]%'
                         OR definition LIKE N'%[[]ControllerType] =%'), N'FAIL', N'PASS'),
       N'no module still names the old column or parameter';

SELECT * FROM @Results ORDER BY Step;

IF EXISTS (SELECT 1 FROM @Results WHERE Result = N'FAIL')
    THROW 51000, 'Test-RetireDeviceControllerType: at least one step failed.', 1;
