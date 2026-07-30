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

CREATE OR ALTER PROCEDURE dbo.usp_SyncHealthCheck
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

/* ============================================================================
   הרצה ראשונה:
       EXEC dbo.usp_SyncHealthCheck;

   מומלץ: להריץ כשלב שני בג'וב CalibratorMainLoadProd, ולשלוח התראה כאשר
   section 6 מחזיר ATTENTION. זה סוגר את פער ה"כשל השקט" בלי לגעת בחבילות SSIS.
   ============================================================================ */
