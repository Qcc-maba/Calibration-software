# העתק קובץ זה ל-config.py ומלא את הפרטים שלך
# הקובץ config.py לא יישמר ב-Git

# Priority ERP Database (amaba) - חשבוניות והזמנות
SQL_CONFIG = {
    'server': r'maba-priority\pri',
    'database': 'amaba',
    'username': ***REMOVED***,
    'password': ***REMOVED***
}

# QCCData Database - מכשירים וכיולים
QCCDATA_CONFIG = {
    'server': r'maba-priority\pri',
    'database': 'QCCData',
    'username': ***REMOVED***,
    'password': ***REMOVED***
}

REPLIT_API_URL = 'https://232ca506-7be9-4e7f-a436-7bb478f77860-00-1bf7ltq07a1po.riker.replit.dev/api/sync/customer-data'

# Ship API (UPS Israel) - משלוחים
SHIP_API_CONFIG = {
    'base_url': 'https://newbetaapi.ship.co.il',
    'email': '***REMOVED***',
    'password': '***REMOVED***',
    'customer_id': '699226',

    # אם אימות אוטומטי נכשל (WAF), הוסף את ה-token מה-localStorage:
    # 1. פתח https://newbetaapp.ship.co.il והתחבר
    # 2. F12 → Application → Local Storage → https://newbetaapp.ship.co.il
    # 3. חפש את המפתח 'auth_token' → העתק את הערך
    # 4. הדבק כאן:
    # 'auth_token': '***REMOVED***',   # <-- הערך מ-localStorage
}
