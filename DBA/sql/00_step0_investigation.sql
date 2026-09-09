/* ============================================================================
   00 — שלב 0: אבחון קריאה-בלבד  (MIGRATION-AND-FIX-PLAN §4 שלב 0)
   ----------------------------------------------------------------------------
   מטרה:  לסגור את הפערים שנותרו במיפוי לפני שנוגעים בקוד או ב-view. כל שאילתה
          כאן היא SELECT בלבד — אין INSERT/UPDATE/DELETE/DDL, בטוח להרצה על ייצור
          (CalibratorProd @ MbaCustWeb\QCC) בכל עת.

   מה בפנים (מיפוי לתוכניות):
       Q1  ספירת אובדן מדויקת על *כל* קבוצות ההזמנה — לא הַשְׁלָכָה מ-400
           (MIGRATION-AND-FIX-PLAN 0.4 · SYNC-IMPROVEMENT-PLAN ב.6)
       Q2  קריסת יוני 2026 — 128 קבוצות מול ~1,500 בחודש טיפוסי (0.5 / ב.9)
       Q3  התפלגות גיל של קבוצות-ללא-פריט (מול חלון 16.7 הימים ב-view)
       Q4  שימוש ב-linked server (0.3)

   ⚠ הנחות סכימה (אין גישה חיה בזמן הכתיבה — מבוסס על השמות בתסריטים ובמסמכי DB-*):
       • "קבוצת מכשירים" = שורת dbo.OrderDetails; "פריט" = dbo.OrderDetailsItems.
         "קבוצה ללא פריט" = OrderDetails שאין לה אף OrderDetailsItems (כמו §4 ב-02).
       • תאריך העסקי הזמין הוא OrderWorkPlans.WorkPlanOpenDate. לפי SYNC §0א הוא נגזר
         מ-o.CURDATE (תאריך השינוי האחרון) וממותג בטעות כ-OpenDate — הפרשנות מטה
         מתחשבת בכך. dbo.OrderDetails.CreatedDate הוא זמן ה-merge (GETDATE()) ולכן
         אינו משקף חודש עסקי.
       • Q1 החוצה-שרתים מניחה linked server ל-Priority ושמות amaba.dbo.MBA_DOCUMENTS /
         ORDERITEMS / TRANSORDER (מ-SYNC §0א). שם ה-linked server ומפתחות ההצטרפות
         חייבים אימות מול המסד — Q4 מגלה את שם השרת, וה-JOIN מסומן <<< CONFIRM.
   ============================================================================ */

SET NOCOUNT ON;
GO


/* ==========================================================================
   Q1 — ספירת האובדן המדויקת (מחליף את ההשלכה מ-400)
   ==========================================================================
   §0א הראה: מדגם 400 קבוצות ישנות → 263/385 = 68% קיבלו מסמך כיול ב-Priority
   ולא הגיעו ל-Calibrator, ומכאן הַשְׁלָכָה של ~5,200. כאן סופרים במדויק. */

/* --- Q1a: הבסיס הוודאי (מקומי, ללא linked server) -----------------------
   כמה קבוצות מכשירים קיימות, כמה בלי אף פריט, ובאיזה אחוז. מספר מדויק, לא הַשְׁלָכָה.
   זה מחליף את "78%" במספר עדכני אמיתי. */
SELECT
    'Q1a. GROUPS WITHOUT ITEM (local, exact)'                  AS section,
    COUNT(*)                                                   AS order_details_total,
    SUM(CASE WHEN i.OrderDetailId IS NULL THEN 1 ELSE 0 END)   AS groups_without_item,
    SUM(CASE WHEN i.OrderDetailId IS NOT NULL THEN 1 ELSE 0 END) AS groups_with_item,
    CAST(100.0 * SUM(CASE WHEN i.OrderDetailId IS NULL THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*),0) AS DECIMAL(5,2))                 AS pct_without_item
FROM dbo.OrderDetails AS od
OUTER APPLY (
    SELECT TOP (1) 1 AS OrderDetailId
    FROM dbo.OrderDetailsItems AS x
    WHERE x.OrderDetailId = od.OrderDetailId
) AS i;
GO

