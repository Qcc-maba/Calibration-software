/* Rollback for MBA-1001: every object the etl retirement drops, as it stood on PROD (CalibratorProd)
   captured 2026-11-18 07:38 from the live server by SMO. All tables held 0 rows, so no data.
   Re-run in SSMS against the same database to restore. Order: schema, tables, procedures, grant. */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA [etl] AUTHORIZATION [dbo]');
GO

-- ===== table etl.CalendarEvents (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalendarEvents]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalendarEvents](
	[CalendarEventId] [int] NOT NULL,
	[EventTypeId] [int] NOT NULL,
	[StartDate] [datetime2](0) NOT NULL,
	[EndDate] [datetime2](0) NOT NULL,
	[Comments] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[IsDeleted] [bit] NOT NULL,
	[UpdateUserID] [int] NULL,
	[AWSCalendarEventId] [int] NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.CalendarEventsToParticipants (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalendarEventsToParticipants]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalendarEventsToParticipants](
	[CalendarEventId] [int] NOT NULL,
	[UserId] [int] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[IsDeleted] [bit] NOT NULL,
	[UpdateUserID] [int] NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.CalibGetDataLog (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[CalibGetDataLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[CalibGetDataLog](
	[TableName] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastExecutionDate] [datetime2](0) NULL,
PRIMARY KEY CLUSTERED 
(
	[TableName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- ===== table etl.Cars (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[Cars]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[Cars](
	[CarId] [int] NOT NULL,
	[MabaNumber] [int] NULL,
	[Model] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LicenseNumber] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[Seats] [tinyint] NOT NULL,
	[TreatmentPeriod] [int] NOT NULL,
	[NextTreatmentDate] [date] NOT NULL,
	[NextYearlyTestDate] [date] NOT NULL,
	[OwnerId] [int] NULL,
	[CarStatusId] [int] NOT NULL,
	[CreateDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[AssignedCalibratorId] [int] NULL,
	[UpdateUserID] [int] NULL,
	[IsDeleted] [bit] NOT NULL
) ON [PRIMARY]
END
GO

-- ===== table etl.ETLExecutionLog (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[ETLExecutionLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[ETLExecutionLog](
	[ETLPackageName] [nvarchar](255) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastExecutionDate] [datetime2](0) NULL,
PRIMARY KEY CLUSTERED 
(
	[ETLPackageName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO

-- ===== table etl.SyncRunLog (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[SyncRunLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[SyncRunLog](
	[RunId] [bigint] IDENTITY(1,1) NOT NULL,
	[ProcedureName] [nvarchar](128) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[TargetTable] [nvarchar](128) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[StartedAt] [datetime2](3) NOT NULL,
	[CompletedAt] [datetime2](3) NULL,
	[DurationMs]  AS (datediff(millisecond,[StartedAt],[CompletedAt])),
	[Status] [varchar](20) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[SourceRows] [int] NULL,
	[RowsInserted] [int] NULL,
	[RowsUpdated] [int] NULL,
	[RowsDeleted] [int] NULL,
	[RowsRejected] [int] NULL,
	[ErrorNumber] [int] NULL,
	[ErrorMessage] [nvarchar](2048) COLLATE Latin1_General_100_CI_AI_SC NULL,
 CONSTRAINT [PK_etl_SyncRunLog] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO
SET ANSI_PADDING ON

GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[etl].[SyncRunLog]') AND name = N'IX_etl_SyncRunLog_Proc_Started')
CREATE NONCLUSTERED INDEX [IX_etl_SyncRunLog_Proc_Started] ON [etl].[SyncRunLog]
(
	[ProcedureName] ASC,
	[StartedAt] DESC
)
INCLUDE([Status],[RowsInserted],[RowsUpdated],[RowsRejected]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[DF_etl_SyncRunLog_StartedAt]') AND type = 'D')
BEGIN
ALTER TABLE [etl].[SyncRunLog] ADD  CONSTRAINT [DF_etl_SyncRunLog_StartedAt]  DEFAULT (sysdatetime()) FOR [StartedAt]
END

GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[DF_etl_SyncRunLog_Status]') AND type = 'D')
BEGIN
ALTER TABLE [etl].[SyncRunLog] ADD  CONSTRAINT [DF_etl_SyncRunLog_Status]  DEFAULT ('RUNNING') FOR [Status]
END

GO
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[etl].[CK_etl_SyncRunLog_Status]') AND parent_object_id = OBJECT_ID(N'[etl].[SyncRunLog]'))
ALTER TABLE [etl].[SyncRunLog]  WITH CHECK ADD  CONSTRAINT [CK_etl_SyncRunLog_Status] CHECK  (([Status]='FAILED' OR [Status]='SUCCESS' OR [Status]='RUNNING'))
GO
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[etl].[CK_etl_SyncRunLog_Status]') AND parent_object_id = OBJECT_ID(N'[etl].[SyncRunLog]'))
ALTER TABLE [etl].[SyncRunLog] CHECK CONSTRAINT [CK_etl_SyncRunLog_Status]
GO

-- ===== table etl.Users (0 rows)
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[etl].[Users]') AND type in (N'U'))
BEGIN
CREATE TABLE [etl].[Users](
	[ID] [int] NOT NULL,
	[FirstName] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[LastName] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NOT NULL,
	[FirstNameEng] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[LastNameEng] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Email] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Password] [nvarchar](50) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Phone] [nvarchar](20) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedDate] [datetime2](0) NOT NULL,
	[UpdatedDate] [datetime2](0) NULL,
	[UpdateUserID] [int] NULL,
	[UserAddress] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[LocationArea] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL,
	[Stamp] [nvarchar](200) COLLATE Latin1_General_100_CI_AI_SC NULL
) ON [PRIMARY]
END
GO

-- ===== procedure dbo.usp_SyncHealthCheck
IF OBJECT_ID(N'[dbo].[usp_SyncHealthCheck]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [dbo].[usp_SyncHealthCheck] AS RETURN 0');
GO
/* ============================================================================
   02 — dbo.usp_SyncHealthCheck
   ----------------------------------------------------------------------------
   מה זה פותר:
     היום אין דרך לענות מתוך ה-DB על "האם הסנכרון תקין". טבלאות ה-watermark
     (etl.ETLExecutionLog, etl.CalibGetDataLog) ריקות כי רק החבילות הלא-פעילות
     כותבות אליהן. אם חבילה נופלת — שום דבר לא משתנה ואף אחד לא יודע.

     הפרוצדורה הזו מסיקה את מצב הסנכרון מהנתונים עצמם: טריות, פערי נחיתה מול
     יעד, ושורות שנופלות בשקט בסינונים.

   בטיחות:  קריאה בלבד. אין DML. בטוח להרצה על ייצור בכל עת.
   שימוש:   EXEC dbo.usp_SyncHealthCheck;                  -- סף ברירת מחדל 2 שעות
            EXEC dbo.usp_SyncHealthCheck @StaleHours = 4;
   ============================================================================ */

CREATE   PROCEDURE dbo.usp_SyncHealthCheck
    @StaleHours INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @now DATETIME2(6) = GETDATE();

    /* ---------- 1. טריות: מתי כל טבלת ליבה נגעה לאחרונה ---------- */
    ;WITH freshness AS (
        SELECT 'Customers'        AS table_name,
               MAX(CreateDate)    AS last_insert,
               MAX(UpdatedDate)   AS last_update,
               COUNT(*)           AS row_count
        FROM dbo.Customers
        UNION ALL
        SELECT 'OrderWorkPlans',   MAX(CreatedDate), MAX(UpdatedDate), COUNT(*) FROM dbo.OrderWorkPlans
        UNION ALL
        SELECT 'OrderDetails',     MAX(CreatedDate), MAX(UpdatedDate), COUNT(*) FROM dbo.OrderDetails
        UNION ALL
        SELECT 'OrderDetailsItems',MAX(CreatedDate), MAX(UpdatedDate), COUNT(*) FROM dbo.OrderDetailsItems
        UNION ALL
        SELECT 'CustomerContacts', MAX(CreateDate),  MAX(UpdatedDate), COUNT(*) FROM dbo.CustomerContacts
        UNION ALL
        SELECT 'CustomerSites',    MAX(CreateDate),  MAX(UpdatedDate), COUNT(*) FROM dbo.CustomerSites
    )
    SELECT
        '1. FRESHNESS'                                             AS section,
        table_name,
        row_count,
        last_insert,
        last_update,
        DATEDIFF(MINUTE,
                 (SELECT MAX(v) FROM (VALUES (last_insert),(last_update)) AS t(v)),
                 @now)                                             AS minutes_since_touch,
        CASE
            WHEN (SELECT MAX(v) FROM (VALUES (last_insert),(last_update)) AS t(v)) IS NULL
                THEN 'NO DATA'
            WHEN DATEDIFF(HOUR,
                     (SELECT MAX(v) FROM (VALUES (last_insert),(last_update)) AS t(v)),
                     @now) > @StaleHours
                THEN 'STALE'
            ELSE 'OK'
        END                                                        AS status
    FROM freshness
    ORDER BY status DESC, table_name;

    /* ---------- 2. פער נחיתה מול יעד ----------
       הערה: פער חיובי (יעד > נחיתה) מצביע על שורות שאין להן מקור — סימן
       להיעדר WHEN NOT MATCHED BY SOURCE, כלומר מחיקות שלא מגיעות. */
    SELECT
        '2. STAGING DRIFT'                                         AS section,
        d.staging_table,
        d.staging_rows,
        d.target_table,
        d.target_rows,
        d.target_rows - d.staging_rows                             AS drift,
        CASE
            WHEN d.staging_rows = 0                THEN 'STAGING EMPTY'
            WHEN d.target_rows - d.staging_rows > 0 THEN 'ORPHANS IN TARGET'
            WHEN d.target_rows - d.staging_rows < 0 THEN 'ROWS DROPPED'
            ELSE 'OK'
        END                                                        AS status
    FROM (
        SELECT 'stg_Customers'       AS staging_table, (SELECT COUNT(*) FROM stg.stg_Customers)       AS staging_rows,
               'Customers'           AS target_table,  (SELECT COUNT(*) FROM dbo.Customers)           AS target_rows
        UNION ALL
        SELECT 'stg_CustomerSites',    (SELECT COUNT(*) FROM stg.stg_CustomerSites),
               'CustomerSites',        (SELECT COUNT(*) FROM dbo.CustomerSites)
        UNION ALL
        SELECT 'stg_CustomerContacts', (SELECT COUNT(*) FROM stg.stg_CustomerContacts),
               'CustomerContacts',     (SELECT COUNT(*) FROM dbo.CustomerContacts)
        UNION ALL
        SELECT 'stg_CustomerRemarks',  (SELECT COUNT(*) FROM stg.stg_CustomerRemarks),
               'CustomerRemarks',      (SELECT COUNT(*) FROM dbo.CustomerRemarks)
        UNION ALL
        SELECT 'stg_MabaComments',     (SELECT COUNT(*) FROM stg.stg_MabaComments),
               'MabaComments',         (SELECT COUNT(*) FROM dbo.MabaComments)
    ) AS d
    ORDER BY ABS(d.target_rows - d.staging_rows) DESC;

    /* ---------- 3. נפילות שקטות בסינוני MergeOrdersData ----------
       שורה 283 בפרוצדורה מסננת: WHERE OrderDetailId IS NOT NULL AND Doc IS NOT NULL
       השורות שנופלות שם לא נרשמות בשום מקום. כאן סופרים אותן. */
    SELECT
        '3. SILENT DROPS'                                          AS section,
        COUNT(*)                                                   AS staging_rows_total,
        SUM(CASE WHEN o.Doc IS NULL THEN 1 ELSE 0 END)             AS dropped_missing_doc,
        SUM(CASE WHEN o.OrderDetailId IS NULL THEN 1 ELSE 0 END)   AS dropped_missing_detail_id,
        SUM(CASE WHEN o.Doc IS NULL OR o.OrderDetailId IS NULL
                 THEN 1 ELSE 0 END)                                AS dropped_total,
        CAST(100.0 * SUM(CASE WHEN o.Doc IS NULL OR o.OrderDetailId IS NULL THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0) AS DECIMAL(5,2))                 AS dropped_pct
    FROM stg.stg_Orders AS o;

    /* ---------- 4. שלמות היררכיית ההזמנות ---------- */
    SELECT
        '4. ORDER HIERARCHY'                                       AS section,
        (SELECT COUNT(*) FROM dbo.OrderWorkPlans)                  AS work_plans,
        (SELECT COUNT(*) FROM dbo.OrderDetails)                    AS details,
        (SELECT COUNT(*) FROM dbo.OrderDetailsItems)               AS items,
        (SELECT COUNT(*) FROM dbo.OrderDetails AS od
          WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS i
                            WHERE i.OrderDetailId = od.OrderDetailId))
                                                                   AS details_without_items,
        (SELECT COUNT(*) FROM dbo.OrderWorkPlans AS wp
          WHERE wp.CustomerId IS NULL)                             AS work_plans_without_customer;

    /* ---------- 5. פערי קישור ידועים ---------- */
    SELECT
        '5. LINKAGE GAPS'                                          AS section,
        (SELECT COUNT(*) FROM dbo.Users)                           AS users_total,
        (SELECT COUNT(*) FROM dbo.Users WHERE CustomerId IS NULL)  AS users_without_customer,
        (SELECT COUNT(*) FROM dbo.Users AS u
          JOIN dbo.UserRoles AS r ON r.UserRoleId = u.UserRoleId
         WHERE r.UserRoleName = 'Customer' AND u.CustomerId IS NULL)
                                                                   AS portal_users_unlinked,
        (SELECT COUNT(*) FROM dbo.Customers WHERE CustomerSupportContactId IS NULL)
                                                                   AS customers_without_agent,
        (SELECT COUNT(*) FROM dbo.Statuses
          WHERE Code IS NULL OR LTRIM(RTRIM(Code)) = '')           AS statuses_without_code;

    /* ---------- 6. סיכום ---------- */
    DECLARE @stale INT = (
        SELECT COUNT(*) FROM (
            SELECT MAX(CreateDate)  AS t FROM dbo.Customers
            UNION ALL SELECT MAX(CreatedDate) FROM dbo.OrderWorkPlans
            UNION ALL SELECT MAX(CreatedDate) FROM dbo.OrderDetails
            UNION ALL SELECT MAX(CreatedDate) FROM dbo.OrderDetailsItems
        ) AS x
        WHERE x.t IS NULL OR DATEDIFF(HOUR, x.t, @now) > @StaleHours
    );

    SELECT
        '6. VERDICT'                                               AS section,
        @now                                                       AS checked_at,
        @StaleHours                                                AS stale_threshold_hours,
        @stale                                                     AS stale_core_tables,
        CASE WHEN @stale = 0 THEN 'SYNC APPEARS HEALTHY'
             ELSE 'ATTENTION - ' + CAST(@stale AS VARCHAR(10)) + ' core table(s) stale' END
                                                                   AS verdict;
END;

GO

-- ===== procedure etl.CalibGetDataLogGetSet
IF OBJECT_ID(N'[etl].[CalibGetDataLogGetSet]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[CalibGetDataLogGetSet] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[CalibGetDataLogGetSet]
@TableName [NVARCHAR](255),
@LastExecutionDate DATETIME2(0) = NULL
AS
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName)
INSERT [etl].[CalibGetDataLog]([TableName],LastExecutionDate)
VALUES(@TableName,'1900-01-01')

IF EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName) and @LastExecutionDate IS NOT NULL
UPDATE [etl].[CalibGetDataLog]
SET LastExecutionDate = @LastExecutionDate
WHERE [TableName] = @TableName

SELECT LastExecutionDate
FROM [etl].[CalibGetDataLog]
WHERE [TableName] = @TableName

GO

-- ===== procedure etl.MergeCalendarEventsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCalendarEventsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCalendarEventsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCalendarEventsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEvents] AS dest
USING (
	SELECT [CalendarEventId]
		,[EventTypeId]
		,[StartDate]
		,[EndDate]
		,[Comments]
		,[CreatedDate]
		,[UpdatedDate]
		,[IsDeleted]
		,0 as [UpdateUserID]
		,[AWSCalendarEventId]
	FROM [etl].[CalendarEvents]
	) AS source
	ON dest.AWSCalendarEventId = source.CalendarEventId
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[EventTypeId] = source.[EventTypeId]
			,dest.[StartDate] = source.[StartDate]
			,dest.[EndDate] = source.[EndDate]
			,dest.[Comments] = source.[Comments]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [EventTypeId]
			,[StartDate]
			,[EndDate]
			,[Comments]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			,[AWSCalendarEventId]
			)
		VALUES (
			 source.[EventTypeId]
			,source.[StartDate]
			,source.[EndDate]
			,source.[Comments]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			,source.[CalendarEventId]
			);

GO

-- ===== procedure etl.MergeCalendarEventsToParticipantsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCalendarEventsToParticipantsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCalendarEventsToParticipantsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCalendarEventsToParticipantsToOnPrem]
AS
MERGE INTO [dbo].[CalendarEventsToParticipants] AS dest
USING (
	SELECT 
	     ce.[CalendarEventId]
		,u1.ID as [UserId]
		,ctp.[CreatedDate]
		,ctp.[UpdatedDate]
		,ctp.[IsDeleted]
		,u2.ID as [UpdateUserID]
	FROM [etl].[CalendarEventsToParticipants] as ctp
	JOIN [dbo].[CalendarEvents] as ce ON ce.AWSCalendarEventId = ctp.[CalendarEventId]
	LEFT JOIN [dbo].[Users] as u1 ON u1.AWSID = ctp.[UserId]
	LEFT JOIN [dbo].[Users] as u2 ON u2.AWSID = ctp.[UpdateUserID]
	) AS source
	ON dest.[CalendarEventId] = source.[CalendarEventId] AND
	   dest.[UserId] = source.[UserId] AND
	   dest.[CreatedDate] = source.[CreatedDate] 
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[IsDeleted] = source.[IsDeleted]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[CalendarEventId]
			,[UserId]
			,[CreatedDate]
			,[UpdatedDate]
			,[IsDeleted]
			,[UpdateUserID]
			)
		VALUES (
			source.[CalendarEventId]
			,source.[UserId]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[IsDeleted]
			,source.[UpdateUserID]
			);

GO

-- ===== procedure etl.MergeCarsToOnPrem
IF OBJECT_ID(N'[etl].[MergeCarsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeCarsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [etl].[MergeCarsToOnPrem]
AS
SELECT 1
/*
MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT 
	     c.[CarId]
		,c.[MabaNumber]
		,c.[Model]
		,c.[LicenseNumber]
		,c.[Seats]
		,c.[TreatmentPeriod]
		,c.[NextTreatmentDate]
		,c.[NextYearlyTestDate]
		,u.ID as [OwnerId]
		,c.[CarStatusId]
		,c.[CreateDate]
		,c.[UpdatedDate]
		,u1.ID as[AssignedCalibratorId]
		,0 as [UpdateUserID]
		,c.[IsDeleted]
	FROM [etl].[Cars] as c
	LEFT JOIN [dbo].[Users] as u ON c.[OwnerId] = u.AWSID
	LEFT JOIN [dbo].[Users] as u1 ON c.[AssignedCalibratorId] = u1.AWSID
	) AS source
	ON dest.AWSCarId = source.CarId
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MabaNumber] = source.[MabaNumber]
			,dest.[Model] = source.[Model]
			,dest.[LicenseNumber] = source.[LicenseNumber]
			,dest.[Seats] = source.[Seats]
			,dest.[TreatmentPeriod] = source.[TreatmentPeriod]
			,dest.[NextTreatmentDate] = source.[NextTreatmentDate]
			,dest.[NextYearlyTestDate] = source.[NextYearlyTestDate]
			,dest.[OwnerId] = source.[OwnerId]
			,dest.[CarStatusId] = source.[CarStatusId]
			,dest.[CreateDate] = source.[CreateDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[AssignedCalibratorId] = source.[AssignedCalibratorId]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[IsDeleted] = source.[IsDeleted]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaNumber]
			,[Model]
			,[LicenseNumber]
			,[Seats]
			,[TreatmentPeriod]
			,[NextTreatmentDate]
			,[NextYearlyTestDate]
			,[OwnerId]
			,[CarStatusId]
			,[CreateDate]
			,[UpdatedDate]
			,[AssignedCalibratorId]
			,[UpdateUserID]
			,[IsDeleted]
			,[AWSCarId]
			)
		VALUES (
             source.[MabaNumber]
			,source.[Model]
			,source.[LicenseNumber]
			,source.[Seats]
			,source.[TreatmentPeriod]
			,source.[NextTreatmentDate]
			,source.[NextYearlyTestDate]
			,source.[OwnerId]
			,source.[CarStatusId]
			,source.[CreateDate]
			,source.[UpdatedDate]
			,source.[AssignedCalibratorId]
			,source.[UpdateUserID]
			,source.[IsDeleted]
			,source.[CarId]
			);
*/

GO

-- ===== procedure etl.MergeUsersToOnPrem
IF OBJECT_ID(N'[etl].[MergeUsersToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[MergeUsersToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE  [etl].[MergeUsersToOnPrem]
AS
MERGE INTO [dbo].[Users] AS dest
USING (
	SELECT [ID]
		,[FirstName]
		,[LastName]
		,[FirstNameEng]
		,[LastNameEng]
		,[Email]
		,[Password]
		,[Phone]
		,[IsActive]
		,[CreatedDate]
		,[UpdatedDate]
		,0 as [UpdateUserID]
		,[UserAddress]
		,[LocationArea]
		,[Stamp]
	FROM [etl].[Users]
	) AS source
	ON dest.AWSID = source.ID
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[FirstName] = source.[FirstName]
			,dest.[LastName] = source.[LastName]
			,dest.[FirstNameEng] = source.[FirstNameEng]
			,dest.[LastNameEng] = source.[LastNameEng]
			,dest.[Email] = source.[Email]
			,dest.[Password] = source.[Password]
			,dest.[Phone] = source.[Phone]
			,dest.[IsActive] = source.[IsActive]
			,dest.[CreatedDate] = source.[CreatedDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[UserAddress] = source.[UserAddress]
			,dest.[LocationArea] = source.[LocationArea]
			,dest.[Stamp] = source.[Stamp]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [FirstName]
			,[LastName]
			,[FirstNameEng]
			,[LastNameEng]
			,[Email]
			,[Password]
			,[Phone]
			,[IsActive]
			,[CreatedDate]
			,[UpdatedDate]
			,[UpdateUserID]
			,[UserAddress]
			,[LocationArea]
			,[Stamp]
			,[AWSID]
			)
		VALUES (
             source.[FirstName]
			,source.[LastName]
			,source.[FirstNameEng]
			,source.[LastNameEng]
			,source.[Email]
			,source.[Password]
			,source.[Phone]
			,source.[IsActive]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[UpdateUserID]
			,source.[UserAddress]
			,source.[LocationArea]
			,source.[Stamp]
			,source.[ID]
			);

GO

-- ===== procedure etl.usp_SyncRunEnd
IF OBJECT_ID(N'[etl].[usp_SyncRunEnd]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[usp_SyncRunEnd] AS RETURN 0');
GO
ALTER PROCEDURE etl.usp_SyncRunEnd
    @RunId        BIGINT,
    @Status       VARCHAR(20),
    @RowsInserted INT            = NULL,
    @RowsUpdated  INT            = NULL,
    @RowsDeleted  INT            = NULL,
    @RowsRejected INT            = NULL,
    @ErrorNumber  INT            = NULL,
    @ErrorMessage NVARCHAR(2048) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE etl.SyncRunLog
       SET CompletedAt  = SYSDATETIME(),
           Status       = @Status,
           RowsInserted = @RowsInserted,
           RowsUpdated  = @RowsUpdated,
           RowsDeleted  = @RowsDeleted,
           RowsRejected = @RowsRejected,
           ErrorNumber  = @ErrorNumber,
           ErrorMessage = @ErrorMessage
     WHERE RunId = @RunId;
END

GO

-- ===== procedure etl.usp_SyncRunReport
IF OBJECT_ID(N'[etl].[usp_SyncRunReport]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[usp_SyncRunReport] AS RETURN 0');
GO


/* --- ׳“׳•׳— ׳׳¦׳‘: ׳׳” ׳¨׳¥, ׳׳” ׳ ׳›׳©׳, ׳׳” ׳×׳§׳•׳¢ ------------------------------------ */
CREATE   PROCEDURE etl.usp_SyncRunReport
    @Hours INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (200)
           RunId, ProcedureName, TargetTable, Status,
           StartedAt, CompletedAt, DurationMs,
           SourceRows, RowsInserted, RowsUpdated, RowsDeleted, RowsRejected,
           CASE WHEN SourceRows > 0
                THEN CAST(100.0 * ISNULL(RowsRejected,0) / SourceRows AS DECIMAL(5,2))
           END AS RejectedPct,
           ErrorMessage
      FROM etl.SyncRunLog
     WHERE StartedAt >= DATEADD(HOUR, -@Hours, SYSDATETIME())
     ORDER BY StartedAt DESC;

    /* ׳¨׳™׳¦׳•׳× ׳×׳§׳•׳¢׳•׳×: RUNNING ׳™׳•׳×׳¨ ׳׳©׳¢׳” */
    SELECT 'STUCK RUNS' AS alert, RunId, ProcedureName, StartedAt,
           DATEDIFF(MINUTE, StartedAt, SYSDATETIME()) AS running_minutes
      FROM etl.SyncRunLog
     WHERE Status = 'RUNNING'
       AND StartedAt < DATEADD(HOUR, -1, SYSDATETIME())
     ORDER BY StartedAt;

    /* ׳¡׳™׳›׳•׳ ׳׳₪׳™ ׳₪׳¨׳•׳¦׳“׳•׳¨׳” */
    SELECT ProcedureName,
           COUNT(*)                                              AS runs,
           SUM(CASE WHEN Status='FAILED'  THEN 1 ELSE 0 END)      AS failed,
           SUM(CASE WHEN Status='RUNNING' THEN 1 ELSE 0 END)      AS still_running,
           AVG(DurationMs)                                        AS avg_ms,
           SUM(ISNULL(RowsRejected,0))                            AS total_rejected
      FROM etl.SyncRunLog
     WHERE StartedAt >= DATEADD(HOUR, -@Hours, SYSDATETIME())
     GROUP BY ProcedureName
     ORDER BY failed DESC, total_rejected DESC;
END

GO

-- ===== procedure etl.usp_SyncRunStart
IF OBJECT_ID(N'[etl].[usp_SyncRunStart]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [etl].[usp_SyncRunStart] AS RETURN 0');
GO


/* ==========================================================================
   ׳—׳׳§ ׳‘ ג€” ׳₪׳¨׳•׳¦׳“׳•׳¨׳•׳× ׳”׳¨׳™׳©׳•׳
   ========================================================================== */

CREATE   PROCEDURE etl.usp_SyncRunStart
    @ProcedureName NVARCHAR(128),
    @TargetTable   NVARCHAR(128) = NULL,
    @SourceRows    INT           = NULL,
    @RunId         BIGINT        OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT etl.SyncRunLog (ProcedureName, TargetTable, SourceRows, Status)
    VALUES (@ProcedureName, @TargetTable, @SourceRows, 'RUNNING');
    SET @RunId = SCOPE_IDENTITY();
END

GO

-- ===== procedure stg.MergeCarsToOnPrem
IF OBJECT_ID(N'[stg].[MergeCarsToOnPrem]', N'P') IS NULL EXEC(N'CREATE PROCEDURE [stg].[MergeCarsToOnPrem] AS RETURN 0');
GO
ALTER PROCEDURE [stg].[MergeCarsToOnPrem]
AS
SELECT 1
/*MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT [CarId]
		,[MabaNumber]
		,[Model]
		,[LicenseNumber]
		,[Seats]
		,[TreatmentPeriod]
		,[NextTreatmentDate]
		,[NextYearlyTestDate]
		,[OwnerId]
		,[CarStatusId]
		,[CreateDate]
		,[UpdatedDate]
		,[AssignedCalibratorId]
		,[UpdateUserID]
		,[IsDeleted]
	FROM [stg].[Cars]
	) AS source
	ON dest.AWSCarId = source.CarId
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MabaNumber] = source.[MabaNumber]
			,dest.[Model] = source.[Model]
			,dest.[LicenseNumber] = source.[LicenseNumber]
			,dest.[Seats] = source.[Seats]
			,dest.[TreatmentPeriod] = source.[TreatmentPeriod]
			,dest.[NextTreatmentDate] = source.[NextTreatmentDate]
			,dest.[NextYearlyTestDate] = source.[NextYearlyTestDate]
			,dest.[OwnerId] = source.[OwnerId]
			,dest.[CarStatusId] = source.[CarStatusId]
			,dest.[CreateDate] = source.[CreateDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[AssignedCalibratorId] = source.[AssignedCalibratorId]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[IsDeleted] = source.[IsDeleted]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaNumber]
			,[Model]
			,[LicenseNumber]
			,[Seats]
			,[TreatmentPeriod]
			,[NextTreatmentDate]
			,[NextYearlyTestDate]
			,[OwnerId]
			,[CarStatusId]
			,[CreateDate]
			,[UpdatedDate]
			,[AssignedCalibratorId]
			,[UpdateUserID]
			,[IsDeleted]
			,[AWSCarId]
			)
		VALUES (
             source.[MabaNumber]
			,source.[Model]
			,source.[LicenseNumber]
			,source.[Seats]
			,source.[TreatmentPeriod]
			,source.[NextTreatmentDate]
			,source.[NextYearlyTestDate]
			,source.[OwnerId]
			,source.[CarStatusId]
			,source.[CreateDate]
			,source.[UpdatedDate]
			,source.[AssignedCalibratorId]
			,source.[UpdateUserID]
			,source.[IsDeleted]
			,source.[CarId]
			);
*/

GO

GRANT EXECUTE ON SCHEMA::[etl] TO [ed];
GO
