# פורטל הלקוחות — runbook לעלייה לאוויר

> **נכתב:** 2026-08-30 · יעד: `portal-api.qcc.co.il` על AWS
> הסודות עצמם **אינם** במסמך הזה במכוון — הם נמסרו בטרמינל. אל תכניס אותם לכאן ואל תשלח במייל.

---

## 0. מה שכבר מוכן

| | |
|---|---|
| השירות ללא תלות on-prem | ✅ נבדק: רק SQL + SMTP |
| `SecureCookies: true` | ✅ |
| `AllowedOrigins` כולל `portal.qcc.co.il` | ✅ |
| `ExposureGuard` — סירוב לעלות חשוף בלי מפתח | ✅ |
| `DevLoginCode` לא קיים בקובץ הייצור | ✅ |
| סקריפט התקנה | ✅ `scripts/Install-CustomerPortalApi-Service.ps1` |

## 1. היעד: המכונה `MbaCustWeb`

מה שנמצא בבדיקה:

```
51.17.121.203  →  ec2-51-17-121-203.il-central-1.compute.amazonaws.com
SQL @@SERVERNAME = MbaCustWeb\QCC   ·   MachineName = MbaCustWeb   ·   Windows
port 443 OPEN   ·   port 80 closed   ·   port 5312 closed
```

זו מכונת Windows על EC2 ב-`il-central-1` — **אותו region של ה-S3 bucket**, ועליה כבר רץ ה-SQL Server של הפורטל. השם `MbaCustWeb` ("MBA Customer Web") ופורט 443 שכבר פתוח מרמזים שיש שם IIS.

**למה דווקא כאן ולא מכונה חדשה:** השירות מדבר רק עם ה-SQL שכבר יושב על המכונה הזו (חיבור מקומי, בלי לצאת לרשת) ועם M365. מכונה נוספת תוסיף עלות, latency ועוד משהו לתחזק, בלי להרוויח דבר.

✅ **אושר (2026-08-31):** מותר להוסיף role למכונה שמריצה את ה-SQL של הייצור. `MbaCustWeb` הוא היעד.

## 2. התקנת השירות (על MbaCustWeb, כמנהל)

```powershell
.\scripts\Install-CustomerPortalApi-Service.ps1 `
    -Bind any -Port 5312 `
    -ProxyApiKey       "<המפתח שנמסר>" `
    -ConnectionString  "Server=localhost\QCC;Database=CalibratorProd;User Id=app_prod;Password=<...>;Encrypt=True;TrustServerCertificate=True" `
    -SmtpUser zimun@mba.co.il -SmtpPassword "<...>" -SmtpFrom zimun@mba.co.il
```

שים לב ל-`Server=localhost\QCC` — מקומי, לא דרך הכתובת הציבורית.

בנוסף, שני משתני מכונה שהסקריפט לא מקבל כפרמטר:

```powershell
[Environment]::SetEnvironmentVariable('CustomerPortal__SessionSecret','<שנמסר>','Machine')
[Environment]::SetEnvironmentVariable('CustomerPortal__OtpPepper','<שנמסר>','Machine')
Restart-Service MabaCustomerPortalApi
```

> **`SessionSecret` חייב להיות זהה בשני הצדדים.** השירות חותם את עוגיית הסשן והאפליקציה מאמתת אותה. ערכים שונים = הלקוח מתחבר ומיד נזרק החוצה, בלי הודעת שגיאה מובנת.
>
> **`OtpPepper` — החלפה מבטלת כל קוד שנשלח ועדיין לא נוצל.** לקבוע פעם אחת.

## 3. Reverse proxy ל-HTTPS

השירות מדבר HTTP בלבד ומאזין על 5312. מול העולם צריך TLS:

* IIS → אתר חדש ל-`portal-api.qcc.co.il`, תעודה, ו-URL Rewrite ל-`http://localhost:5312`.
* להעביר `X-Forwarded-For` ו-`X-Forwarded-Proto`.
* **לא לפתוח את 5312 ל-Security Group.** רק 443. הסקריפט פותח 5312 בחומת האש של Windows ל-Domain/Private — כשפרוקסי מקומי עומד מלפנים אפשר לצמצם גם את זה ל-loopback.

לאחר מכן, ב-`appsettings.json`:

```json
"TrustedProxies": [ "127.0.0.1" ]
```

**בלי זה מגביל הקצב יראה את כתובת הפרוקסי במקום את כתובת הלקוח, וכל הלקוחות ייספרו כאחד** — לקוח אחד פעיל יחסום את כל השאר.

