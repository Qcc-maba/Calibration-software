# אישור תיאום כיול ע"י הלקוח (Order approval by e-mail)

הזמנה שממתינה לאישור הלקוח → מייל עם פרטי התיאום → הלקוח מאשר או דוחה → פתיחת כיול חוץ ב-Priority.

## הזרימה

```
New (חדש)
  │  המרכזן משנה סטטוס ל-Pending
  ▼
Pending (ממתין)  ──▶  מייל ללקוח:  תאריך שיבוץ · אתר · תחום כיול · שם וטלפון הכייל · רשימת כלים
  │                                 + כפתורי "אשר תיאום" / "דחה תיאום"
  │
  │  הלקוח נכנס ל-/order-approval/<token>, כותב הערות (רשות) ולוחץ
  │
  ├──▶ Confirmed (מאושר)  ──▶  POST /api/priority/scenarios/return-goods  (פתיחת כיולי חוץ)
  │                             התוצאה נרשמת ב-OrderApprovalRequest.PriorityDocumentNumber / PriorityError
  │
  └──▶ Rejected (נדחה)    ──▶  ההערות נשמרות ב-OrderWorkPlans.CustomerComment
                                (העמודה שמסך המרכזן כבר מציג)
```

**הסטטוס `New` הוא חדש.** לפניו כל הזמנה עם `ClientConfirmationStatusId IS NULL` הוצגה כ"ממתין" —
כלומר כ-990 מתוך ~997 ההזמנות ב-STG נראו כאילו הלקוח נשאל, בזמן שאיש לא פנה אליו. עכשיו `Pending`
פירושו "נשלח מייל ואנחנו ממתינים לתשובה", וזה גם מה שמפעיל את השליחה.

## אבטחה — למה כך

| החלטה | הסיבה |
|-------|-------|
| הטוקן נשמר כ-HMAC-SHA256 עם pepper, לא כטקסט | קורא של ה-DB (או גיבוי שדלף) לא יכול לזייף קישור חי. אותו דפוס כמו `dbo.CustomerPortalOtp`. |
| הכפתורים במייל **לא** מבצעים את הפעולה — הם רק פותחים את העמוד | סורקי אבטחה של דואר ו-prefetch נכנסים לכל קישור בהודעה. קישור שמאשר ב-GET היה מאשר הזמנות מעצמו. הפרמטר `?decision=` רק מסמן את הכפתור בעמוד; האישור נשלח ב-POST. |
| `RespondedAt IS NULL` הוא תנאי ב-UPDATE עצמו | שתי לחיצות במקביל (דאבל-קליק, או העברת המייל הלאה) מייצרות החלטה אחת בדיוק. |
| קריאת Priority אחרי ה-commit, לא בתוכו | תשובת הלקוח לא הולכת לאיבוד כשה-Priority לא זמין. כישלון נרשם ב-`PriorityError` וניתן לחזור עליו. |
| `PRIORITY_API_PREVIEW=true` כברירת מחדל | עד שמוודאים את התרחיש מול חברת ה-Priority של אותה סביבה, הקריאה רק **מתכננת** את פעולות ה-OData ולא כותבת. |

## אובייקטים ב-DB

מותקנים ומאומתים ב-**STG (`Calibrator`)**. **לא הותקנו ב-PROD (`CalibratorProd`).**

| קובץ ב-`database/procedures/` | תפקיד |
|---|---|
| `dbo.OrderApprovalRequest.table.sql` | טבלת הקישורים החד-פעמיים + התשובה + תוצאת Priority |
| `dbo.ClientConfirmationStatus.New.seed.sql` | הוספת הסטטוס `New` / "חדש" לקטגוריה (StatusId מוקצה ע"י IDENTITY — ב-STG יצא 158) |
| `dbo.GetOrderApprovalDetails.sql` | כל מה שהמייל צריך על הזמנה אחת, בשורה אחת (JSON לכיילים/כלים/מק"טים) |
| `dbo.CreateOrderApprovalRequest.sql` | הנפקת קישור; מבטל קישור פתוח קודם לאותה הזמנה |
| `dbo.GetOrderApprovalRequestByToken.sql` | פענוח הטוקן לעמוד הציבורי, בלי לצרוך אותו |
| `dbo.ResolveOrderApprovalRequest.sql` | צריכת הקישור + שינוי הסטטוס, בטרנזקציה אחת |
| `dbo.SetOrderApprovalPriorityResult.sql` | חותמת תוצאת קריאת Priority |
| `dbo.GetWorkPlanData.sql` | ההגדרה החיה, בשינוי אחד: ברירת המחדל ל-`ClientConfirmationStatusId IS NULL` היא `New` במקום `Pending` |

**סדר ההרצה חשוב:** `ClientConfirmationStatus.New.seed.sql` לפני `GetWorkPlanData.sql`, אחרת
`@ClientConfirmationStatusDefault` יתפענח ל-NULL.

## משתני סביבה (`app/.env`)

```
ORDER_APPROVAL_PEPPER=<32+ תווים אקראיים>     # סיבוב הערך מבטל כל קישור שכבר נשלח
ORDER_APPROVAL_BASE_URL=https://cal.qcc.co.il  # חייב להיות כתובת שהלקוח מגיע אליה מבחוץ
PRIORITY_API_BASE_URL=                          # ריק = מדלגים על Priority; האישור עצמו עדיין עובד
PRIORITY_API_TOKEN=
PRIORITY_API_PREVIEW=true
```

שליחת המייל משתמשת ב-SMTP הקיים (`SMTP_*`) דרך `~/server/mail/mailer`.

## מה נשאר פתוח

- **`CalibrationRange`** נשלח ל-Priority מתוך `MainCategories.MainCategoryName` של שורות ההזמנה.
  התרחיש ב-Priority מצפה לתחום כיול כפי שמופיע באקסל החיצוני; אם המיפוי לא זהה, זה השדה לבדוק ראשון.
- **`CalibratorName`** נשלח לפי הכייל הראשון המשובץ. הזמנה עם כמה כיילים תיפתח ב-Priority על שם אחד.
- **נמען יחיד** — איש הקשר הראשון של הלקוח שיש לו מייל (בעדיפות לאיש קשר של אתר שמופיע בהזמנה).
  `RecipientCount` מוחזר כדי שאפשר יהיה להרחיב לכמה נמענים בלי לשנות את ה-SP.
