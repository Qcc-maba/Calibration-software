# תקן ותוכנית עבודה לכתיבת Stored Procedures

> **נכתב:** 2026-07-30 · **קהל:** צוות הפיתוח של `CalibratorProd`
> **מסמך אב:** [SYNC-IMPROVEMENT-PLAN.md](SYNC-IMPROVEMENT-PLAN.md) · **ניתוח:** [CALIBRATOR-SYNC-PLAN.md](CALIBRATOR-SYNC-PLAN.md)

המסמך הזה הוא שני דברים: **תקן** שכל SP חדשה או משוכתבת חייבת לעמוד בו,
ו-**backlog** מסודר של הפרוצדורות שצריך לכתוב, בסדר עבודה מומלץ.

---

## 1. למה צריך תקן

ביקורת סטטית על כל 16 פרוצדורות המיזוג ב-`stg` וב-`etl` נתנה:

| בדיקה | תוצאה |
|---|---|
| `BEGIN TRY` / `CATCH` | **0 / 16** |
| טרנזקציה מפורשת | **0 / 16** |
| טיפול במחיקות (`WHEN NOT MATCHED BY SOURCE`) | **1 / 16** |
| ספירת שורות שנפלו בסינון | **0 / 16** |
| כתיבה לכל לוג שהוא | **0 / 16** |

אלה לא באגים של מפתח מסוים — זהו **היעדר תקן**. הראיה: `MergeCustomersData` נכתבה
באיכות גבוהה (כל 20 תנאי ההשוואה נכונים), ובכל זאת חסרים בה בדיוק אותם חמישה רכיבים.
כשאין תקן, אפילו קוד טוב יוצא לא-שלם.

**המחיר בפועל:** 593 שורות הזמנה נעלמות מדי ריצה בלי זכר, ו-235,000 עדכוני סרק ביום
נבעו משני תווים שגויים שאף אחד לא תפס — כי אין ספירה, אין לוג ואין השוואה בין ריצות.

> ### ⚠ אזהרה לפני שמתחילים: התקן הזה לא פותר את הבאג הגדול
>
> אובדן ~5,200 הכיולים **אינו** נובע מהפרוצדורות אלא מ-`WHERE o.CURDATE > (now - 24000)`
> בתוך ה-view `amaba.dbo.vwGetOrders_WorkPlan_Full_new` — חלון של 16.7 ימים על ה-CTE המוביל.
> שורה שמקבלת `Doc` אחרי שהחלון נסגר לא תגיע לצינור בכלל, ולכן **שום פרוצדורה לא תוכל
> להציל אותה.** הפירוט המלא ב-`SYNC-IMPROVEMENT-PLAN.md` §0א.
>
> המשמעות לצוות: התקן כאן מונע את הבאג **הבא** ונותן נראוּת לבאג הקיים,
> אבל התיקון עצמו הוא שינוי ב-view + backfill (N7, N8).

---

## 2. התקן — 12 כללים

