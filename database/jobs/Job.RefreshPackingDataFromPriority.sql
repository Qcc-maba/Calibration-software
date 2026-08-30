/*
    SQL Agent job: MABA - Refresh packing data from Priority
    ---------------------------------------------------------------------------------------------
    Runs dbo.RefreshPackingDataFromPriority nightly.

    That procedure follows OrderDetailsItems.DOC_N to the Priority goods-receipt document and
    brings back two things our sync never carried across: whether the device arrived in the
    customer's own packaging (MBA_CUSTPACK on the 'N' document) and the date we booked it in.

    Without a schedule both fields freeze at whatever the last manual run produced.

    HOW TO RUN THIS
    ---------------
    1. Open SSMS and connect to 51.17.121.203 (the QCC instance) with an account that has
       SQLAgentUserRole in msdb, or sysadmin. app_stage cannot create jobs.
    2. Make sure SQL Server Agent is running - Object Explorer, bottom node. If it shows a red
       stop icon, right-click it and Start. A job on a stopped Agent never fires and says nothing.
    3. Open this file and press Execute. It targets msdb; do not switch the database dropdown.
    4. Verify: SQL Server Agent > Jobs > the job below > right-click > Start Job at Step.
       It should finish in under a minute and report success.

    The script is safe to re-run: it drops the job first if it already exists.

    FOR PROD
    --------
    Change @Database below to CalibratorProd and re-run. Do not do that until the procedure
    itself has been deployed there - it does not exist on PROD yet.

    Timing: 02:00 was chosen because the pull reaches across the linked server into Priority and
    should not compete with the working day. Change @StartTime if that clashes with the ETL.
*/

USE msdb;
GO

DECLARE @JobName   SYSNAME       = N'MABA - Refresh packing data from Priority',
        @Database  SYSNAME       = N'Calibrator',   /* CalibratorProd when promoting */
        @StartTime INT           = 20000,           /* 02:00:00, format HHMMSS */
        @JobId     UNIQUEIDENTIFIER;

/* start clean so the script can be re-run */
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1;

EXEC msdb.dbo.sp_add_job
     @job_name    = @JobName,
     @enabled     = 1,
     @description = N'Reads the Priority goods-receipt document (TYPE N) via OrderDetailsItems.DOC_N and fills in customer-packing and lab-receiving date. Read-only against Priority.',
     @owner_login_name = N'sa',
     @job_id      = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
     @job_id           = @JobId,
     @step_name        = N'Refresh packing data',
     @subsystem        = N'TSQL',
     @database_name    = @Database,
     @command          = N'EXEC dbo.RefreshPackingDataFromPriority;',
     @retry_attempts   = 2,      /* the linked server to Priority is not always reachable */
     @retry_interval   = 5,      /* minutes */
     @on_success_action = 1,     /* quit reporting success */
     @on_fail_action    = 2;     /* quit reporting failure, so a broken link is visible */

EXEC msdb.dbo.sp_add_schedule
     @schedule_name  = N'MABA - nightly 02:00',
     @freq_type      = 4,        /* daily */
     @freq_interval  = 1,        /* every day */
     @active_start_time = @StartTime;

EXEC msdb.dbo.sp_attach_schedule
     @job_id        = @JobId,
     @schedule_name = N'MABA - nightly 02:00';

EXEC msdb.dbo.sp_add_jobserver
     @job_id      = @JobId,
     @server_name = N'(LOCAL)';

PRINT 'Job created: ' + @JobName;
GO

/*
    Check it afterwards
    -------------------
    Last run and outcome:

        SELECT j.name,
               h.run_date, h.run_time, h.run_duration,
               outcome = CASE h.run_status WHEN 0 THEN 'failed'
                                           WHEN 1 THEN 'succeeded'
                                           WHEN 3 THEN 'cancelled'
                                           ELSE 'other' END,
               h.message
        FROM msdb.dbo.sysjobs   AS j
        JOIN msdb.dbo.sysjobhistory AS h ON h.job_id = j.job_id
        WHERE j.name = N'MABA - Refresh packing data from Priority'
          AND h.step_id = 0
        ORDER BY h.run_date DESC, h.run_time DESC;

    And that the data actually moved:

        SELECT COUNT(*) AS ItemsWithReceivingDate
        FROM dbo.OrderDetailsItems
        WHERE ISNULL(IsDeleted,0)=0 AND CustomerReceivingDate IS NOT NULL;

        SELECT CustomerPackingExists, COUNT(*) AS Details
        FROM dbo.OrderDetails WHERE ISNULL(IsDeleted,0)=0
        GROUP BY CustomerPackingExists;

    As of the first manual run on STAGE: 2,964 items dated, 82 details flagged as customer-packed.
*/
