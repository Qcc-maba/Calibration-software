# DBA/sql — סקריפטי הסנכרון Priority ↔ Calibrator (SQL Server)

סקריפטי T-SQL עבור `CalibratorProd` (AWS, `MbaCustWeb\QCC`). כולם נכתבו לפי התקן
ב-[../SP-DEVELOPMENT-PLAN.md](../SP-DEVELOPMENT-PLAN.md) ומיישמים את
[../SYNC-IMPROVEMENT-PLAN.md](../SYNC-IMPROVEMENT-PLAN.md) ו-[../MIGRATION-AND-FIX-PLAN.md](../MIGRATION-AND-FIX-PLAN.md).

> ⚠️ נכתבו ללא גישה חיה למסד. כל מקום שבו שם טבלה/עמודה אינו ודאי מסומן בהערה
> `⚠` או `<<< CONFIRM` בקוד — יש לאמת מול הסכימה האמיתית לפני הרצה.

## הקבצים

| קובץ | מה עושה | DML? | תלות |
|------|---------|------|------|
| `00_step0_investigation.sql` | אבחון קריאה-בלבד לשלב 0: ספירת אובדן מדויקת (Q1), קריסת יוני 2026 (Q2), התפלגות גיל של קבוצות-ללא-פריט (Q3), שימוש ב-linked server (Q4) | ❌ קריאה בלבד | אין |
| `02_usp_SyncHealthCheck.sql` | `dbo.usp_SyncHealthCheck` — בדיקת בריאות ב-6 סעיפים (טריות, סחף נחיתה→יעד, נפילות שקטות, היררכיה, פערי קישור, verdict) | ❌ קריאה בלבד | אין |
| `03_etl_logging_framework.sql` | תשתית הנראוּת: יוצר `etl.SyncRunLog` + **`etl.SyncReject`**, ופרוצדורות `etl.usp_SyncRunStart` / `usp_SyncRunEnd` / `usp_SyncRunReport` | 🟢 DDL חדש בלבד | אין |
| `01_fix_MergeOrdersData.sql` | מקשיח את `stg.MergeOrdersData` לתבנית הקנונית: TRY/CATCH + טרנזקציה + רישום ריצה + דחיות ל-`SyncReject` + זיהוי שינויים ב-`EXCEPT` + `HOLDLOCK` + אידמפוטנטיות | 🟡 `ALTER PROCEDURE` | **`03`** (טבלאות ופרוצדורות ה-etl) |

## סדר הרצה

```
00  ── בכל עת, קריאה בלבד — לאיסוף בסיס המדידה של שלב 0 (לא תלוי בשאר)
02  ── ✅ כבר הותקן ורץ (2026-07-30); להריץ מחדש כדי לרענן את ההקשחה
03  ── ראשון מבין המשנים: יוצר SyncRunLog + SyncReject + פרוצדורות הרישום
        │
        └─ *שבוע תצפית* (SYNC-IMPROVEMENT-PLAN שער היציאה משלב א)
        │
01  ── אחרון: תלוי ב-03 (כותב ל-etl.SyncRunLog ו-etl.SyncReject)
```

**כללים:**
- **`03` חייב לרוץ לפני `01`** — אחרת `INSERT etl.SyncReject` ו-`EXEC etl.usp_SyncRun*` ב-01 ייכשלו.
- אין להתקין את `01` לפני שהרישום (`03`) עובד — אחרת אין דרך למדוד אם התיקון עזר.
- `00` ו-`02` הם קריאה בלבד ובטוחים להרצה על ייצור בכל רגע.

## אחרי הרצת 01 — בדיקת הקבלה

```sql
EXEC stg.MergeOrdersData @DebugMode = 1;   -- ריצה 1
EXEC stg.MergeOrdersData @DebugMode = 1;   -- ריצה 2 → Updated חייב להיות 0 (אידמפוטנטיות)
EXEC etl.usp_SyncRunReport @Hours = 1;     -- מה נרשם
EXEC dbo.usp_SyncHealthCheck;              -- לוודא שלא נשבר משהו אחר
```
קריטריון עצירה: אם ריצה 2 מחזירה `Updated > 0` — זיהוי השינויים שבור, לחזור לאחור
(ההגדרה הקודמת נשמרת בשלב 2 של `01`).

## הנחות פתוחות לאימות מול הסכימה

- **`01`** — `etl.SyncReject.SourceKey` מאוכלס מ-`stg_Orders.SourceOrderId`; המרת ה-`EXCEPT`
  מטפלת ב-NULL כשווה ל-NULL אך לא ל-0 (שינוי סמנטי קל מול `COALESCE(...,0)` המקורי — ריצה
  ראשונה עשויה לעדכן שורות גבול פעם אחת). בלוק העדכון של `OrderDetailsItems` נשאר מוער
  בכוונה (שלב ד.1+ד.2).
- **`00`** — Q1b (האובדן החוצה-שרתי) דורש שם linked server אמיתי (מתגלה ב-Q4) ואישור מפתחות
  ההצטרפות ל-Priority (`amaba.dbo.ORDERITEMS` / `MBA_DOCUMENTS`). Q1a הוא הבסיס המקומי הוודאי.
- **`02`** — `section 5` שולף לפי `UserRoleName = 'Customer'` (כלל 11); אם ל-`UserRoles` יש
  קוד/מזהה יציב עדיף לשלוף לפיו. סף הטריות בסעיף 1 אחיד (שיפור פתוח: שלב א.6).