| # | כלל | למה זה כאן |
|---|---|---|
| 1 | `SET NOCOUNT ON;` + `SET XACT_ABORT ON;` בראש כל SP | `XACT_ABORT` מבטיח שכשל בפקודה משאיר את הטרנזקציה במצב ניתן ל-rollback |
| 2 | בלוק כותרת: מחבר, תאריך, תיאור, קישור Jira | הקונבנציה קיימת בקוד — לשמר אותה |
| 3 | `BEGIN TRY` / `BEGIN CATCH` סביב כל ה-DML | 0/16 היום |
| 4 | טרנזקציה מפורשת סביב כל קבוצת פקודות שחייבת להיות אטומית | `MergeOrdersData` מריצה 3 MERGE ברצף; כשל בשני משאיר את הראשון מבוצע |
| 5 | ב-`CATCH`: `ROLLBACK` אם `XACT_STATE() <> 0`, רישום, ואז **`THROW`** | בלי `THROW` הג'וב ב-SQL Agent מדווח הצלחה על כשל. זה שורש כל ה"כשל השקט" |
| 6 | רישום ריצה: `etl.usp_SyncRunStart` בתחילה, `etl.usp_SyncRunEnd` בסוף — בשני הנתיבים | ריצה שלא נרשמה = ריצה שלא ניתן לאבחן |
| 7 | **אין נפילה שקטה.** כל שורה שמסוננת נכתבת ל-`etl.SyncReject` עם סיבה | 593 שורות ביום נעלמות בלי רישום |
| 8 | זיהוי שינויים ב-`EXCEPT`, לא בשרשרת `OR` של השוואות | מונע את **מחלקת הבאג** של `=` מול `<>`, וגם NULL-safe בלי `COALESCE` |
| 9 | `WHEN NOT MATCHED BY SOURCE` → `IsDeleted = 1` (מחיקה רכה) | 1/16 היום; מחיקות מ-Priority לא מגיעות לעולם |
| 10 | אין כללים עסקיים או טקסט עברי מקודדים בקוד — טבלת `ref.*` | 29 קטגוריות ומספר הקסם `100` יושבים היום בתוך `MergeOrdersData` |
| 11 | אין שליפה לפי מחרוזת תיאור — רק לפי `Code` / מזהה | `'WaitingForCalibration'` בשורה 69: שינוי תיאור משתיק את הסנכרון בלי שגיאה |
| 12 | אידמפוטנטיות: הרצה שנייה ללא שינוי במקור = **0 עדכונים** | זו בדיקת הקבלה הקלה ביותר, והיא הייתה חושפת את באג האופרטור מיד |

### שלושה כללים ששווה להרחיב

**כלל 8 — למה `EXCEPT` ולא שרשרת השוואות.** הקוד הקיים:

```sql
WHEN MATCHED AND (
        COALESCE(dest.[Name],'')            <> COALESCE(source.[Name],'')
    OR  COALESCE(dest.[MainCategoryId],0)    = COALESCE(source.[MainCategoryId],0)   -- ⬅ באג
    OR  COALESCE(dest.[SecondaryCategoryId],0) = COALESCE(source.[SecondaryCategoryId],0)
    OR  ... עוד 9 תנאים ...
)
```

שני תווים שגויים בשרשרת של 12 תנאים הפכו את התנאי לאמת כמעט תמיד. התבנית החלופית:

```sql
WHEN MATCHED AND EXISTS (
        SELECT src.Name, src.MainCategoryId, src.SecondaryCategoryId, src.DeviceModel
        EXCEPT
        SELECT dest.Name, dest.MainCategoryId, dest.SecondaryCategoryId, dest.DeviceModel
)
```

שלושה יתרונות: אין אופרטור שאפשר להפוך, `EXCEPT` מתייחס ל-`NULL = NULL` כזהים
(ולכן אין צורך ב-`COALESCE`), והוספת עמודה = שורה אחת בשתי הרשימות. אי-אפשר לכתוב
את הבאג הזה בתבנית הזאת.

**כלל 7 — דחיות אינן שגיאות.** שורה שנדחית היא מידע עסקי, לא כשל. הפרוצדורה ממשיכה,
אבל השורה נרשמת עם סיבה. זה מה שהופך "60.5% נעלמות" ל-"60.5% נדחו כי `Doc IS NULL`, הנה הן".

**כלל 12 — האידמפוטנטיות היא הבדיקה.** אם אחרי שתי ריצות רצופות בלי שינוי במקור
מתקבלים עדכונים, יש באג בזיהוי השינויים. בדיקה אחת, שתי שורות SQL, תופסת מחלקת באגים שלמה.

---

## 3. רכיב חדש שהתקן דורש — `etl.SyncReject`

