# Maba.VCT.CustomerPortalApi

שירות net10 שמחזיק את **ההתחברות לפורטל הלקוחות** — כניסה בקוד חד־פעמי במייל.
הממשק (`app/`, Next.js) לא מכיל את הלוגיקה הזו: הוא רק מעביר אליו את הבקשות ומאמת את קוקי הסשן
שהשירות מנפיק.

אותו דפוס פריסה כמו `Maba.VCT.InstructionAssistant`.

## הזרימה

1. הלקוח מזין כתובת מייל.
2. `dbo.CreateCustomerPortalOtp` בודק אם הכתובת שייכת לאיש קשר של לקוח — קודם ב-`CustomerContacts`
   ואם לא נמצא, בפריוריטי (`PHONEBOOK` דרך ה-linked server), ואז מעתיק את איש הקשר ל-`CustomerContacts`.
3. אם נמצאה — נוצר קוד בן 6 ספרות ונשלח במייל. **הקוד עצמו לא נשמר**: ל-DB נכנס רק
   HMAC-SHA256 שלו עם pepper צד־שרת.
4. הלקוח מזין את הקוד, `dbo.VerifyCustomerPortalOtp` מממש אותו פעם אחת בלבד, והשירות מנפיק
   קוקי סשן חתום.

הקוד תקף 10 דקות, מותרים 5 ניסיונות שגויים, ולכל היותר 5 קודים ל-15 דקות לכל כתובת.

## Endpoints

| Method | Path | תיאור |
|---|---|---|
| `GET`  | `/health` | בדיקת חיים + האם ה-DB וה-SMTP מוגדרים |
| `POST` | `/api/customer-auth/request-otp` | `{ email }` → `{ status, expiresInSeconds, retryAfterSeconds }` |
| `POST` | `/api/customer-auth/verify-otp` | `{ email, code }` → `{ status, attemptsLeft, session }` + `Set-Cookie` |
| `GET`  | `/api/customer-auth/me` | `{ session }` — או `{ session: null }` |
| `POST` | `/api/customer-auth/sign-out` | מוחק את הקוקי |

`status` של `request-otp`: `sent` \| `emailNotFound` \| `rateLimited` \| `sendFailed`.
`status` של `verify-otp`: `verified` \| `invalid` \| `expired` \| `tooManyAttempts` \| `notFound`.

## הרצה

```powershell
dotnet run --project Systems/CustomerPortalApi        # http://localhost:5312
dotnet test  Systems/CustomerPortalApi.Tests
```

להרצה מקומית: להעתיק את `appsettings.Development.example.json` ל-`appsettings.Development.json`
ולמלא. הקובץ ב-gitignore.

## קונפיגורציה (`CustomerPortal`)

| מפתח | הערה |
|---|---|
| `ConnectionString` | `Calibrator` / `CalibratorProd`. זה הרובד היחיד שמחזיק אותו. |
| `OtpPepper` | מפתח ה-HMAC של הקודים. שינוי שלו פוסל קודים פתוחים — לא מזיק. |
| `SessionSecret` | **חייב להיות זהה בתו** ל-`CUSTOMER_SESSION_SECRET` בממשק, שמאמת את אותו קוקי. |
| `AllowedOrigins` | מקורות שמותר להם לקרוא עם credentials. |
| `SecureCookies` | `false` רק לפיתוח מקומי מעל HTTP. |
| `Smtp` | Microsoft 365: `smtp.office365.com:587`, `UseImplicitTls: false` (STARTTLS). |

ב-Microsoft 365 צריך ש-SMTP AUTH יהיה מאופשר על התיבה
(`Set-CASMailbox -SmtpClientAuthenticationDisabled $false`), ואם יש MFA — App Password.

## תלויות ב-DB

הפרוצדורות ב-[`database/procedures/`](../../database/procedures/):
`dbo.CustomerPortalOtp.table.sql`, `dbo.CreateCustomerPortalOtp.sql`,
`dbo.VerifyCustomerPortalOtp.sql`, `dbo.GetCustomerPortalContactByEmail.sql`,
`dbo.GetPriorityContactsByEmail.sql`.

**פרוסות ל-STG (`Calibrator`) בלבד — עדיין לא ל-`CalibratorProd`.**
