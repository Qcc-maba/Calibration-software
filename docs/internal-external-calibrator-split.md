# פיצול כייל פנים / כייל חוץ בין הלוקאלי לגלובלי — מצב קיים ופער

נכתב 08/09/2026. כל המספרים כאן נמדדו מול השרתים החיים באותו יום, לא הוערכו.

**הדרישה:** כייל פנים (Internal calibrator) עובד מול הלוקאלי (PRI, ברשת של פריוריטי);
כייל חוץ (External calibrator) מול הגלובלי (51.17.121.203, אמזון). המשבצת (coordinator)
כותבת ללוקאלי ומסנכרנת לגלובלי.

**המסקנה:** ההבחנה פנים/חוץ **קיימת ועובדת**, אבל כעמודה בבסיס נתונים אחד. הפיצול לשני
בסיסי נתונים **לא מומש בשום שכבה**, ואין לוקאלי שאפשר לכתוב אליו.

---

## 1. מה כן קיים

ההבחנה מיוצגת ב־`OrderDetails.IsInHouse`:

| ערך | משמעות | תצוגה בקוד |
|-----|--------|-------------|
| `1` | כיול במעבדת מ.ב.א. — כייל פנים | `IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')` |
| `0` | כיול באתר הלקוח — כייל חוץ | ראה `CalibrationLocation` |

הניתוב הוא לפי `@Page` ב־`dbo.GetDevicesGroupsByOrder` (זהה ב־STAGE וב־PROD, 10,258 תווים):

```sql
DECLARE @ExtIntFilter BIT = NULL
IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders') SET @ExtIntFilter = 0
IF @Page IN (N'internal-orders')                                            SET @ExtIntFilter = 1
...
,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter AS NVARCHAR(MAX)) ELSE ' ' END
```

מסלולים באפליקציה: `/internal-orders`, `/internal-validator` מול `/external-orders`,
`/external-schedule`, `/external-validator`, `/coordinator-orders`.
`/internal-orders` מייבא את `TCoordinatorOrder` ומשתמש באותו קומפוננט טבלה של המשבצת.

נפחים ב־PROD: **4,609 פנים · 6,407 חוץ · 914 NULL**. (STAGE: 2,078 / 3,035 / 366.)

## 2. מה לא קיים

| שכבה | מה נמדד |
|------|---------|
| האפליקציה | `datasource` יחיד ב־`prisma/schema.prisma` על `REMOTE_DATABASE_URL`; `PrismaClient` אחד ב־`src/server/db.ts`. אין לקוח mssql/tedious שני, אין הפניה ל־PRI |
| שרת VCT | מחרוזת חיבור אחת. אין שום הסתעפות פנים/חוץ בקוד `Systems/VCT/` |
| סנכרון לוקאלי→גלובלי | **לא קיים.** ל־`kyulan` אין אף אובייקט שפונה לאמזון |
| סנכרון גלובלי→לוקאלי | linked server `31.168.173.93`, 16 פרוצדורות — **כולן מול `amaba` בלבד** (`PART`, `PARTTEXT`, `SERNUMBERSTEXT`, `INVOICES`, `CPROF`). אפס פניות ל־`kyulan` או ל־`Calibrator` המקומי |
| Jobs על PRI | `to_maba_MainAll`, `to_priority_MBA_CALIBLOAD` — שניהם Priority ↔ `priority_kyul`, לא נוגעים באמזון |

`dbo.Source` (MABA / SEPHARM / גפן, לפי `EmailDomain`) הוא ריבוי־ארגונים, **לא** פנים/חוץ —
`Users.UserSourceId` כמעט ואינו מאוכלס.

## 3. החסם: אין בסיס נתונים לוקאלי לכתוב אליו

| DB על PRI | מצב | סכימה |
|-----------|-----|--------|
| `Calibrator` | **קפוא מ־17/03/2025.** `Orders` 11,863 שורות, `MAX(ID)`=11,863 רציף (טעינה חד־פעמית). `CalibrationHistory`/`CalibratedUnits`/`Alerts`/`MBA_CALIBLOAD` = 0 | 59 טבלאות, מבנה **שטוח** (שם לקוח ותיאור מכשיר באותה שורה של `Orders`) |
| `kyulan` | **חי ומעודכן** — `tblInstr` נערך 08/09/2026 15:39, 84 שורות ב־30 יום; `tblInstrCorrections` 44,736 | 49 טבלאות, 117 פרוצדורות, מבנה MABA2000 (`tblInstr`, `tblParentInstr`) |

איפה יושב כל אובייקט שהקוד ניגש אליו:

| | `tblInstr` | `MeasurementDevices` | `OrderDetails` | `AssignMeasurmentDevicesToCalibrator` |
|---|---|---|---|---|
| PRI\kyulan | ✅ | — | — | — |
| PRI\Calibrator | — | ✅ | — | — |
| AWS\Calibrator | — | ✅ | ✅ | ✅ (SP) |

**אף אחת מהטבלאות שהאפליקציה עובדת מולן לא קיימת ב־`kyulan`.** הפניית התחנה או האפליקציה
לשם תשבור אותן מיד.

## 4. מה נדרש כדי לממש

1. להקים עותק של סכימת האפליקציה על שרת ברשת המקומית (לא `kyulan` ולא `Calibrator` הקיימים).
2. לפצל את שכבת הנתונים — כ־100 פרוצדורות + מודלי Prisma — לניתוב לפי `IsInHouse`.
3. לבנות סנכרון דו־כיווני עם מדיניות התנגשויות ומזהים. שים לב ש־ETL קיים כבר מעתיק מזהים
   בין בסיסי הנתונים, כך שמזהה זהה בשני הצדדים אינו הוכחה לאותה רשומה.
4. להחליט מה קורה ל־4,609 שורות הפנים שכבר חיות ב־PROD.

**זה בדיוק הפרויקט שכבר נוסה ונזנח** (`CalibratorLocal` על PRI, ננטש באותו יום). חמש
אי־ההתאמות שהפילו אותו עדיין נכונות היום — נמדדו מחדש ב־08/09/2026:

| חסם | מצב נוכחי על PRI |
|-----|-------------------|
| compatibility level | 110 בכל בסיסי הנתונים (אמזון: SQL 2022) |
| collation | `Hebrew_BIN` ברמת השרת |
| tempdb | case-sensitive |
| linked server | loopback נדרש |
| גרסה | SQL Server 2019 (15.0.4480.2) |

## 5. פערים קטנים שאפשר לסגור בנפרד

- `KyulanSyncDB` — השם ש־`VCT.json` מבקש ראשון — **לא מוגדר** ב־`App.config` של ה־ConsoleHost,
  ולכן התחנה נופלת ל־`REMOTE_DATABASE_URL` (אמזון). הנפילה מתועדת ומכוונת ב־`ServerCore.cs:583`.
- כל ההגדרות של `KyulanSyncDB` בריפו כתובות `Database=Calibrator` — כלומר העותק הקפוא, ולא `kyulan`.
- `Systems/VCT/ComServer/ComServer.Hosts.GUIMonitor/App.config:16` מגדיר את `KyulanSyncDB` עם
  `providerName="MySql.Data.MyqlClient"` — ספק MySQL, ועם שגיאת כתיב, מול SQL Server.