`etl.SyncRunLog` (מוכן ב-[03](sql/03_etl_logging_framework.sql)) סופר *כמה* נדחו.
הטבלה הזו אומרת *אילו* ו-*למה*. בלעדיה כלל 7 לא ניתן למימוש.

```sql
IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
               WHERE s.name = 'etl' AND t.name = 'SyncReject')
BEGIN
    CREATE TABLE etl.SyncReject
    (
        RejectId     BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_etl_SyncReject PRIMARY KEY CLUSTERED,
        RunId        BIGINT         NOT NULL
            CONSTRAINT FK_etl_SyncReject_Run REFERENCES etl.SyncRunLog (RunId),
        SourceTable  NVARCHAR(128)  NOT NULL,
        SourceKey    NVARCHAR(200)  NULL,    -- המזהה בנחיתה, לצורך מעקב חזרה למקור
        Reason       VARCHAR(50)    NOT NULL, -- קוד קצר: DOC_NULL / NO_PARENT / EMAIL_NO_MATCH
        Detail       NVARCHAR(500)  NULL,
        Payload      NVARCHAR(MAX)  NULL,    -- השורה כ-JSON, לשחזור ידני
        RejectedAt   DATETIME2(3)   NOT NULL
            CONSTRAINT DF_etl_SyncReject_At DEFAULT SYSDATETIME()
    );

    CREATE INDEX IX_etl_SyncReject_Run    ON etl.SyncReject (RunId);
    CREATE INDEX IX_etl_SyncReject_Reason ON etl.SyncReject (Reason, RejectedAt DESC);
END
GO
```

> **שים לב ל-`Payload`:** `NVARCHAR(MAX)` על טבלה שיכולה לקבל ~600 שורות בשעה יגדל מהר.
> יש להוסיף ג'וב תחזוקה שמוחק דחיות מעל 90 יום, או לשמור `Payload` רק ל-`Reason` שלא נחקר עדיין.

---

## 4. התבנית הקנונית

זו התבנית שכל פרוצדורת מיזוג צריכה להיראות כמוה. החלף `Xxx` בשם הישות.
חתימות `usp_SyncRunStart` / `usp_SyncRunEnd` תואמות ל-[03](sql/03_etl_logging_framework.sql) כפי שנכתבו.

