/*
    Open items as of 07/09/2026, with the work already done and the exact statement to run.
    Everything here was measured, not assumed. Nothing in this file has been executed.

    Run on MBACUSTWEB\QCC (51.17.121.203\QCC). Sections 1 and 2 need sysadmin.
*/

/* ==========================================================================================
   1. SSIS environment passwords are stored in clear text.            DECISION + SCHEDULED WORK

   Every variable in every environment has Sensitive unchecked, so the connection strings -
   including Priority's - carry their passwords in readable text. Anyone who can open
   Integration Services Catalogs -> SSISDB -> <folder> -> Environments -> Properties reads them.

   Confirmed by the fact that we lifted the 'ed' password straight out of AWSCalibrator today.

   This cannot be flipped in place: ticking Sensitive blanks the stored value, so the ETL stops
   until each password is re-entered. Do it deliberately, one folder at a time:

     a. Note the current value of every variable in CalibratorProd\Prod.
     b. Tick Sensitive on each password-bearing variable, re-enter the value, OK.
     c. EXEC msdb.dbo.sp_start_job @job_name = N'CalibratorMainLoadProd'; confirm it succeeds.
     d. Only then repeat for the CalibratorSync folder.

   Sensitive values are encrypted with the database master key, so back that key up first if it
   has never been exported.
   ========================================================================================== */
SELECT f.name AS folder_name, e.name AS environment_name, v.name AS variable_name, v.sensitive
FROM SSISDB.catalog.environment_variables AS v
JOIN SSISDB.catalog.environments        AS e ON e.environment_id = v.environment_id
JOIN SSISDB.catalog.folders             AS f ON f.folder_id      = e.folder_id
ORDER BY f.name, e.name, v.name;
-- Expect every row to read sensitive = 0 today. The goal is 1 on the password-bearing ones.


/* ==========================================================================================
   2. Database users with no matching login.                                     VERIFY FIRST

   An earlier reading of this from app_prod claimed eliran, ariel, SlavaMaba and app_stage were
   all orphaned. That was WRONG: app_prod lacks VIEW ANY DEFINITION, so sys.server_principals
   returned only itself and sa, and the LEFT JOIN made every user look orphaned. Re-run as
   sysadmin - the result below is the real one.
   ========================================================================================== */
SELECT DbName   = DB_NAME(),
       UserName = dp.name,
       Status_  = CASE WHEN sp.sid IS NULL THEN 'ORPHANED' ELSE 'ok' END,
       dp.create_date
FROM CalibratorProd.sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp ON sp.sid = dp.sid
WHERE dp.type IN ('S','U') AND dp.principal_id > 4
ORDER BY Status_, dp.name;
-- For any genuinely orphaned user that is still wanted:
--   CREATE LOGIN [<name>] WITH PASSWORD = N'...';
--   USE [<db>]; ALTER USER [<name>] WITH LOGIN = [<name>];
-- For one nobody uses, dropping it is tidier - but that is a decision, not a repair.


/* ==========================================================================================
   3. Three dead Copy Database Wizard jobs.                                    SAFE TO DELETE

   Measured: all three are disabled, none is scheduled, and each last ran in Nov-Dec 2024 and
   failed. They are leftovers of a one-off database copy.

     CDW_MbaCustWeb_QCC_MbaCustWeb_QCC_0     last run 26/11/2024  FAILED
     CDW_pri-test_PRI_MbaCustWeb_QCC_0       last run 26/12/2024  FAILED
     CDW_pri-test_PRI_MbaCustWeb_QCC_0_1     last run 26/12/2024  FAILED
   ========================================================================================== */
-- EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_MbaCustWeb_QCC_MbaCustWeb_QCC_0';
-- EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_pri-test_PRI_MbaCustWeb_QCC_0';
-- EXEC msdb.dbo.sp_delete_job @job_name = N'CDW_pri-test_PRI_MbaCustWeb_QCC_0_1';
-- Commented out on purpose: deleting jobs is not something to run by accident.


/* ==========================================================================================
   4. The two disabled backup jobs.                                          NOT AN EMERGENCY

   Calibrator_Backup and DailyDatabaseBackup are both disabled and both last failed in 2025.
   That looks alarming and is not: msdb.dbo.backupset shows every database backed up today at
   07:50:39, so something else does the work. Confirm with the query below before touching them.

   The real question is the recovery model. Every database is SIMPLE with no log backups, so
   recovery is only ever to the last full backup - a window of up to 24 hours. That is a
   business decision about acceptable data loss, not a fault.
   ========================================================================================== */
SELECT d.name,
       Recovery_ = d.recovery_model_desc,
       LastFull  = MAX(CASE WHEN b.type = 'D' THEN b.backup_finish_date END),
       LastLog   = MAX(CASE WHEN b.type = 'L' THEN b.backup_finish_date END)
FROM sys.databases AS d
LEFT JOIN msdb.dbo.backupset AS b ON b.database_name = d.name
WHERE d.database_id > 4
GROUP BY d.name, d.recovery_model_desc
ORDER BY d.name;
-- Either delete the two dead jobs, or fix and re-enable them so the job list stops lying about
-- what protects this server.