/* --- Q1b: האובדן האמיתי (חוצה-שרתים) — כמה מהקבוצות-ללא-פריט כבר כוילו ב-Priority
   זו הגרסה המדויקת של בדיקת המדגם: מכל קבוצה-ללא-פריט, האם קיים לה מסמך כיול
   ב-Priority (MBA_DOCUMENTS.DOC_N). הספירה כאן מחליפה את ה-263/385 המושלך.

   ⚠ קריאה-בלבד גם חוצה-שרתים, אבל:
     • החליפו [PRIORITY_LS] בשם ה-linked server האמיתי (ראו Q4).
     • אשרו את מפתח ההצטרפות מ-dbo.OrderDetails ל-Priority. ההנחה כאן:
       OrderDetails.OrderDetailSourceId  ↔  Priority ORDERITEMS.<key>  <<< CONFIRM
       ומשם ל-MBA_DOCUMENTS על אותה הזמנה/פריט.
     • אם אין linked server — להריץ את הצד המקומי (Q1a) ולהצליב ידנית מול ייצוא
       מ-Priority, או להשתמש ב-OPENQUERY (תבנית בתחתית Q1b).

   התבנית להרצה לאחר אישור השמות: */
/*
SELECT
    'Q1b. LOST CALIBRATIONS (cross-server, exact)'             AS section,
    COUNT(*)                                                   AS groups_without_item,
    SUM(CASE WHEN p.DOC_N IS NOT NULL THEN 1 ELSE 0 END)       AS calibrated_in_priority_but_missing,
    CAST(100.0 * SUM(CASE WHEN p.DOC_N IS NOT NULL THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*),0) AS DECIMAL(5,2))                 AS pct_actually_lost
FROM dbo.OrderDetails AS od
LEFT JOIN dbo.OrderDetailsItems AS it ON it.OrderDetailId = od.OrderDetailId
LEFT JOIN [PRIORITY_LS].[amaba].[dbo].[ORDERITEMS]  AS oi
       ON oi.[<key>] = od.OrderDetailSourceId                 -- <<< CONFIRM key
LEFT JOIN [PRIORITY_LS].[amaba].[dbo].[MBA_DOCUMENTS] AS p
       ON p.[<order_key>] = oi.[<order_key>]                  -- <<< CONFIRM key
WHERE it.OrderDetailId IS NULL;                               -- קבוצות ללא פריט בלבד
*/
/* חלופת OPENQUERY (כשה-JOIN המפוזר איטי מדי):
   INSERT ל-#tmp את קבוצות-ללא-פריט המקומיות, ואז
   SELECT ... FROM OPENQUERY([PRIORITY_LS], 'SELECT <key>, DOC_N FROM amaba.dbo...') q
   JOIN #tmp ON ... — עדיין קריאה בלבד. */
GO


/* ==========================================================================
   Q2 — קריסת יוני 2026 (128 קבוצות מול ~1,500 טיפוסי)
   ==========================================================================
   נפח קבוצות מכשירים לפי חודש עסקי (WorkPlanOpenDate של ההזמנה-אב).
   מחפשים את הצניחה ביוני 2026 מול החודשים שסביבו. הצגה של 24 חודשים אחרונים. */
SELECT
    'Q2. MONTHLY VOLUME'                                       AS section,
    DATEFROMPARTS(YEAR(wp.WorkPlanOpenDate), MONTH(wp.WorkPlanOpenDate), 1) AS month_start,
    COUNT(DISTINCT od.OrderDetailId)                           AS device_groups,
    COUNT(DISTINCT wp.OrderWorkPlanId)                         AS work_plans,
    SUM(CASE WHEN i.OrderDetailId IS NULL THEN 1 ELSE 0 END)   AS groups_without_item
FROM dbo.OrderWorkPlans AS wp
JOIN dbo.OrderDetails    AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
OUTER APPLY (
    SELECT TOP (1) 1 AS OrderDetailId
    FROM dbo.OrderDetailsItems AS x
    WHERE x.OrderDetailId = od.OrderDetailId
) AS i
WHERE wp.WorkPlanOpenDate >= DATEADD(MONTH, -24, GETDATE())
GROUP BY DATEFROMPARTS(YEAR(wp.WorkPlanOpenDate), MONTH(wp.WorkPlanOpenDate), 1)
ORDER BY month_start;
GO
/* פרשנות: אם יוני 2026 מציג ~128 מול ~1,500 בחודשים שכנים — אושרה הקריסה.
   הצעד הבא (מחוץ לקובץ זה): להצליב מול היקף ההזמנות ב-Priority לאותו חודש כדי
   להבחין בין "פחות עבודה בפועל" לבין "הצינור הפסיק להזרים". */


/* ==========================================================================
   Q3 — התפלגות גיל של קבוצות-ללא-פריט
   ==========================================================================
   מקבץ את הקבוצות-ללא-פריט לפי גיל (מול WorkPlanOpenDate). הדליים נגזרים מחלון
   16.7 הימים של ה-CTE orderdata ב-vwGetOrders_WorkPlan_Full_new (SYNC §0א):
   קבוצה שכבר יצאה מ-16.7 הימים לא תוכל לקבל פריט לעולם בצינור הנוכחי. */
