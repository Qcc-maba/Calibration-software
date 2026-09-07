/*
    Why CalibratorMainLoadProd / CalibratorMainLoad have failed every hour since 31/08/2026.

    Run on MBACUSTWEB\QCC as a login with access to SSISDB (ssis_admin, or sysadmin).
    app_prod cannot read SSISDB: "The server principal app_prod is not able to access the
    database SSISDB under the current security context."

    What is already known, so you can skip re-checking it:
      - Job step 1, RunMasterLoadFromPriority, fails ~9 seconds in. Too fast to be data volume.
      - The linked server 31.168.173.93 (amaba) answers in 0.7s, so Priority itself is reachable.
      - The sibling jobs that reach Priority through that linked server SUCCEED
        ("MABA - Refresh device descriptions", "MABA - Refresh packing data from Priority").
        Only the SSIS package, which uses its own connection managers, fails.
      - Every etl.* and stg.* procedure carries modify_date 2026-08-31 09:10:36 - a deployment
        that morning, the same day the data stops.
      - stg.stg_Orders stops at LA26103948, the same place dbo.OrderWorkPlans does, so the
        merge is fine and the extract never delivers anything new.

    Priority order of suspicion, given a redeploy plus a fast failure:
      1. Sensitive parameters lost on redeploy (package protection / DTS key) - the classic
         "Failed to decrypt protected XML node" or a blank connection password.
      2. The environment reference the job passes no longer resolves after the redeploy.
      3. The account the step runs as (MBACUSTWEB\SYSTEM) lost rights the package needs.
*/

-- 1. The last executions and how they ended. status 4 = failed, 7 = succeeded.
SELECT TOP 20
       e.execution_id,
       e.folder_name,
       e.project_name,
       e.package_name,
       e.status,
       e.start_time,
       e.end_time,
       e.environment_folder_name,
       e.environment_name
FROM SSISDB.catalog.executions AS e
ORDER BY e.execution_id DESC;

-- 2. The actual error text. Replace the id with the newest failing execution_id from step 1
--    (110049 was the 07/09 09:00 run). message_type 120 = Error, 130 = TaskFailed.
SELECT m.message_time,
       m.message_type,
       m.message_source_type,
       m.message
FROM SSISDB.catalog.operation_messages AS m
WHERE m.operation_id = 110049
  AND m.message_type IN (120, 130)
ORDER BY m.message_time;

-- 3. If step 2 returns nothing, the failure happened before the package could log. This shows
--    every error the catalog has recorded recently, whatever the execution.
SELECT TOP 40
       m.operation_id,
       m.message_time,
       m.message
FROM SSISDB.catalog.operation_messages AS m
WHERE m.message_type = 120
ORDER BY m.operation_id DESC, m.message_time DESC;

-- 4. The first execution that failed, which dates the breakage and should line up with the
--    31/08 09:10 deployment.
SELECT MIN(e.start_time) AS first_failure,
       MAX(e.start_time) AS latest_failure,
       COUNT(*)          AS failures
FROM SSISDB.catalog.executions AS e
WHERE e.status = 4
  AND e.package_name LIKE '%Master%';

-- 5. The last time it actually succeeded. Expect nothing after 31/08.
SELECT TOP 5 e.execution_id, e.package_name, e.start_time, e.end_time
FROM SSISDB.catalog.executions AS e
WHERE e.status = 7
  AND e.package_name LIKE '%Master%'
ORDER BY e.execution_id DESC;

-- 6. Project parameters and whether the sensitive ones still hold a value. A NULL or empty
--    sensitive value here is hypothesis 1 confirmed.
SELECT p.project_name,
       p.parameter_name,
       p.sensitive,
       p.design_default_value,
       p.default_value
FROM SSISDB.catalog.object_parameters AS p
WHERE p.project_name LIKE '%Calibrator%'
ORDER BY p.project_name, p.parameter_name;
