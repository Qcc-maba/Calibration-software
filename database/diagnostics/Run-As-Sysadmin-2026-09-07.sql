/*
    ==========================================================================================
    Everything that needs an account app_prod does not have. Run on MBACUSTWEB\QCC as sysadmin.

    Four sections. 1 and 2 are safe and quick. 3 stops the ETL until you finish it, so do it
    when you can watch a job run. 4 is a configuration change someone has to confirm.

    app_prod is refused by msdb and SSISDB outright, which is why these could not be done for
    you. Everything below was prepared from measurements already taken.
    ==========================================================================================
*/

/* ------------------------------------------------------------------------------------------
   SECTION 1 - are any database users really orphaned?                       READ ONLY, 5 sec

   Read this as app_prod and it lies: that login cannot see other logins, so sys.server_principals
   returns only itself and sa, and the LEFT JOIN paints every user as orphaned. As sysadmin you
   get the truth. Only act on what THIS returns.
   ------------------------------------------------------------------------------------------ */
SELECT DbName   = 'CalibratorProd',
       UserName = dp.name,
       Status_  = CASE WHEN sp.sid IS NULL THEN 'ORPHANED' ELSE 'ok' END,
       dp.create_date
FROM CalibratorProd.sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.type IN ('S','U') AND dp.principal_id > 4
UNION ALL
SELECT 'Calibrator', dp.name,
       CASE WHEN sp.sid IS NULL THEN 'ORPHANED' ELSE 'ok' END,
       dp.create_date
FROM Calibrator.sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.type IN ('S','U') AND dp.principal_id > 4
ORDER BY Status_, UserName;

-- For each row that really says ORPHANED and belongs to someone who still needs access:
--   CREATE LOGIN [<name>] WITH PASSWORD = N'<new>', CHECK_POLICY = OFF;
--   USE [<db>]; ALTER USER [<name>] WITH LOGIN = [<name>];
-- For one nobody uses:
--   USE [<db>]; DROP USER [<name>];
-- Send me the output and I will tell you which is which.


/* ------------------------------------------------------------------------------------------
   SECTION 2 - delete the three dead Copy Database Wizard jobs.                   ~10 seconds

   Measured: all three disabled, none scheduled, each last ran in Nov-Dec 2024 and failed. They
   are the leftovers of a one-off database copy and nothing calls them. Deleting them stops the
   job list from implying work that is not happening.
   ------------------------------------------------------------------------------------------ */
EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_MbaCustWeb_QCC_MbaCustWeb_QCC_0';
EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_pri-test_PRI_MbaCustWeb_QCC_0';
EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_pri-test_PRI_MbaCustWeb_QCC_0_1';

-- While you are here: Calibrator_Backup and DailyDatabaseBackup are also disabled and last
-- failed in 2025. Do NOT panic and do NOT delete them yet - backups ARE happening (every
-- database was backed up today at 07:50, see Open-Items-2026-09-07.sql section 4). Decide
-- whether to repair them or remove them, but the server is not unprotected.


/* ------------------------------------------------------------------------------------------
   SECTION 3 - stop storing the passwords in clear text.       BREAKS THE ETL UNTIL FINISHED

   Every environment variable has Sensitive unchecked, so the connection strings - Priority's
   included - are readable by anyone who can open the environment. That is how we recovered the
   'ed' password this morning, which was convenient once and is a problem permanently.

   Ticking Sensitive BLANKS the stored value, so each one must be re-entered immediately. Do one
   folder, prove it, then do the other. Never both at once.

   Before you start: make sure the database master key is backed up. Sensitive values are
   encrypted with it, and without it they cannot be recovered.
   ------------------------------------------------------------------------------------------ */
SELECT f.name AS folder_name, e.name AS environment_name, v.name AS variable_name, v.sensitive
FROM SSISDB.catalog.environment_variables AS v
JOIN SSISDB.catalog.environments        AS e ON e.environment_id = v.environment_id
JOIN SSISDB.catalog.folders             AS f ON f.folder_id      = e.folder_id
ORDER BY f.name, e.name, v.name;

/*  Then, in SSMS:
      a. Copy the current value of every variable in CalibratorProd\Prod somewhere safe.
      b. Integration Services Catalogs -> SSISDB -> CalibratorProd -> Environments -> Prod ->
         Properties -> Variables. Tick Sensitive on each password-bearing row, paste the value
         back, OK.
      c. EXEC msdb.dbo.sp_start_job @job_name = N'CalibratorMainLoadProd';
         Confirm it SUCCEEDS before going further.
      d. Only then repeat for the CalibratorSync folder and CalibratorMainLoad.

    If a run fails after this, the value did not save - re-enter it rather than changing the
    login password.  */


/* ------------------------------------------------------------------------------------------
   SECTION 4 - OnPremCalibrator points at the wrong server.                  CONFIRMED WRONG

   It reads Data Source=51.17.121.203\QCC,1433 - the AWS machine - and you have confirmed it is
   meant to be the LOCAL database. AWSCalibrator points at the same host, differing only in
   Initial Catalog, so today the "sync to AWS" runs between two databases on one box.

   Fix it in the same Variables dialog as section 3: set the Data Source of OnPremCalibrator to
   the on-premise instance, leave Initial Catalog=Calibrator, and keep the credentials that
   instance expects. Then run CalibratorMainLoadProd by hand and confirm it still succeeds.

   Note this may be why nobody noticed it was wrong: with both sides on the same box the package
   still completes. Once it points on-premise, that server has to be reachable from MbaCustWeb
   and the login it uses has to exist THERE - the same two things that broke 'ed' this morning.
   ------------------------------------------------------------------------------------------ */
SELECT v.name, LEFT(CONVERT(nvarchar(max), v.value), 60) AS starts_with
FROM SSISDB.catalog.environment_variables AS v
WHERE v.name IN (N'AWSCalibrator', N'OnPremCalibrator');
