# העתק קובץ זה ל-config.py ומלא את הפרטים שלך
# הקובץ config.py לא יישמר ב-Git (ראה .gitignore)
# אין לשים כאן ערכים אמיתיים — placeholders בלבד.

# Priority ERP Database (amaba) - חשבוניות והזמנות
SQL_CONFIG = {
    'server': r'SERVER\INSTANCE',
    'database': 'amaba',
    'username': 'YOUR_SQL_USER',
    'password': 'YOUR_SQL_PASSWORD'
}

# QCCData Database - מכשירים וכיולים
QCCDATA_CONFIG = {
    'server': r'SERVER\INSTANCE',
    'database': 'QCCData',
    'username': 'YOUR_SQL_USER',
    'password': 'YOUR_SQL_PASSWORD'
}

# כתובת ה-API של השרת שאליו הסקריפט שולח נתונים מסונכרנים
SERVER_API_URL = 'http://localhost:5000/api/sync/customer-data'

# Ship API (UPS Israel) - משלוחים
SHIP_API_CONFIG = {
    'base_url': 'https://newbetaapi.ship.co.il',
    'email': 'YOUR_SHIP_EMAIL',
    'password': 'YOUR_SHIP_PASSWORD',
    'customer_id': 'YOUR_CUSTOMER_ID',

    # אם אימות אוטומטי נכשל (WAF), הוסף את ה-token מה-localStorage:
    # 1. פתח https://newbetaapp.ship.co.il והתחבר
    # 2. F12 → Application → Local Storage → https://newbetaapp.ship.co.il
    # 3. חפש את המפתח 'auth_token' → העתק את הערך
    # 4. הדבק כאן:
    # 'auth_token': 'YOUR_AUTH_TOKEN',
}
