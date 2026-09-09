/*
    ==========================================================================================
    RESOLVED 07/09/2026. Kept as the record of what was actually wrong, because the reasoning
    below is still how you would diagnose a repeat.

    Three faults were stacked, each hidden by the one before it. Watch the run DURATION as the
    signal: 7s (login) -> 19s (password) -> minutes (working).

      1. No server login 'ed'         -> CREATE LOGIN + ALTER USER ... WITH LOGIN, both databases
      2. Its password did not match   -> lifted verbatim from the connection string (see below)
      3. No EXECUTE on the procedures -> GRANT EXECUTE ON SCHEMA::stg / etl / dbo

    CalibratorProd went from 2,838 work plans stopped at 31/08 to 2,900 reaching 07/09.

    CORRECTION to step 5 of the original script: reading sys.server_principals as app_prod shows
    only app_prod and sa, so every database user looks orphaned. That was an artifact of missing
    VIEW ANY DEFINITION, not a diagnosis. Re-check as sysadmin before believing it.
    ==========================================================================================
*/

/*
    Fixes the hourly CalibratorMainLoad / CalibratorMainLoadProd failure.

    Run on MBACUSTWEB\QCC (51.17.121.203\QCC) as sysadmin. app_prod cannot do step 1: creating a
    server login needs ALTER ANY LOGIN, which it does not have.

    ------------------------------------------------------------------------------------------
    DIAGNOSIS (measured 07/09/2026, nothing here is a guess)

    The SSIS package CalibratorProd\CalibratorSSIS\StartSyncMasterToAWS.dtsx fails at validation:

        Load accessories:Error: ADO NET Destination has failed to acquire the connection
        {5D340525-F86F-4A09-8F4F-C17373323AB0} with the following error message:
        "Login failed for user 'ed'."

        Truncate DepartmentDelays:Error: Failed to acquire connection "AWSCalibrator".

    Everything else in that execution is a consequence: OrdersSyncToAWS.dtsx and
    AgentsWaitingListToAWS.dtsx never start because the parent fails validation.

    Why the login fails: 'ed' exists as a DATABASE USER in both Calibrator and CalibratorProd but
    there is NO SERVER LOGIN of that name. Only app_prod and sa exist as SQL logins on the
    instance. Both databases carry five orphaned users each - ed, eliran, ariel, SlavaMaba and
    the opposite environment's app_ user - which is the signature of a database restored onto a
    different server: database users travel in the backup, server logins do not.

    Second problem, easy to miss: user 'ed' holds CONNECT and nothing else. No role membership,
    no explicit grants. So recreating the login is necessary but NOT sufficient - the package
    writes to staging tables and would fail on the first insert.

    Impact while it is broken: 212 executions failed, 0 succeeded. Priority holds orders up to
    LA26104050; Calibrator and CalibratorProd both stop at LA26103948. 102 orders missing.
    ------------------------------------------------------------------------------------------
*/

/* ==========================================================================================
   STEP 1 - recreate the server login.

   If the password the SSIS package stores is known, use it verbatim: the package then works
   with no change on the SSIS side at all, and you can skip step 4.

   If it is not known, pick a new one here and do step 4 as well.
   ========================================================================================== */
USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'ed')
BEGIN
    CREATE LOGIN [ed]
        WITH PASSWORD = N'<<PUT THE PASSWORD HERE>>',
             CHECK_POLICY = OFF,          -- matches how app_prod and sa are configured here
             DEFAULT_DATABASE = [CalibratorProd];
    PRINT 'login ed created';
END
ELSE
    PRINT 'login ed already exists - nothing done';
GO

/* ==========================================================================================
   STEP 2 - point the orphaned database users at it, in BOTH databases.
   ========================================================================================== */
USE [CalibratorProd];
GO
ALTER USER [ed] WITH LOGIN = [ed];
GO

USE [Calibrator];
GO
ALTER USER [ed] WITH LOGIN = [ed];
GO

/* ==========================================================================================
   STEP 3 - give it the rights the package needs. It only had CONNECT.

   db_datareader + db_datawriter covers reading and writing rows. If the package also truncates
   (the error mentions "Truncate DepartmentDelays"), TRUNCATE TABLE needs ALTER on the table, so
   either grant db_ddladmin as well or db_owner. Start narrow, widen only if it still fails.
   ========================================================================================== */
USE [CalibratorProd];
GO
ALTER ROLE [db_datareader] ADD MEMBER [ed];
ALTER ROLE [db_datawriter] ADD MEMBER [ed];
ALTER ROLE [db_ddladmin]   ADD MEMBER [ed];   -- needed for TRUNCATE TABLE
GO

USE [Calibrator];
GO
ALTER ROLE [db_datareader] ADD MEMBER [ed];
ALTER ROLE [db_datawriter] ADD MEMBER [ed];
ALTER ROLE [db_ddladmin]   ADD MEMBER [ed];
GO

/* ==========================================================================================
   STEP 4 - only if you set a NEW password in step 1.

   SSMS -> Integration Services Catalogs -> SSISDB -> CalibratorProd -> Environments -> Prod
   Open it, find the variable holding the AWSCalibrator password, set the new value, OK.
   Repeat for the CalibratorSync folder, which runs the same project on its own schedule.

   Then right-click the project -> Configure -> References, and confirm the job still points at
   that environment.
   ========================================================================================== */

/* ==========================================================================================
   STEP 5 - verify, before waiting an hour for the schedule.
   ========================================================================================== */
USE [master];
GO
-- the login exists and the users are no longer orphaned
SELECT DbName = N'CalibratorProd', dp.name,
       HasLogin = CASE WHEN sp.sid IS NULL THEN 'STILL ORPHANED' ELSE 'ok' END
FROM CalibratorProd.sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.name = N'ed'
UNION ALL
SELECT N'Calibrator', dp.name,
       CASE WHEN sp.sid IS NULL THEN 'STILL ORPHANED' ELSE 'ok' END
FROM Calibrator.sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.name = N'ed';
GO

-- then run the job once by hand:
--   SQL Server Agent -> Jobs -> CalibratorMainLoadProd -> Start Job at Step...
-- and confirm it succeeds, then:
SELECT Newest = MAX(OrderNumber) FROM CalibratorProd.dbo.OrderWorkPlans WHERE OrderNumber LIKE 'LA26%';
-- expect this to move past LA26103948, towards LA26104050.

/* ==========================================================================================
   OPTIONAL - the other four orphans.

   eliran, ariel, SlavaMaba and the opposite app_ user are orphaned in both databases too. They
   are not what breaks the ETL, so they are deliberately left alone here. Fix them the same way
   only if someone actually needs those logins:

       CREATE LOGIN [<name>] WITH PASSWORD = N'...';
       USE [<db>]; ALTER USER [<name>] WITH LOGIN = [<name>];

   Dropping the unused ones is the tidier answer, but that is a decision, not a repair.
   ========================================================================================== */