```sql
-- =============================================
-- Author:      <שם>
-- Create date: <תאריך>
-- Description: Merge Xxx from amaba staging into dbo
-- JiraLink:    <קישור>
-- =============================================
CREATE OR ALTER PROCEDURE stg.MergeXxxData
    @DebugMode BIT = 0          -- 1 = להחזיר את הספירות במקום להסתפק בלוג
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @proc  SYSNAME = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @RunId BIGINT,
            @src   INT,
            @ins   INT = 0,
            @upd   INT = 0,
            @del   INT = 0,
            @rej   INT = 0;

    DECLARE @acts TABLE (act NVARCHAR(10) NOT NULL, is_del BIT NOT NULL);

    SELECT @src = COUNT(*) FROM stg.stg_Xxx;

    EXEC etl.usp_SyncRunStart
         @ProcedureName = @proc,
         @TargetTable   = 'dbo.Xxx',
         @SourceRows    = @src,
         @RunId         = @RunId OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---- 1. דחיות: נרשמות לפני הסינון, לא נעלמות (כלל 7) ---- */
        INSERT etl.SyncReject (RunId, SourceTable, SourceKey, Reason, Payload)
        SELECT @RunId,
               'stg.stg_Xxx',
               CONVERT(NVARCHAR(200), s.SourceId),
               CASE WHEN s.Doc IS NULL THEN 'DOC_NULL' ELSE 'NO_PARENT' END,
               (SELECT s.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
          FROM stg.stg_Xxx AS s
         WHERE s.Doc IS NULL
            OR NOT EXISTS (SELECT 1 FROM dbo.Parent AS p
                            WHERE p.KeyFromSource = s.ParentKey);
        SET @rej = @@ROWCOUNT;

        /* ---- 2. המיזוג ---- */
        MERGE dbo.Xxx WITH (HOLDLOCK) AS dest
        USING (
                SELECT s.SourceId, s.Name, s.CategoryId, s.DeviceModel, s.ParentKey
                  FROM stg.stg_Xxx AS s
                 WHERE s.Doc IS NOT NULL
                   AND EXISTS (SELECT 1 FROM dbo.Parent AS p
                                WHERE p.KeyFromSource = s.ParentKey)
              ) AS src
           ON dest.KeyFromSource = src.SourceId

        /* זיהוי שינויים ב-EXCEPT — NULL-safe, בלי אופרטור שאפשר להפוך (כלל 8) */
        WHEN MATCHED AND EXISTS (
                 SELECT src.Name, src.CategoryId, src.DeviceModel
                 EXCEPT
                 SELECT dest.Name, dest.CategoryId, dest.DeviceModel )
            THEN UPDATE SET
                 dest.Name        = src.Name,
                 dest.CategoryId  = src.CategoryId,
                 dest.DeviceModel = src.DeviceModel,
                 dest.IsDeleted   = 0,          -- שורה שחזרה למקור מתחייה
                 dest.UpdatedDate = SYSDATETIME()

        WHEN NOT MATCHED BY TARGET
            THEN INSERT (KeyFromSource, Name, CategoryId, DeviceModel, IsDeleted, CreateDate)
                 VALUES (src.SourceId, src.Name, src.CategoryId, src.DeviceModel, 0, SYSDATETIME())

        /* מחיקה רכה (כלל 9) */
        WHEN NOT MATCHED BY SOURCE AND dest.IsDeleted = 0
            THEN UPDATE SET
                 dest.IsDeleted   = 1,
                 dest.UpdatedDate = SYSDATETIME()

        /* src.SourceId הוא NULL בדיוק בענף NOT MATCHED BY SOURCE — כך מפרידים מחיקה מעדכון */
        OUTPUT $action,
               CASE WHEN src.SourceId IS NULL THEN 1 ELSE 0 END
          INTO @acts (act, is_del);

        SELECT @ins = SUM(CASE WHEN act = 'INSERT'                THEN 1 ELSE 0 END),
               @upd = SUM(CASE WHEN act = 'UPDATE' AND is_del = 0 THEN 1 ELSE 0 END),
               @del = SUM(CASE WHEN act = 'UPDATE' AND is_del = 1 THEN 1 ELSE 0 END)
          FROM @acts;

        COMMIT TRANSACTION;

        EXEC etl.usp_SyncRunEnd
             @RunId = @RunId, @Status = 'SUCCESS',
             @RowsInserted = @ins, @RowsUpdated = @upd,
             @RowsDeleted  = @del, @RowsRejected = @rej;

        IF @DebugMode = 1
            SELECT @RunId AS RunId, @src AS SourceRows, @ins AS Inserted,
                   @upd AS Updated, @del AS SoftDeleted, @rej AS Rejected;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        DECLARE @errNum INT            = ERROR_NUMBER(),
                @errMsg NVARCHAR(2048) = ERROR_MESSAGE();

        EXEC etl.usp_SyncRunEnd
             @RunId = @RunId, @Status = 'FAILED',
             @ErrorNumber = @errNum, @ErrorMessage = @errMsg;

        THROW;   -- חובה (כלל 5): בלי זה הג'וב מדווח הצלחה על כשל
    END CATCH
END
GO
```

### שלוש הערות מימוש

- **`WITH (HOLDLOCK)`** על יעד ה-`MERGE` — מונע race condition בין בדיקת ההתאמה להוספה.
  זו המלצה סטנדרטית ל-`MERGE` ב-SQL Server והיא חסרה בכל 16 הפרוצדורות.
