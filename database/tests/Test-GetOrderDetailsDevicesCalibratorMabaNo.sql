/*
    Test - GetOrderDetailsDevices returns the stored MABA No to a calibrator without a prefix (MBA-1002)
    Run on STAGE with Invoke-CalibratorStageSqlFile.ps1. Reads only; nothing is written.
    Anything other than 'PASS' in Result is a failure.

    For a calibrator, the procedure builds the MABA No from the work-plan assignment's prefix
    (CalibratorsToWorkPlan.OrderDetailsMbaReportNumber). With no prefix it used to return a bare row
    number ('1', '2'), which page 1 then saved over the device's real MABA No.
        T1  a calibrator on a work plan they are NOT assigned to -> every device shows its stored MABA No
        T2  a calibrator assigned with NO prefix                -> every device shows its stored MABA No
    The prefix case itself is unchanged and is not asserted here.
*/
SET NOCOUNT ON;

-- Capture table shaped like the procedure's result, so the test does not break when a column is added.
-- INSERT ... EXEC fills by position; the procedure returns ProductLocation twice, so repeated names get
-- their ordinal appended.
DECLARE @Cols NVARCHAR(MAX) = (
    SELECT STRING_AGG(CAST(QUOTENAME(CASE WHEN d.Dups > 1 THEN CONCAT(d.name, N'_', d.column_ordinal) ELSE d.name END)
                           + N' ' + d.system_type_name + N' NULL' AS NVARCHAR(MAX)), N', ')
           WITHIN GROUP (ORDER BY d.column_ordinal)
    FROM (SELECT name, column_ordinal, system_type_name, COUNT(*) OVER (PARTITION BY name) AS Dups
          FROM sys.dm_exec_describe_first_result_set(N'EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = 0', NULL, 0)
          WHERE name IS NOT NULL) d);
CREATE TABLE #Out (Dummy INT NULL);
EXEC (N'ALTER TABLE #Out ADD ' + @Cols);
ALTER TABLE #Out DROP COLUMN Dummy;

DECLARE @Results TABLE (Test NVARCHAR(80), Calibrator NVARCHAR(255), WorkPlan INT, Devices INT, Wrong INT, Example NVARCHAR(200), Result NVARCHAR(40));
DECLARE @T INT = 1, @Email NVARCHAR(255), @Wp INT, @Sql NVARCHAR(MAX);

WHILE @T <= 2
BEGIN
    SELECT @Email = NULL, @Wp = NULL;
    IF @T = 1
        SELECT TOP 1 @Email = u.Email,
               @Wp = (SELECT MAX(od.OrderWorkPlanId)
                      FROM dbo.OrderDetails od JOIN dbo.OrderDetailsItems i ON i.OrderDetailId = od.OrderDetailId
                      WHERE i.MbaReportNumber LIKE '%/%'
                        AND od.OrderWorkPlanId NOT IN (SELECT OrderWorkPlanId FROM dbo.CalibratorsToWorkPlan WHERE CalibratorId = u.ID AND IsDeleted = 0))
        FROM dbo.Users u JOIN dbo.UserRoles r ON r.UserRoleId = u.UserRoleId
        WHERE r.UserRoleName = N'Calibrator' AND ISNULL(u.IsActive, 1) = 1
        ORDER BY u.ID;
    IF @T = 2
        SELECT TOP 1 @Email = u.Email, @Wp = c.OrderWorkPlanId
        FROM dbo.CalibratorsToWorkPlan c
        JOIN dbo.Users u ON u.ID = c.CalibratorId JOIN dbo.UserRoles r ON r.UserRoleId = u.UserRoleId
        WHERE c.IsDeleted = 0 AND r.UserRoleName = N'Calibrator'
          AND NULLIF(LTRIM(RTRIM(c.OrderDetailsMbaReportNumber)), '') IS NULL
          AND EXISTS (SELECT 1 FROM dbo.OrderDetails od JOIN dbo.OrderDetailsItems i ON i.OrderDetailId = od.OrderDetailId
                      WHERE od.OrderWorkPlanId = c.OrderWorkPlanId AND NULLIF(i.MbaReportNumber, '') IS NOT NULL)
        ORDER BY c.OrderWorkPlanId DESC;

    TRUNCATE TABLE #Out;
    IF @Email IS NOT NULL AND @Wp IS NOT NULL
    BEGIN
        SET @Sql = N'INSERT #Out EXEC dbo.GetOrderDetailsDevices @OrderWorkPlanId = @Wp, @LoggedInUserEmail = @Email';
        EXEC sp_executesql @Sql, N'@Wp INT, @Email NVARCHAR(255)', @Wp = @Wp, @Email = @Email;
    END

    INSERT @Results
    SELECT CASE @T WHEN 1 THEN N'T1: calibrator not assigned to the work plan' ELSE N'T2: calibrator assigned with no prefix' END,
           @Email, @Wp,
           COUNT(o.OrderDetailsItemId),
           SUM(CASE WHEN ISNULL(o.MbaReportNumber, N'') COLLATE Latin1_General_BIN2 <> ISNULL(i.MbaReportNumber, N'') COLLATE Latin1_General_BIN2 THEN 1 ELSE 0 END),
           MAX(CASE WHEN ISNULL(o.MbaReportNumber, N'') COLLATE Latin1_General_BIN2 <> ISNULL(i.MbaReportNumber, N'') COLLATE Latin1_General_BIN2
                    THEN CONCAT(N'item ', o.OrderDetailsItemId, N': returned ', o.MbaReportNumber COLLATE DATABASE_DEFAULT,
                                N', stored ', i.MbaReportNumber COLLATE DATABASE_DEFAULT) END),
           CASE
             WHEN @Email IS NULL OR @Wp IS NULL THEN N'SKIP: no such case on this server'
             WHEN COUNT(o.OrderDetailsItemId) = 0 THEN N'FAIL: no devices returned'
             WHEN SUM(CASE WHEN ISNULL(o.MbaReportNumber, N'') COLLATE Latin1_General_BIN2 <> ISNULL(i.MbaReportNumber, N'') COLLATE Latin1_General_BIN2 THEN 1 ELSE 0 END) > 0
               THEN N'FAIL: MABA No not the stored one'
             ELSE N'PASS'
           END
    FROM #Out o
    LEFT JOIN dbo.OrderDetailsItems i ON i.OrderDetailsItemId = o.OrderDetailsItemId
    WHERE o.OrderDetailsItemId IS NOT NULL;

    SET @T += 1;
END

DROP TABLE #Out;
SELECT * FROM @Results;
