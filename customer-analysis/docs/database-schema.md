# מבנה בסיס הנתונים - QCCData

## סקירה כללית
בסיס הנתונים QCCData מאוחסן ב-Microsoft SQL Server ומכיל את כל המידע של מעבדת הכיול.

---

## טבלאות

### 1. datasheet - מכשירים וכיולים
טבלה מרכזית המכילה את כל המכשירים ופרטי הכיול שלהם.

| שדה | סוג | תיאור |
|-----|-----|--------|
| `Customer_Num` | VARCHAR | מספר לקוח (ח.פ.) |
| `Customer_Name` | VARCHAR | שם הלקוח/חברה |
| `Serial_No` | VARCHAR | מספר סידורי של המכשיר |
| `Device description` | VARCHAR | תיאור/שם המכשיר |
| `Model` | VARCHAR | דגם המכשיר |
| `Manufacturer` | VARCHAR | יצרן המכשיר |
| `Cal_Date` | DATE | תאריך כיול אחרון |
| `Next_Cal_Date` | DATE | תאריך כיול הבא |
| `SKA` | VARCHAR | קוד SKA (ספרה אחרונה: 7/8=כיול חיצוני, אחר=פנימי) |
| `Certificate_Number` | VARCHAR | מספר תעודת כיול |

**שימושים:**
- רשימת מכשירים של לקוח
- חישוב מכשירים פעילים/פג תוקף
- התפלגות סוגי מכשירים
- התפלגות פנים/חוץ לפי SKA
- התפלגות חודשית של כיולים

---

### 2. CustomerMain - פרטי לקוחות
מידע בסיסי על לקוחות.

| שדה | סוג | תיאור |
|-----|-----|--------|
| `Customer number` | VARCHAR | מספר לקוח (ח.פ.) |
| `Address` | VARCHAR | כתובת רחוב |
| `City` | VARCHAR | עיר |
| `STATE` | VARCHAR | מדינה/אזור |
| `Shipping Description` | VARCHAR | שיטת משלוח |
| `Agent name` | VARCHAR | שם הסוכן/נציג |

**שימושים:**
- הצגת כתובת מלאה
- שיטת משלוח ללקוח
- שם הנציג האחראי

---

### 3. ContactMain - אנשי קשר
פרטי אנשי קשר של לקוחות.

| שדה | סוג | תיאור |
|-----|-----|--------|
| `קשור ללקוח` | VARCHAR | מספר לקוח (קישור לטבלת לקוחות) |
| `Name` | VARCHAR | שם איש הקשר |
| `Phone` | VARCHAR | טלפון קווי |
| `Mobile` | VARCHAR | טלפון נייד |
| `Email` | VARCHAR | כתובת דוא"ל |
| `Main_Contact` | VARCHAR | האם איש קשר ראשי ('Y'/'N') |

**שימושים:**
- הצגת רשימת אנשי קשר
- זיהוי איש קשר ראשי

---

### 4. OrdersFULL - הזמנות והצעות מחיר
נתונים פיננסיים על הזמנות והצעות מחיר.

| שדה | סוג | תיאור |
|-----|-----|--------|
| `Customer Number` | VARCHAR | מספר לקוח |
| `Order Number` | VARCHAR | מספר הזמנה |
| `Quotation` | VARCHAR | מספר הצעת מחיר |
| `CurrentDate` | DATE | תאריך ההזמנה/הצעה |
| `Price after discount` | DECIMAL | מחיר לאחר הנחה |
| `Discount Percentage` | DECIMAL | אחוז הנחה |

**שימושים:**
- חישוב הכנסות שנתיות
- ספירת הזמנות והצעות מחיר
- חישוב סכום הנחות

---

## קשרים בין טבלאות

```
CustomerMain.Customer number ──┬── datasheet.Customer_Num
                               │
                               ├── ContactMain.קשור ללקוח
                               │
                               └── OrdersFULL.Customer Number
```

---

## לוגיקת עסקית

### זיהוי מיקום כיול (פנים/חוץ)
מבוסס על הספרה האחרונה בשדה `SKA`:
- **7 או 8** = כיול חיצוני (אתר לקוח)
- **אחר** = כיול פנימי (מעבדה)

### זיהוי סטטוס מכשיר
- **בתוקף**: `Next_Cal_Date >= TODAY`
- **פג תוקף**: `Next_Cal_Date < TODAY`

### חישוב הנחות
```sql
discountsTotal = SUM(Price after discount * Discount Percentage / 100)
```

---

## שאילתות לדוגמה

### כל המכשירים של לקוח
```sql
SELECT Serial_No, [Device description], Model, Manufacturer, 
       Cal_Date, Next_Cal_Date, SKA, Certificate_Number
FROM [dbo].[datasheet]
WHERE Customer_Num = '123456789'
ORDER BY Next_Cal_Date DESC
```

### סיכום פיננסי שנתי
```sql
SELECT 
    COUNT(DISTINCT [Order Number]) as ordersCount,
    COUNT(DISTINCT CASE WHEN Quotation IS NOT NULL THEN Quotation END) as quotesCount,
    SUM([Price after discount]) as revenue
FROM [dbo].[OrdersFULL]
WHERE [Customer Number] = '123456789' AND YEAR(CurrentDate) = 2024
```

### התפלגות כיולים פנים/חוץ
```sql
SELECT 
    [Device description],
    SUM(CASE WHEN RIGHT(SKA, 1) IN ('7', '8') THEN 1 ELSE 0 END) as external,
    SUM(CASE WHEN RIGHT(SKA, 1) NOT IN ('7', '8') THEN 1 ELSE 0 END) as internal
FROM [dbo].[datasheet]
WHERE Customer_Num = '123456789'
GROUP BY [Device description]
```