- **`WHEN NOT MATCHED BY SOURCE` פועל על כל טבלת היעד.** אם המיזוג הוא חלקי
  (למשל לקוחות של מקור אחד בלבד), חייבים לצמצם את היעד — אחרת הענף הזה
  ימחק רכות שורות של מקורות אחרים. הדרך: `MERGE (SELECT * FROM dbo.Xxx WHERE SourceId = @SourceId) AS dest`.
  **זו הטעות המסוכנת ביותר בכל התקן** — `dbo.Customers` מכילה נתונים מ-3 מקורות.
- **`dest.IsDeleted = 0` בענף העדכון** מחזיר לחיים שורה שנמחקה רכות וחזרה למקור.
  בלי זה, שורה שנמחקה בטעות ב-Priority ושוחזרה תישאר מסומנת מחוקה לנצח.

---

## 5. Backlog — מה כותבים, ובאיזה סדר

### 5.1 פרוצדורות חדשות

| # | פרוצדורה | תפקיד | מאמץ | תלוי ב… |
|---|---|---|---|---|
| N1 | `etl.SyncReject` (טבלה) | יעד הדחיות | S | — |
| N2 | `etl.usp_SyncAlert` | מייל כאשר יש `FAILED`, ריצה תקועה, או `RejectedPct` חריג | S | N1, 03 |
| N3 | `dbo.usp_BackfillUsersCustomerId` | לקשר 2,090 משתמשי פורטל ללקוח. חד-פעמי אך **אידמפוטנטי** | M | — |
| N4 | `dbo.usp_LinkCustomerSupportContact` | התאמת אימייל מנורמלת ל-11,296 הלקוחות + רישום כשלים | M | N1 |
| N5 | `ref.CategoryMapping` + `ref.usp_MapCategory` | להוציא את 29 הקטגוריות מ-`MergeOrdersData` | M | — |
| N6 | `dbo.usp_GetWorkPlanHeader` / `…Details` / `…Items` | פיצול `GetWorkPlanData` (20,990 תווים) לפי רמת היררכיה | M | — |
| **N7** | `dbo.usp_CountMissingCalibrations` | לספור במדויק כמה כיולים קיימים ב-Priority וחסרים ב-Calibrator. מחליף את ההַשְׁלָכָה מ-400 | S | linked server / SSIS |
| **N8** | `dbo.usp_BackfillCalibrationItems` | להזרים את ~5,200 הפריטים החסרים. `@DryRun BIT = 1`, עבודה ב-batches, אידמפוטנטית | L | N7 + תיקון ה-view |
| — | `dbo.usp_SyncHealthCheck` | ✅ **הותקן ורץ** 2026-07-30 | — | — |

> **N3/N4 הן פרוצדורות תיקון נתונים על ייצור.** חייבות: `@DryRun BIT = 1` כברירת מחדל
> שמחזירה את מה שהיה משתנה בלי לשנות, ו-`SELECT` של השורות המושפעות לאישור לפני הרצה אמיתית.

### 5.2 שכתוב הפרוצדורות הקיימות — בגלים

הסדר נקבע לפי סיכון עולה. **גל לא מתחיל לפני שהגל שלפניו רץ שבוע בייצור.**

| גל | פרוצדורות | למה בסדר הזה | סיכון |
|---|---|---|---|
| **0 — פיילוט** | `stg.MergeCustomerRemarks` (54 שורות) | הקטנה מכולן. התבנית כבר כתובה עבורה ב-[03](sql/03_etl_logging_framework.sql) חלק ג | 🟡 |
| **1 — נחיתה ריקה** | `MergeMeasurementsData`, `MergeMeasurementsToMeasurmentUnitsData`, `MergeMeasurementDevicesCorrection`, `MergeMabaComments` | טבלאות הנחיתה שלהן ריקות (0 שורות) — שינוי כמעט ללא השפעה, אבל מוכיח את התקן | 🟢 |
| **2 — לקוחות** | `MergeCustomersData`, `MergeCustomersContactsData`, `MergeCustomerRemarks` | הקוד כאן איכותי; מוסיפים רישום, דחיות ומחיקות בלי לתקן באגי לוגיקה | 🟡 |
| **3 — הזמנות** | `MergeOrdersData` (386 שורות), `MergeClientAccessoryOrderDetailsItems` | הלב של הסנכרון, ובה כל הבאגים. **אחרונה בכוונה** | 🔴 |
| **4 — etl** | 5 × `etl.Merge*ToOnPrem` | רק אחרי ההחלטה אם סכימת `etl` נשארת (ריקה לחלוטין היום) | 🟡 |
| **ניקוי** | `stg.MergeCarsToOnPrem` | 76 שורות **בלי DML כלל** — חשודה כקוד מת. לאמת ולמחוק | 🟢 |

