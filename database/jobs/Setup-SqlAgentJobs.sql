/*
    SQL Agent jobs for the MABA calibration database
    ---------------------------------------------------------------------------------------------
    Creates both nightly refresh jobs in one place, and REFUSES TO RUN with a readable explanation
    if the connected login cannot create them - rather than failing on statement 40 with
    "EXECUTE permission was denied on the object 'sp_add_job'".

        MABA - Refresh packing data from Priority     02:00   dbo.RefreshPackingDataFromPriority
        MABA - Refresh device descriptions            02:30   dbo.RefreshDeviceDescriptions

    Set @Database below. Everything else has a working default.

    WHO CAN RUN THIS
    ----------------
    A login that is sysadmin, or one in msdb's SQLAgentUserRole. app_prod is NEITHER by default -
    it is db_owner in CalibratorProd and has no principal in msdb at all. If that is the account
    you are connected as, the preflight below will say so and stop; run Grant-SqlAgentJobRights.sql
    as a sysadmin first, or connect as one and set @OwnerLogin = N'sa'.

    SQL Server Agent must also be running. The preflight checks that too, because a job on a
    stopped Agent never fires and never complains.

    Safe to re-run: each job is dropped first if it exists.

    WHAT THE TWO JOBS DO
    --------------------
    Refresh packing data - follows OrderDetailsItems.DOC_N to the Priority goods-receipt document
    (TYPE 'N') and brings back two fields the sync never carried: whether the device arrived in the
    customer's own packaging (MBA_CUSTPACK) and the date we booked it in. Without a schedule both
    freeze at whatever the last manual run produced. On STAGE the first run read 4,414 receipts,
    dated 3,604 items and flagged 82 order lines as customer-packed.

    Refresh device descriptions - rebuilds dbo.CrmDeviceDescription from MBA_DOCLOAD.SERNDES,
    un-reversing Priority's visual-order text on the way in (MBA-666). 3,000 descriptions on STAGE.
    On PROD the table is currently EMPTY - this job is what fills it, and dbo.GetCalibrationItems
    returns nothing until it has run at least once.

    Both jobs only READ from Priority. Nothing is written back to the ERP.

    02:00 and 02:30 were chosen so the two pulls do not overlap each other or the working day.
*/

/*  NOTE: no USE msdb anywhere in this file, deliberately. A login with no principal in msdb - which
    is exactly the case this script exists to diagnose - cannot even switch to it, so USE would fail
    before the preflight had a chance to explain why. Every Agent object is addressed as
    msdb.dbo.<name> instead, which needs no context switch. The whole file is one batch, so RETURN
    below genuinely stops it.  */

SET NOCOUNT ON;

DECLARE @Database    SYSNAME = N'CalibratorProd',   /* N'Calibrator' for STAGE */
        @OwnerLogin  SYSNAME = NULL,                /* NULL = whoever is running this. N'sa' also fine */
        @PackingTime INT     = 20000,               /* 02:00:00, HHMMSS */
        @DescribeTime INT    = 23000;               /* 02:30:00 */

SET @OwnerLogin = COALESCE(@OwnerLogin, SUSER_SNAME());

/* ============================================================================================= */
/*  Preflight - say why this will not work BEFORE writing anything                                */
/* ============================================================================================= */
DECLARE @Problems TABLE (Seq INT IDENTITY, Problem NVARCHAR(400));
DECLARE @Sysadmin BIT = IS_SRVROLEMEMBER('sysadmin'),
        @CanReadJobs BIT = 0;

/*  Probe what the script actually needs rather than something that correlates with it.

    Two indirect tests were tried first and both said yes when the answer was no. IS_ROLEMEMBER
    answers for the CURRENT database, not msdb. And HAS_DBACCESS('msdb') returns 1 for app_prod -
    guest gets it into the database - while SELECT on dbo.sysjobs is still denied, so the preflight
    passed and the script then died on the first real statement. Reading sysjobs is the smallest
    thing this script cannot do without, so read sysjobs.  */
BEGIN TRY
    DECLARE @Probe INT = (SELECT TOP (1) 1 FROM msdb.dbo.sysjobs);
    SET @CanReadJobs = 1;
END TRY
BEGIN CATCH
    SET @CanReadJobs = 0;
END CATCH

