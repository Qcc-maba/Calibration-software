# DBA — סביבת בדיקות לוקלית (Docker · SQL Server 2022)

מקבילה לוקלית ובטוחה ל-"CalibratorTest" מ-[MIGRATION-AND-FIX-PLAN.md](../MIGRATION-AND-FIX-PLAN.md) §3.1.
מריצה SQL Server 2022 בקונטיינר, **מנותקת מהייצור** (אין ג'ובים, אין מייל, אין linked server לייצור,
אין סיכון לכתיבה חזרה ל-`amaba`).

## דרישות
- Docker Desktop (Linux containers) — קיים אצלך (v29.4.1).
- **גיבוי** `CalibratorProd*.bak` (אופציונלי אך מומלץ) — בלעדיו נוצר shell ריק בלבד.

## הרצה
```powershell
# מהתיקייה DBA/docker
# (אופציונלי) שים גיבוי כדי לשחזר אוטומטית:
#   copy \path\CalibratorProd.bak .\backup\
docker compose --env-file ..\.env up -d      # סיסמת SA מ-DBA/.env (MSSQL_SA_PASSWORD)
docker compose logs -f init                   # לעקוב אחרי האתחול (restore/bootstrap/safety)
```
- אם אין `.env`: משתמש בסיסמת ברירת מחדל **לפיתוח בלבד** (`Dev_Calib_2026!`).
- חיבור: `localhost,14330` · DB `CalibratorTest` · login `calib_test` (לא sa, לא db_owner).

```powershell
docker compose down       # עצירה (שומר נתונים)
docker compose down -v    # עצירה + מחיקת ה-DB
```

## מה קורה באתחול (`init/entrypoint.sh`)
1. ממתין ש-SQL Server מוכן.
2. אם יש `backup/*.bak` → **RESTORE** כ-`CalibratorTest` (עם MOVE דינמי לפי שמות הקבצים בגיבוי).
   אחרת → **shell ריק** (DB + סכימות `dbo`/`stg`/`etl`).
3. **פעולות בטיחות** (`10_safety.sql`): יוצר login מוגבל `calib_test`, מערבל אימיילים ב-`dbo.Users`
   (אם שוחזרו נתונים אמיתיים), ומנתק כל linked server.
4. מחיל את תשתית הלוגים `DBA/sql/03_etl_logging_framework.sql`.

## אחרי ההרצה — הצעדים מהתוכנית
- `sql/01_fix_MergeOrdersData.sql` ו-`sql/02_usp_SyncHealthCheck.sql` דורשים את טבלאות הבסיס
  (כלומר restore מגיבוי). הרץ אותם מול `CalibratorTest` ואמת מול §2 בתוכנית.
- **מדד ההכרעה (§2.3):** להשוות ספירת שורות של ה-view עם חלון 90 יום מול הקיים.

> `backup/*.bak` ו-volume הנתונים אינם נכנסים ל-git.