> **פער בספירה שצריך לסגור:** מסמך המיפוי מונה 11 פרוצדורות `stg.Merge*`, אבל בטבלת
> `stg → dbo` מופיעות 10 בשמן. יש לאתר את הפרוצדורה החסרה לפני תחילת גל 1 — אחרת היא
> תישאר הפרוצדורה היחידה בלי תקן.

### 5.3 עבודה נלווית ל-`MergeOrdersData` (גל 3)

הפרוצדורה הזאת דורשת רשימה משלה, כי שכתוב שלה נוגע בשמונה דברים במקביל:

| # | פעולה | הערה |
|---|---|---|
| 1 | `=` → `<>` בשורות 171–172 | [01](sql/01_fix_MergeOrdersData.sql) כבר כתוב |
| 2 | להמיר את כל 12 התנאים לתבנית `EXCEPT` | מייתר את 1 |
| 3 | לבטל את ההערה על בלוק העדכון של `OrderDetailsItems` (286–329) | 🔴 |
| 4 | **יחד עם 3** — לתקן 7 אופרטורים הפוכים בתוך הבלוק (288–303) | אחרת הבאג חוזר גדול יותר |
| 5 | להוסיף `WHEN MATCHED` ל-`OrderWorkPlans` | כיום אין בכלל |
| 6 | `Doc IS NOT NULL` → כתיבה ל-`SyncReject` | 593 שורות ביום |
| 7 | להוציא את בלוק 29 הקטגוריות ל-`ref.CategoryMapping` | N5 |
| 8 | להסיר `REVERSE(o.[Devicemodel])` | דורש תיקון תצוגה + migration לנתונים הקיימים |
| 9 | להחליף `'WaitingForCalibration'` בשליפה לפי `Code` | כלל 11 |
| 10 | להוציא את כלל 100 הימים לקונפיגורציה | כלל 10 |

**אין לעשות את כל עשרת אלה בפריסה אחת.** מומלץ שלושה PR נפרדים:
תחילה 1+2+6 (זיהוי שינויים ודחיות), אחר כך 7+9+10 (הוצאת כללים), ולבסוף 3+4+5 (מודל העדכון).
פריט 8 הוא משימה נפרדת לגמרי כי הוא נוגע בממשק.

---

## 6. Definition of Done

PR שמוסיף או משנה SP לא מאושר לפני שכל הסעיפים מסומנים.