IF @Sysadmin <> 1 AND @CanReadJobs = 0
    INSERT @Problems (Problem) VALUES
      (N'This login cannot read msdb.dbo.sysjobs, so it cannot create, see or start a job. '
     + N'Run database/jobs/Grant-SqlAgentJobRights.sql as a sysadmin, or reconnect as one.');

/*  A SQLAgentUserRole member may only create jobs it owns. Asking for another login as the owner
    fails with a message that does not say that, so catch it here.  */
IF @Sysadmin <> 1 AND @OwnerLogin <> SUSER_SNAME()
    INSERT @Problems (Problem) VALUES
      (N'@OwnerLogin names another login. Only a sysadmin can create a job owned by someone else - '
     + N'leave @OwnerLogin NULL so the job is owned by whoever runs this.');

/*  Whether the Agent is running is worth knowing but must never break the preflight. On SQL Server
    2022 sys.dm_server_services needs VIEW SERVER PERFORMANCE STATE, which is NOT the same as
    VIEW SERVER STATE - app_prod holds the second and not the first, so guarding on the obvious
    permission still let the DMV raise. TRY/CATCH is the only version of this that cannot be wrong
    about which permission the DMV happens to want.  */
DECLARE @AgentState SYSNAME = N'unknown - this login cannot read the service list';
BEGIN TRY
    SELECT TOP (1) @AgentState = status_desc
    FROM sys.dm_server_services WHERE servicename LIKE N'%Agent%';
END TRY
BEGIN CATCH
    SET @AgentState = N'unknown - this login cannot read the service list';
END CATCH

IF @AgentState NOT IN (N'Running', N'unknown - this login cannot read the service list')
    INSERT @Problems (Problem) VALUES
      (N'SQL Server Agent is ' + @AgentState + N'. The jobs would be created and would never fire. '
     + N'Object Explorer > SQL Server Agent > right-click > Start.');

IF DB_ID(@Database) IS NULL
    INSERT @Problems (Problem) VALUES (N'@Database ' + @Database + N' does not exist on this server.');

IF EXISTS (SELECT 1 FROM @Problems)
BEGIN
    SELECT Refusing_to_run = Problem FROM @Problems ORDER BY Seq;
    SELECT Connected_as   = SUSER_SNAME(),
           IsSysadmin     = @Sysadmin,
           CanReadJobs    = @CanReadJobs,
           AgentService   = @AgentState,
           TargetDatabase = @Database;
    RETURN;
END

/*  Past the preflight but not sysadmin: msdb is reachable, though whether this login is in
    SQLAgentUserRole cannot be read from here. If sp_add_job comes back with "EXECUTE permission
    was denied", that is the missing role and Grant-SqlAgentJobRights.sql adds it.  */
IF @Sysadmin <> 1
    PRINT 'note: not sysadmin. If the next statement is denied, the SQLAgentUserRole membership is missing.';

/* ============================================================================================= */
/*  The jobs                                                                                      */
/* ============================================================================================= */
DECLARE @JobId UNIQUEIDENTIFIER, @Name SYSNAME;

/* ---- 1. packing data -------------------------------------------------------------------------- */
SET @Name = N'MABA - Refresh packing data from Priority';
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @Name)
    EXEC msdb.dbo.sp_delete_job @job_name = @Name, @delete_unused_schedule = 1;

/*  @JobId MUST be NULL going in. sp_add_job validates that, and the failure is not obvious:
    the second job's sp_add_job is rejected, @JobId keeps pointing at the FIRST job, and its
    sp_add_jobstep / sp_add_jobschedule then attach to that job instead. Because the first job
    has already been posted to a target server by then, the error that surfaces is
    "Cannot add, update, or delete a job that originated from an MSX server" - which sends you
    looking at server names and MSX enlistment, neither of which is the problem. Seen on
    CalibratorProd, 01/09: one job left holding two steps and two schedules, the other absent. */
SET @JobId = NULL;

