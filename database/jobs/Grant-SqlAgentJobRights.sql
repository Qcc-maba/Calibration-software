/*
    One-time grant: let app_prod manage its own SQL Agent jobs
    ---------------------------------------------------------------------------------------------
    A SYSADMIN RUNS THIS ONCE. It is the only step in the MABA deployment that app_prod cannot do
    for itself, which is why it is in its own file.

    Measured on 51.17.121.203 (CalibratorProd), 31/08:

        app_prod    sysadmin 0    serveradmin 0    securityadmin 0    db_owner 1

    It has no principal in msdb at all - not even read access. `SELECT ... FROM msdb.sys.*` and
    `sys.dm_server_services` both come back "The user does not have permission to perform this
    action" (error 297). So it cannot create a job, cannot see whether one exists, and cannot tell
    whether the Agent is even running.

    WHAT THIS GRANTS, AND WHAT IT DELIBERATELY DOES NOT
    ---------------------------------------------------
    SQLAgentUserRole is the smallest role that can own and run jobs. A member can create, edit,
    start and delete ONLY THE JOBS IT OWNS. It cannot see other people's jobs, cannot change the
    Agent's configuration, cannot create proxies or operators, and cannot touch anything outside
    msdb. It is not sysadmin and it is not close to it.

    The job steps then run as app_prod against CalibratorProd, where it is already db_owner. No
    new rights are needed on the data side, and nothing runs with elevated privilege.

    If your policy is that application logins own no jobs at all, then do not run this - create the
    jobs yourself from Setup-SqlAgentJobs.sql with @OwnerLogin = N'sa' and this file is unnecessary.
    Either arrangement works; this one just removes a human from the loop each time a schedule
    changes.

    SQL Server Agent must also be RUNNING. A job on a stopped Agent never fires and says nothing.
    The check at the bottom reports that too.
*/

SET NOCOUNT ON;

DECLARE @Login SYSNAME = N'app_prod';   /* app_stage as well, if you want the same on STAGE */

/* ---- 1. give the login a user in msdb -------------------------------------------------------- */
USE msdb;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @Login)
BEGIN
    DECLARE @sql NVARCHAR(400) = N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
    EXEC sys.sp_executesql @sql;
    PRINT 'created msdb user ' + @Login;
END
ELSE
    PRINT 'msdb user ' + @Login + ' already exists';

/* ---- 2. the smallest role that can own and run a job ----------------------------------------- */
IF NOT EXISTS (SELECT 1
               FROM sys.database_role_members AS rm
               JOIN sys.database_principals AS r ON r.principal_id = rm.role_principal_id
               JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
               WHERE r.name = N'SQLAgentUserRole' AND m.name = @Login)
BEGIN
    EXEC sys.sp_addrolemember @rolename = N'SQLAgentUserRole', @membername = @Login;
    PRINT 'added ' + @Login + ' to SQLAgentUserRole';
END
ELSE
    PRINT @Login + ' is already in SQLAgentUserRole';

/* ---- 3. report what the grant achieved -------------------------------------------------------- */
SELECT Login_          = @Login,
       MsdbUser        = CASE WHEN EXISTS (SELECT 1 FROM sys.database_principals WHERE name = @Login)
                              THEN 'yes' ELSE 'NO' END,
       SQLAgentUserRole= CASE WHEN EXISTS (SELECT 1
                              FROM sys.database_role_members AS rm
                              JOIN sys.database_principals AS r ON r.principal_id = rm.role_principal_id
                              JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
                              WHERE r.name = N'SQLAgentUserRole' AND m.name = @Login)
                              THEN 'yes' ELSE 'NO' END,
       StillNotSysadmin= CASE WHEN IS_SRVROLEMEMBER('sysadmin', @Login) = 1
                              THEN 'WARNING - it IS sysadmin' ELSE 'correct - it is not' END;

SELECT AgentService = servicename,
       State        = status_desc,
       StartsWith   = startup_type_desc,
       Verdict      = CASE WHEN status_desc = N'Running' THEN 'ok'
                           ELSE 'START IT - a job on a stopped Agent never fires and says nothing' END
FROM sys.dm_server_services
WHERE servicename LIKE N'%Agent%';

/* Next: run Setup-SqlAgentJobs.sql, which creates the jobs themselves and can be run by app_prod
   once the above is in place. */
