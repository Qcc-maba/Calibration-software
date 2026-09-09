# הנחיות ל־Claude Code שרץ על maba-dc2

העתק את כל הקובץ הזה כהודעה ראשונה ל־Claude Code שרץ **על השרת**.
הוא כתוב כדי שיהיה אפשר לעבוד בלי לשאול שאלות חוזרות: כל מה שצריך לדעת נמצא כאן.

---

## הקשר

`QCC Analytics` הוא דשבורד ניתוח לקוחות למעבדת כיול (Express + React, Node), ובתוכו מסך
**"תמחור מוצרים"** (`/pricing`) שממפה רשימת מכשירים של לקוח למק"טים ולמחירים של מ.ב.א. הזורע.

- **רץ על השרת הזה** מתוך `C:\apps\qcc-analytics-deploy\app`, פורט **5000**.
- מופעל ע"י **משימה מתוזמנת או שירות** בשם `QCCAnalytics` (שתי האפשרויות קיימות בשטח —
  מתקין ה־IT נופל למשימה מתוזמנת כשאין NSSM). אל תניח מה מהם; בדוק.
- לוגים: `C:\apps\qcc-analytics-deploy\app\logs\service.err.log`
- הגדרות: `C:\apps\qcc-analytics-deploy\app\.env` (יש לו `DATABASE_URL`, `SQL_*` לפריוריטי,
  `DASHBOARD_USER/PASSWORD`)
- כל בקשה שאינה מ־localhost דורשת Basic auth. מקומית — אין הזדהות.

## המשימה

להעלות את הגרסה שפורסמה ב־`\\maba-srv\maba2000\Eliran\qcc-latest`, ולוודא שהיא עלתה.

```powershell
robocopy "\\maba-srv\maba2000\Eliran\qcc-latest" "C:\apps\qcc-server-deploy" /E
cd C:\apps\qcc-server-deploy
.\Install-QCCAnalytics.ps1 -Name QCCAnalytics -Target "C:\apps\qcc-analytics-deploy\app"
```

הסקריפט עוצר את האפליקציה, מגבה `dist_bak_<תאריך>`, מחליף `dist`, מוסיף `data\pricing`
(בלי לדרוס), מעדכן `.env`, מפעיל ומריץ בדיקות. הוא **דורש הרשאות מנהל** ונעצר מיד בלעדיהן.

## אימות — חובה, אל תסתפק ב"הסקריפט אמר OK"

```powershell
Invoke-RestMethod http://localhost:5000/api/version
```

צריך להחזיר `build : 2026-09-06 11:07 (fb6faa1)` או מאוחר יותר. **אם חוזר HTML במקום JSON —
הגרסה הישנה עדיין רצה** (ה־endpoint לא קיים בה), וזו התקלה הנפוצה כאן.

```powershell
Invoke-RestMethod http://localhost:5000/api/pricing/health          # itemsLoaded : 875
Invoke-RestMethod http://localhost:5000/api/pricing/source-status   # priorityConnected : True
(Invoke-RestMethod 'http://localhost:5000/api/pricing/customers?q=given&limit=3').customers
```

השאילתה האחרונה חייבת להחזיר `GIVEN IMAGING`. אם היא ריקה — הגרסה הישנה רצה.

## המלכודת שכבר הפילה אותנו פעמיים — קרא לפני שאתה מריץ

**החלפת קבצים אינה מפילה את התהליך הרץ.** node לא מחזיק את `dist\index.cjs` פתוח אחרי
העלייה, ולכן אפשר להחליף את כל ה־`dist` בזמן שהשרת ממשיך להגיש את הגרסה הישנה מהזיכרון.
התוצאה: על הדיסק גרסה חדשה, במסך גרסה ישנה, ונראה כאילו "הפריסה לא עשתה כלום".

לכן:
1. תמיד לוודא שהאפליקציה **באמת** נעצרה — הפורט השתחרר:
   ```powershell
   Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
   ```
   אם היא מחזירה שורה, התהליך חי. `Stop-ScheduledTask` נכשל בשקט בלי הרשאות מנהל.
2. אם צריך להרוג ידנית:
   ```powershell
   Stop-Process -Id (Get-NetTCPConnection -LocalPort 5000 -State Listen).OwningProcess -Force
   ```
3. אחרי ההפעלה — לאמת דרך `/api/version`, לא דרך "השירות במצב Running".

## אם משהו נשבר

```powershell
cd C:\apps\qcc-server-deploy
.\Rollback-QCCAnalytics.ps1
```

חוזר ל־`dist_bak_*` האחרון תוך פחות מדקה. **`data\pricing` לא נוגעים בה בשום מצב** — שם
יושבות ~2,650 התאמות שמשתמשים אישרו ידנית, וזה הנכס היחיד שאי אפשר לשחזר מ־build.

## משימה שנייה (אופציונלית): לגרום לשרת לעדכן את עצמו

קיימת משימה מתוזמנת `QCCAnalyticsUpdate` שאמורה למשוך גרסאות חדשות מהשיתוף לבד. היא רשומה
אך **לא עובדת**, ולא ידוע למה. הסקריפט שלה: `C:\apps\qcc-updater\Update-QCCAnalytics.ps1`.

```powershell
Copy-Item "\\maba-srv\maba2000\Eliran\qcc-latest\Update-QCCAnalytics.ps1" "C:\apps\qcc-updater\" -Force
Start-ScheduledTask -TaskName QCCAnalyticsUpdate
Start-Sleep 20
Get-Content C:\apps\qcc-updater\update.log -Tail 20
Get-ScheduledTask -TaskName QCCAnalyticsUpdate | Get-ScheduledTaskInfo | Select-Object LastRunTime, LastTaskResult
```

**ההשערה המובילה:** המשימה רצה תחת SYSTEM (חשבון המחשב `MABA-DC2$`), ולחשבון הזה אין הרשאת
קריאה ל־`\\maba-srv\maba2000\Eliran`. הגרסה החדשה של הסקריפט כותבת ללוג בכל מקרה, כולל שורה
`running as: ...`. אם זו אכן הסיבה, שתי דרכים:

```powershell
.\Install-AutoUpdater.ps1 -User 'MABA\<חשבון עם גישה>' -Password '<סיסמה>'
```
או לבקש מ־IT הרשאת קריאה לחשבון המחשב על השיתוף (עדיף — אין סיסמה שמתיישנת).

## כללי עבודה

- **פלט קונסולה באנגלית בלבד.** קונסולת Windows Server משבשת עברית. תיעוד ו־README בעברית — בסדר.
- **`.ps1` שמכיל עברית חייב להישמר UTF-8 עם BOM**, אחרת ה־parser של PowerShell 5.1 משתגע.
  עדיף פשוט לא לכתוב עברית בתוך סקריפטים.
- **אל תיגע** ב־`app\node_modules` (מיותר — ה־build עצמאי), ב־`db\`, וב־`scripts\` של IT.
- **אל תריץ `npm install` ואל תבנה על השרת.** הבנייה נעשית במקום אחר; כאן רק פורסים `dist` מוכן.
- אל תשנה סיסמאות או מחרוזות חיבור קיימות ב־`.env` אלא אם התבקשת במפורש.

## דיווח

בסיום דווח בקצרה: איזה `build` מדווח `/api/version`, כמה פריטים במחירון, אם פריוריטי מחובר,
ואם חיפוש "given" מחזיר תוצאה. אם משהו נכשל — צרף את השורות הרלוונטיות מהלוג, לא תיאור כללי.
