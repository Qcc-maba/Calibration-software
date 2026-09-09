# DBA — סנכרון Priority ↔ Calibrator (SQL Server)

ערכת העבודה של ה-DBA: מיפוי צינור הסנכרון בין Priority ERP (on-prem, SQL 2019) למערכת
Calibrator (AWS, SQL 2022), ממצאים שנמדדו מול הייצור, תוכניות תיקון, וסקריפטי SQL.

> ⚠️ **`.env` (סודות DB) לא נמצא כאן ולא נכנס ל-git** — מוחרג ב-`.gitignore`. שמור אותו מקומית בלבד.

## מסמכים
| קובץ | תוכן |
|------|------|
| [MIGRATION-AND-FIX-PLAN.md](MIGRATION-AND-FIX-PLAN.md) | **התוכנית המרכזית** — טופולוגיה מלאה, אסטרטגיית מיגרציה לסביבת בדיקות, ותוכנית תיקון שלב-אחר-שלב |
| [SYNC-IMPROVEMENT-PLAN.md](SYNC-IMPROVEMENT-PLAN.md) | מה לתקן (הממצאים) |
| [SP-DEVELOPMENT-PLAN.md](SP-DEVELOPMENT-PLAN.md) | תקן כתיבת פרוצדורות (איך לתקן) |
| [CALIBRATOR-SYNC-PLAN.md](CALIBRATOR-SYNC-PLAN.md) | תכנית סנכרון |
| [DB-MAPPING-AND-USAGE.md](DB-MAPPING-AND-USAGE.md) | מיפוי טבלאות ושימוש |
| [DB-SCHEMA-REFERENCE.md](DB-SCHEMA-REFERENCE.md) | ייחוס סכימה |
| `Calibrator-Sync-Map.pdf` · `MABA2000-DB-Map.pdf` | מפות סנכרון (PDF) |

## SQL (`sql/`)
| קובץ | תפקיד |
|------|-------|
| `01_fix_MergeOrdersData.sql` | תיקון פרוצדורת המיזוג (אופרטור + תבנית EXCEPT) |
| `02_usp_SyncHealthCheck.sql` | בדיקת תקינות הסנכרון (6 ממצאים) |
| `03_etl_logging_framework.sql` | תשתית נראוּת: `etl.SyncRunLog` + `etl.SyncReject` |

## הקשר
- הקוד המלא של הסנכרון (פרוצדורות, SSIS) חי במאגר `Qcc-maba/db_calibrator` ובמערכות הייצור.
- ה-API של Priority (OData) חי ב-`maba2000-web` — ראה `Systems/Priority/` בפרויקט זה.