SELECT
    'Q3. AGE OF GROUPS WITHOUT ITEM'                           AS section,
    age_bucket,
    COUNT(*)                                                   AS groups_without_item
FROM (
    SELECT
        CASE
            WHEN DATEDIFF(DAY, wp.WorkPlanOpenDate, GETDATE()) <= 17  THEN '0. <=16.7d (עדיין בחלון)'
            WHEN DATEDIFF(DAY, wp.WorkPlanOpenDate, GETDATE()) <= 30  THEN '1. 17-30d'
            WHEN DATEDIFF(DAY, wp.WorkPlanOpenDate, GETDATE()) <= 90  THEN '2. 31-90d'
            WHEN DATEDIFF(DAY, wp.WorkPlanOpenDate, GETDATE()) <= 180 THEN '3. 91-180d'
            WHEN DATEDIFF(DAY, wp.WorkPlanOpenDate, GETDATE()) <= 365 THEN '4. 181-365d'
            ELSE                                                          '5. >365d'
        END AS age_bucket
    FROM dbo.OrderDetails AS od
    JOIN dbo.OrderWorkPlans AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsItems AS i
                       WHERE i.OrderDetailId = od.OrderDetailId)
) AS t
GROUP BY age_bucket
ORDER BY age_bucket;
GO
/* פרשנות: ריכוז גבוה בדלי 0 = קבוצות טריות שעדיין עשויות לקבל פריט (רעש, לא אובדן).
   ריכוז בדליים 2-5 = אובדן ודאי — הקבוצה מעבר לחלון ולא תקבל פריט בצינור הקיים. */


/* ==========================================================================
   Q4 — שימוש ב-linked server
   ==========================================================================
   מגלה אילו linked servers מוגדרים, ומי מפנה אליהם מתוך קוד ה-DB. נחוץ ל-Q1b
   (שם השרת ל-Priority) ולמיפוי נתיב הכתיבה הישיר לענן (MIGRATION §1.1 #5). */

/* --- Q4a: השרתים המקושרים המוגדרים ------------------------------------- */
SELECT
    'Q4a. LINKED SERVERS'                                      AS section,
    s.name                                                     AS linked_server,
    s.product, s.provider, s.data_source, s.is_linked,
    s.modify_date
FROM sys.servers AS s
WHERE s.server_id <> 0                                         -- לא השרת המקומי
ORDER BY s.name;
GO

/* --- Q4b: התחברויות ה-linked server (למי ממופה איזה login) -------------- */
SELECT
    'Q4b. LINKED LOGINS'                                       AS section,
    s.name                                                     AS linked_server,
    ll.uses_self_credential,
    ll.remote_name
FROM sys.linked_logins AS ll
JOIN sys.servers       AS s ON s.server_id = ll.server_id
WHERE s.server_id <> 0
ORDER BY s.name;
GO

/* --- Q4c: אילו אובייקטים בקוד מפנים ל-linked server / OPENQUERY / four-part
   סורק את גוף כל הפרוצדורות/פונקציות/views אחר הפניה לשם שרת מקושר. הריצו את
   Q4a קודם, ואם יש שם שרת ספציפי — החליפו אותו במחרוזת החיפוש למטה. */
SELECT
    'Q4c. CODE REFERENCING REMOTE'                             AS section,
    SCHEMA_NAME(o.schema_id) + '.' + o.name                    AS object_name,
    o.type_desc,
    CASE
        WHEN m.definition LIKE '%OPENQUERY%'    THEN 'OPENQUERY'
        WHEN m.definition LIKE '%OPENROWSET%'   THEN 'OPENROWSET'
        ELSE 'FOUR-PART / OTHER'
    END                                                        AS access_kind
FROM sys.sql_modules AS m
JOIN sys.objects     AS o ON o.object_id = m.object_id
WHERE m.definition LIKE '%OPENQUERY%'
   OR m.definition LIKE '%OPENROWSET%'
   OR m.definition LIKE '%[a-zA-Z0-9_]%.%.%.%[a-zA-Z0-9_]%'    -- חשד ל-four-part naming
ORDER BY object_name;
GO
/* פרשנות: מנתיב הכתיבה הישיר לענן (linked server מ-Priority) — אם Q4c על צד
   ה-Calibrator ריק, הכתיבה החוצה-שרתית יוזמת מ-Priority, ויש למפות אותה שם
   (MIGRATION 0.3). Q4c כאן מכסה את מה שנגיש מצד ה-Calibrator. */