/* ==========================================================================================
   5. Duplicate e-mail addresses.                                        NEEDS A MERGE DECISION

   Measured on CalibratorProd: 38 addresses are shared by 79 accounts, and ALL 79 are active.
   GetLoginUser resolves by e-mail, so which account you get is arbitrary. Worst offenders:

     sales@gelectronic.co.il   4 accounts, 4 active
     lindar@hadassah.org.il    3 accounts, 3 active
     ...36 more with 2 each

   This is not something to fix blind - each pair has to be judged: same person twice, or two
   people sharing a mailbox. The list below is the working set.
   ========================================================================================== */
SELECT Email    = LOWER(LTRIM(RTRIM(u.Email))),
       Accounts = COUNT(*),
       Active_  = SUM(CASE WHEN ISNULL(u.IsActive,0) = 1 THEN 1 ELSE 0 END),
       Ids      = STRING_AGG(CAST(u.ID AS varchar(10)), ','),
       Names    = STRING_AGG(u.FirstName + ' ' + u.LastName, ' | ')
FROM CalibratorProd.dbo.Users AS u
WHERE u.Email IS NOT NULL AND LTRIM(RTRIM(u.Email)) <> ''
GROUP BY LOWER(LTRIM(RTRIM(u.Email)))
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- Once a pair is judged a duplicate, deactivate the redundant account rather than deleting it -
-- calibration history references these ids:
--   UPDATE CalibratorProd.dbo.Users SET IsActive = 0, UpdatedDate = SYSUTCDATETIME()
--   WHERE ID = <the redundant id>;


/* ==========================================================================================
   6. Malformed e-mail addresses.                                      NEEDS THE REAL ADDRESSES

   Five accounts, all active. CK_Users_Email_Format was deployed WITH NOCHECK, so these predate
   it and are not blocked by it - but none of them can receive mail, which matters now that
   order approval and OTP login both go by e-mail.

     ID    0  N/A                             ETL / ETL          - a system account, leave it
     ID   35  0523862631                      אלון אזולאי        - a phone number in the field
     ID  724  .                               אלה גולוב
     ID 2928  a_yekev@netvisionnet.           אנטון יקב          - truncated, no TLD
     ID 3110  dan.fischeremedi-fischer.com    דן פישר            - the @ is missing

   ID 3110 looks recoverable by eye (dan.fischer@medi-fischer.com) but do not guess - confirm
   with the customer. ID 0 is the ETL account and should stay as it is.
   ========================================================================================== */
SELECT u.ID, u.Email, u.FirstName, u.LastName, u.IsActive
FROM CalibratorProd.dbo.Users AS u
WHERE u.Email IS NULL OR LEN(LTRIM(RTRIM(u.Email))) < 6 OR u.Email NOT LIKE '%_@_%._%'
ORDER BY u.ID;


/* ==========================================================================================
   7. Where the packing filters really belong.                                    BACKEND WORK

   getPackingOrders passed @ActualCalibrationDate, @CalibrationStatus, @CustomerName,
   @CustomerAddress, @ShippingAddress, @ShippingMethod, @CustomerReceivingDate and
   @SpecialTreatment to GetDevicesUngroupedByOrder. Neither that procedure nor its V2 declares
   any of them, so SQL Server rejected the whole call and the screen returned 500 for eight of
   its ten filters. PR #117 filters those rows in JS instead, which restores the screen.

   The better home is still the procedure, so the database narrows before returning rows. Run
   this to see what it does declare today.
   ========================================================================================== */
SELECT ProcName = OBJECT_NAME(p.object_id), p.name, TypeName = t.name
FROM CalibratorProd.sys.parameters AS p
JOIN CalibratorProd.sys.types AS t ON t.user_type_id = p.user_type_id
WHERE p.object_id IN (OBJECT_ID('CalibratorProd.dbo.GetDevicesUngroupedByOrder'),
                      OBJECT_ID('CalibratorProd.dbo.GetDevicesUngroupedByOrderV2'))
ORDER BY ProcName, p.parameter_id;


/* ==========================================================================================
   8. AWSCalibrator and OnPremCalibrator point at the same machine.          QUESTION FOR THE
                                                                             SYSTEM OWNER
   Both resolve to Data Source=51.17.121.203\QCC,1433 with User ID=ed, differing only in
   Initial Catalog: CalibratorProd for one, Calibrator for the other. So the package named
   "StartSyncMasterToAWS" syncs between two databases on one box rather than between on-prem and
   the cloud. Either the name is historical, or one of these connection strings is pointed at
   the wrong server. Worth an answer before anyone relies on the distinction.
   ========================================================================================== */
SELECT v.name, LEFT(CONVERT(nvarchar(max), v.value), 55) AS starts_with
FROM SSISDB.catalog.environment_variables AS v
WHERE v.name IN (N'AWSCalibrator', N'OnPremCalibrator');
