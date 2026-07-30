# QCC Analytics - סקריפטי סנכרון

סקריפטים אלו מושכים נתונים מבסיס הנתונים SQL Server ושולחים אותם לשרת.
לאחר הסנכרון, השרת מעתיק את הנתונים לפרודקשן **אוטומטית** תוך ~3 דקות.

---

## הגדרה ראשונית

### דרישות מקדימות
- Python 3.7 ומעלה
- גישה לבסיס הנתונים SQL Server

### שלב 1: התקנת ספריות Python
```
pip install pyodbc requests python-dateutil
```

### שלב 2: ODBC Driver (חובה ל-SQL Server)
- הורד: [Microsoft ODBC Driver 17 for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server)

### שלב 3: הגדרת config.py
וודא שהקובץ `config.py` מכיל את הפרטים הנכונים:
```python
SQL_CONFIG = {
    'server': 'YOUR_SQL_SERVER_ADDRESS',
    'database': 'YOUR_DATABASE_NAME',
    'username': 'YOUR_USERNAME',
    'password': 'YOUR_PASSWORD',
}
REPLIT_API_URL = 'https://YOUR-REPL.replit.dev/api/sync/customer-data'
```

---

## הרצה ידנית

```
run-sync.bat
```
מריץ את כל שלבי הסנכרון ומחכה לאישור לפני סגירה (מתאים לבדיקה).

---

## סנכרון אוטומטי יומי (מומלץ)

### הגדרה חד-פעמית — Windows Task Scheduler

1. לחץ ימני על `setup-scheduled-task.bat`
2. בחר **"הפעל כמנהל מערכת"**
3. המשימה תיווצר ותרוץ כל לילה ב-**03:00** אוטומטית

זהו. לא צריך לעשות כלום יותר.

### מה הסנכרון עושה (בסדר):
| שלב | תיאור |
|-----|--------|
| 1/3 | סנכרון לקוחות מ-Priority ERP |
| 2/3 | סנכרון הוצאות UPS מ-Priority |
| 3/3 | סנכרון משלוחים מ-Ship API (UPS) |
| אוטומטי | השרת מעתיק לפרודקשן ~3 דקות אחרי הסיום |

### לוגים
כל הרצה שומרת לוג בתיקייה `logs\sync_YYYY-MM-DD_HH-MM-SS.log`.
נשמרים 30 הלוגים האחרונים, ישנים יותר נמחקים אוטומטית.

### בדיקה ידנית של המשימה
```
schtasks /run /tn "QCC_Analytics_Sync"
```

### צפייה / עריכה במשימה
פתח את **Task Scheduler** → חפש `QCC_Analytics_Sync`

### מחיקת המשימה
```
schtasks /delete /tn "QCC_Analytics_Sync" /f
```

---

## סנכרון לקוח בודד

```
python sync-single-customer.py -c CUSTOMER_ID
```

---

## פתרון בעיות

| בעיה | פתרון |
|------|--------|
| שגיאת חיבור SQL | בדוק שה-IP/פורט 1433 פתוח בפיירוול |
| שגיאת חיבור Replit | בדוק שהשרת רץ ושכתובת ה-API נכונה ב-config.py |
| Ship API נכשל | WAF חוסם — נורמלי, הנתונים מסונכרנים בנפרד |
| המשימה לא רצה | הרץ `setup-scheduled-task.bat` שוב כמנהל מערכת |

---

## אבטחה

⚠️ אל תשתף את `config.py` — הוא מכיל סיסמאות!
אם אתה צריך לשתף קוד, העבר פרטים ל-`.env` ותוסיף `config.py` ל-`.gitignore`.