EXEC msdb.dbo.sp_add_job
     @job_name         = @Name,
     @enabled          = 1,
     @description      = N'Reads the Priority goods-receipt document (TYPE N) through OrderDetailsItems.DOC_N and fills in customer-packing and lab-receiving date. Read-only against Priority.',
     @owner_login_name = @OwnerLogin,
     @job_id           = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
     @job_id         = @JobId,
     @step_name      = N'EXEC dbo.RefreshPackingDataFromPriority',
     @subsystem      = N'TSQL',
     @database_name  = @Database,
     @command        = N'EXEC dbo.RefreshPackingDataFromPriority;',
     @retry_attempts = 2,
     @retry_interval = 5,     /* minutes - the linked server is the usual reason for a retry */
     @on_success_action = 1,  /* quit reporting success */
     @on_fail_action    = 2;  /* quit reporting failure */

EXEC msdb.dbo.sp_add_jobschedule
     @job_id           = @JobId,
     @name             = N'Nightly 02:00',
     @freq_type        = 4,   /* daily */
     @freq_interval    = 1,
     @active_start_time = @PackingTime;

EXEC msdb.dbo.sp_add_jobserver @job_id = @JobId, @server_name = N'(local)';
PRINT 'created: ' + @Name;

/* ---- 2. device descriptions ------------------------------------------------------------------- */
SET @Name = N'MABA - Refresh device descriptions';
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @Name)
    EXEC msdb.dbo.sp_delete_job @job_name = @Name, @delete_unused_schedule = 1;

SET @JobId = NULL;   /* see the note on the first job */

EXEC msdb.dbo.sp_add_job
     @job_name         = @Name,
     @enabled          = 1,
     @description      = N'Rebuilds dbo.CrmDeviceDescription from Priority MBA_DOCLOAD.SERNDES, un-reversing the visual-order text (MBA-666). Read-only against Priority.',
     @owner_login_name = @OwnerLogin,
     @job_id           = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
     @job_id         = @JobId,
     @step_name      = N'EXEC dbo.RefreshDeviceDescriptions',
     @subsystem      = N'TSQL',
     @database_name  = @Database,
     @command        = N'EXEC dbo.RefreshDeviceDescriptions;',
     @retry_attempts = 2,
     @retry_interval = 5,
     @on_success_action = 1,
     @on_fail_action    = 2;

EXEC msdb.dbo.sp_add_jobschedule
     @job_id           = @JobId,
     @name             = N'Nightly 02:30',
     @freq_type        = 4,
     @freq_interval    = 1,
     @active_start_time = @DescribeTime;

EXEC msdb.dbo.sp_add_jobserver @job_id = @JobId, @server_name = N'(local)';
PRINT 'created: ' + @Name;

/* ============================================================================================= */
SELECT Job        = j.name,
       Enabled    = j.enabled,
       Owner      = SUSER_SNAME(j.owner_sid),
       Database_  = s.database_name,
       Command    = s.command,
       StartsAt   = STUFF(STUFF(RIGHT('000000' + CAST(sch.active_start_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')
FROM msdb.dbo.sysjobs AS j
JOIN msdb.dbo.sysjobsteps AS s ON s.job_id = j.job_id
LEFT JOIN msdb.dbo.sysjobschedules AS js ON js.job_id = j.job_id
LEFT JOIN msdb.dbo.sysschedules AS sch ON sch.schedule_id = js.schedule_id
WHERE j.name LIKE N'MABA - %'
ORDER BY j.name;

PRINT '';
PRINT 'Now test each one without waiting for 02:00:';
PRINT '  SQL Server Agent > Jobs > right-click the job > Start Job at Step';
PRINT 'Packing finishes in under a minute. Device descriptions takes a little longer - it reads';
PRINT '3,000 descriptions across the linked server.';
PRINT '';
PRINT 'Afterwards, that they actually did something:';
PRINT '  SELECT COUNT(*) FROM dbo.CrmDeviceDescription;                        -- expect ~3,000';
PRINT '  SELECT COUNT(*) FROM dbo.OrderDetailsItems WHERE CustomerReceivingDate IS NOT NULL;';
PRINT '';
PRINT 'And that the Agent ran them:';
PRINT '  SELECT j.name, h.run_date, h.run_time, h.run_duration,';
PRINT '         CASE h.run_status WHEN 0 THEN ''failed'' WHEN 1 THEN ''succeeded'' ELSE ''other'' END,';
PRINT '         h.message';
PRINT '  FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobhistory h ON h.job_id = j.job_id';
PRINT '  WHERE j.name LIKE ''MABA - %'' AND h.step_id = 0 ORDER BY h.run_date DESC, h.run_time DESC;';