## 4. DNS

```
portal-api.qcc.co.il   A   51.17.121.203
```

(או CNAME ל-`ec2-51-17-121-203.il-central-1.compute.amazonaws.com`. אם ה-IP אינו Elastic IP — **לוודא שהוא כן**, אחרת הוא ישתנה בהפעלה מחדש ויפיל את הפורטל.)

## 5. Vercel

בפרויקט `app` → Settings → Environment Variables, ל-Production ול-Preview:

| שם | ערך |
|---|---|
| `CUSTOMER_PORTAL_API_URL` | `https://portal-api.qcc.co.il` |
| `CUSTOMER_SESSION_SECRET` | הערך שנמסר — **זהה** ל-`CustomerPortal__SessionSecret` |
| `CUSTOMER_PORTAL_API_KEY` | המפתח שנמסר — **זהה** ל-`CustomerPortal__ProxyApiKey` |
| `SMTP_FROM` | `פורטל מ.ב.א. הזורע <zimun@mba.co.il>` |

ואז **Redeploy** — משתני סביבה נקראים בזמן build/הרצה של הפונקציה, ולא נכנסים לתוקף בלי פריסה מחדש.

> ### 🛑 חסם ידוע — MBA-937
>
> **האפליקציה אינה שולחת את הכותרת `X-Portal-Api-Key` בכלל.** נבדק בקוד: `callPortalApi`
> שולח רק `content-type`, ואין משתנה למפתח ב-`src/env.js`.
>
> המשמעות: ברגע שיוגדר `ProxyApiKey` על השירות — וזה **חובה** לחשיפה ציבורית, אחרת
> הוא מסרב לעלות — **כל בקשה תיענה ב-401 והפורטל יהיה בלתי שמיש**. זה לא מתגלה היום רק
> מפני שמקומית המפתח ריק והבדיקה מושבתת.
>
> **[MBA-937](https://calibration-maba.atlassian.net/browse/MBA-937) חייב להיסגר ולהיפרס לפני שלב 5.**
> אין דרך לעקוף: לוותר על המפתח פירושו להשאיר את `request-otp` פתוח, והוא מגלה אילו
> כתובות מייל שייכות ללקוחות.

## 6. אימות אחרי העלייה

```bash
curl -s https://portal-api.qcc.co.il/health            # 200
curl -s -X POST https://portal-api.qcc.co.il/api/customer-auth/request-otp \
     -H 'content-type: application/json' -d '{"email":"eliran_ha@mba.co.il"}'
#   בלי הכותרת → 401  (זו ההוכחה שה-ProxyApiKey אכן נאכף)
```

ואז ב-`portal.qcc.co.il`: לבקש קוד, לקבל מייל מ"פורטל מ.ב.א. הזורע", להיכנס, ולראות 175 מכשירים.

---

## מה שאסור לשכוח

1. **`DevLoginCode` לא מוגדר בייצור.** הוא לא בקובץ, וה-guard חוסם אותו גם אם מישהו יוסיף — אבל אל תוסיף.
2. **`ProxyApiKey` ריק = השירות מסרב לעלות** בהאזנה ציבורית. זה מכוון: `request-otp` עונה תשובה שונה לכתובת רשומה ולא רשומה, כך ששירות פתוח מאפשר לגלות מי מהלקוחות שלך.
3. **`portal.qcc.co.il` מ-Vercel מגיש את כל האפליקציה** — דומיין ב-Vercel מתחבר לפרויקט, לא לנתיב. כלומר שיבוץ עבודה, אשף הכיול והאריזה ייענו בכתובת שנמסרה ללקוח. אלה מסכים פנימיים ואין להם מה לעשות שם. להגבלה ל-`/customer/*` נדרש `middleware.ts` שאינו קיים בקוד — [MBA-938](https://calibration-maba.atlassian.net/browse/MBA-938) ל-Dako.
   זו **הגנה בשכבות ולא בקרת הגישה עצמה**: המסכים הפנימיים ממילא דורשים התחברות, כך שאין כאן חור. זה מונע מלקוח לגלות שהם קיימים, ומונע ממסך פנימי להיטען תחת דומיין ממותג-לקוח.
4. **`ReportArchiveSync` נשאר on-prem** ואינו חלק מהעלייה הזו. הוא קורא מה-share של Priority וכותב ל-S3 ול-DB שבענן.