- [ ] `SET NOCOUNT ON` + `SET XACT_ABORT ON`
- [ ] בלוק כותרת עם מחבר, תאריך, תיאור וקישור Jira
- [ ] `TRY` / `CATCH` עוטף את כל ה-DML
- [ ] טרנזקציה מפורשת; `ROLLBACK` מותנה ב-`XACT_STATE() <> 0`
- [ ] `THROW` בסוף ה-`CATCH` — **לא** רק רישום
- [ ] `usp_SyncRunStart` / `usp_SyncRunEnd` בשני נתיבי היציאה
- [ ] כל סינון כותב ל-`etl.SyncReject` עם `Reason` קצר ועקבי
- [ ] זיהוי שינויים ב-`EXCEPT` — **אין** שרשרת `OR` של השוואות
- [ ] `WHEN NOT MATCHED BY SOURCE` קיים, ומצומצם למקור הנכון אם היעד משותף
- [ ] אין טקסט עברי, מספר קסם או כלל עסקי בקוד
- [ ] אין שליפה לפי מחרוזת תיאור — רק לפי `Code`
- [ ] `WITH (HOLDLOCK)` על יעד ה-`MERGE`
- [ ] **בדיקת אידמפוטנטיות עברה:** ריצה שנייה = 0 עדכונים (פלט מצורף ל-PR)
- [ ] `OBJECT_DEFINITION` של הגרסה הקודמת מצורף ל-PR כתסריט חזרה לאחור

---

## 7. איך בודקים שינוי ב-SP בבטחה

**חסם פתוח:** אין כרגע גישה ל-`Calibrator` (סביבת stage) — `app_stage` נדחה ו-`app_prod` חסר הרשאה.
עד שנוצר login, **כל בדיקה נעשית על ייצור**, ולכן הפרוטוקול הזה אינו אופציונלי.
פתיחת ה-stage היא הפעולה בעלת התשואה הגבוהה ביותר בכל התוכנית.

```sql
-- 1. גיבוי ההגדרה הקיימת. לשמור בקובץ, לא רק בזיכרון.
SELECT OBJECT_DEFINITION(OBJECT_ID('stg.MergeXxxData'));

-- 2. תצלום מצב לפני
SELECT COUNT(*) AS rows_before,
       SUM(CASE WHEN UpdatedDate >= DATEADD(HOUR,-2,SYSDATETIME()) THEN 1 ELSE 0 END) AS updated_2h
  FROM dbo.Xxx;

-- 3. פריסה, ואז הרצה ראשונה
EXEC stg.MergeXxxData @DebugMode = 1;

-- 4. הרצה שנייה מיד — בדיקת האידמפוטנטיות. Updated חייב להיות 0.
EXEC stg.MergeXxxData @DebugMode = 1;

-- 5. מה הלוג אומר
EXEC etl.usp_SyncRunReport @Hours = 1;
SELECT Reason, COUNT(*) AS cnt FROM etl.SyncReject
 WHERE RunId IN (SELECT RunId FROM etl.SyncRunLog
                  WHERE ProcedureName = 'stg.MergeXxxData'
                    AND StartedAt >= DATEADD(HOUR,-1,SYSDATETIME()))
 GROUP BY Reason ORDER BY cnt DESC;

-- 6. בדיקת בריאות כללית — שלא נשבר משהו אחר
EXEC dbo.usp_SyncHealthCheck;
```

**קריטריוני עצירה — אם אחד מהם מתקיים, לחזור לאחור מיד:**

| סימן | מה זה אומר |
|---|---|
| הרצה שנייה מחזירה `Updated > 0` | זיהוי השינויים שבור — הבאג המקורי חזר בצורה אחרת |
| `RowsRejected` גדל משמעותית מול הבסיס | הסינון החדש מחמיר מהכוונה |
| `RowsDeleted > 0` בפרוצדורה שלא אמורה למחוק | `NOT MATCHED BY SOURCE` לא צומצם למקור הנכון — **הסיכון החמור** |
| `usp_SyncHealthCheck` מראה סחף חדש בטבלה אחרת | תופעת לוואי לא מכוונת |

**החזרה לאחור:** להריץ את ההגדרה שנשמרה בשלב 1, אחרי החלפת `CREATE PROCEDURE` ב-`ALTER PROCEDURE`.
מחיקה רכה שבוצעה בטעות בטלה ב-`UPDATE dbo.Xxx SET IsDeleted = 0 WHERE UpdatedDate >= '<זמן הפריסה>' AND IsDeleted = 1` —
ולכן חשוב לרשום את זמן הפריסה המדויק.
