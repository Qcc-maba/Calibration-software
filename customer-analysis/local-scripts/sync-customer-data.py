# sync-customer-data.py
"""
סקריפט סנכרון נתוני לקוחות מ-Priority ERP (amaba)

גרסה: 10.0 (30/12/2025) - מעבר לטבלאות INVOICES ו-INVOICESA
  - הכנסות מטבלת INVOICES (סכומים, הנחות, מטבע)
  - סינון לפי INVOICESA.TYPE = 'C' (חשבוניות סופיות/סגורות)
  - תמיכה מלאה בהנחות ומטבעות
  - נטו = TOTPRICE - VAT

התקנה:
    pip install pyodbc requests

שימוש:
    python sync-customer-data.py                   # סנכרון כל הלקוחות
    python sync-customer-data.py -c 10077          # סנכרון לקוח ספציפי
    python sync-customer-data.py --departments     # סנכרון נתוני מחלקות
    python sync-customer-data.py --calibrators     # סנכרון כיילים
    python sync-customer-data.py --ship-discover   # גילוי endpoints של Ship API
    python sync-customer-data.py --ship            # סנכרון משלוחים מ-Ship API
    python sync-customer-data.py --ship --ship-from 2025-01-01 --ship-to 2025-12-31
    py sync-customer-data.py --ship --ship-from 2025-01-01 --ship-to 2025-12-31
    python sync-customer-data.py --url https://client-analytics-dashboard--eliran8hadad.replit.app --calibrators
    py sync-customer-data.py --url https://client-analytics-dashboard--eliran8hadad.replit.app --calibrators
    python sync-customer-data.py --cal-alerts                              # סנכרון התראות כיול בלבד (מהיר, ללא לולאת לקוחות)
    py sync-customer-data.py --url https://client-analytics-dashboard--eliran8hadad.replit.app --cal-alerts
    python sync-customer-data.py --operational-query                       # שאילתת תפעול — שנה שוטפת
    python sync-customer-data.py --operational-query --date-from 2024-01-01 --date-to 2024-12-31 --clear
    python sync-customer-data.py --financial-query                         # שאילתת פיננסים — שנה שוטפת
    python sync-customer-data.py --financial-query --date-from 2024-01-01 --date-to 2024-12-31 --clear
"""

VERSION = "10.47"  # Added --cal-alerts standalone flag for fast calibration-alerts-only sync without full customer loop

import pyodbc
import requests
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse
import time
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
from typing import Dict, List, Any, Optional
import threading
from collections import defaultdict

# דגל גלובלי לדילוג על QCCData אם אין גישה
qccdata_available = True
qccdata_lock = threading.Lock()

# ========== ברירת מחדל להגדרות ציון ==========
DEFAULT_SCORING_CONFIG = {
    'weights': {'tenure': 25, 'revenue': 40, 'frequency': 35},
    'thresholds': {'A': 85, 'B': 70, 'C': 55, 'D': 40},
    'maxValues': {'tenureMonths': 60, 'revenueAmount': 500000}
}

def fetch_scoring_config(base_url: str) -> dict:
    """שליפת הגדרות ציון מה-API"""
    try:
        # Extract base URL without the sync endpoint
        if '/api/sync' in base_url:
            api_base = base_url.rsplit('/api/sync', 1)[0]
        else:
            api_base = base_url.rstrip('/')
        
        config_url = f"{api_base}/api/settings/scoring"
        response = requests.get(config_url, timeout=10)
        if response.status_code == 200:
            config = response.json()
            print(f"[CONFIG] Loaded scoring config from API")
            return config
    except Exception as e:
        print(f"[WARN] Could not fetch scoring config: {e}")
    
    print(f"[CONFIG] Using default scoring config")
    return DEFAULT_SCORING_CONFIG

# ========== טעינת הגדרות ==========
try:
    from config import SQL_CONFIG, REPLIT_API_URL
    SYNC_SECRET = getattr(__import__('config'), 'SYNC_SECRET', '') or ''
    print(f"[CONFIG] Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }
    REPLIT_API_URL = os.environ.get('REPLIT_API_URL', 'https://your-replit-url.replit.dev/api/sync/customer-data')
    SYNC_SECRET = os.environ.get('SYNC_SECRET', '')
    if not SQL_CONFIG['username']:
        print("[ERROR] חסר קובץ config.py או environment variables")

# ========== פונקציות עזר לתאריכים ==========
PRIORITY_EPOCH = datetime(1988, 1, 1)

def priority_date_to_datetime(priority_date: int) -> Optional[datetime]:
    """המרת תאריך Priority (דקות מ-1988) לתאריך רגיל"""
    if not priority_date or priority_date <= 0:
        return None
    try:
        return PRIORITY_EPOCH + timedelta(minutes=priority_date)
    except:
        return None

def format_date(dt: datetime) -> str:
    """המרת תאריך לפורמט dd/mm/yyyy"""
    if dt:
        return dt.strftime('%d/%m/%Y')
    return ''

# ========== מיפוי מחלקות כיול לפי PARTNAME ==========
def get_location_from_part(part_number: str) -> str:
    """
    זיהוי מיקום כיול (פנים/חוץ/קבלני משנה) לפי הסיומת של מק"ט הפריט
    סיומת 7 או 8 = חוץ (אתר לקוח)
    סיומת 0 או 1 = פנים (מעבדה)
    סיומת 4 או 5 = קבלני משנה
    שאר הספרות = פנים (ברירת מחדל)
    
    דוגמאות:
    150101-0 -> 0 -> פנים
    150101-7 -> 7 -> חוץ
    150101-4 -> 4 -> קבלני משנה
    """
    if not part_number:
        return 'internal'
    
    part_number = part_number.strip()
    if not part_number:
        return 'internal'
    
    # Get the last character after the hyphen (e.g., "150101-0" -> "0")
    # Handle both "150101-0" and "1501010" formats
    last_char = part_number[-1]
    
    # Check suffix: 7 or 8 = external
    if last_char in ['7', '8']:
        return 'external'
    
    # Check suffix: 4 or 5 = subcontractor
    if last_char in ['4', '5']:
        return 'subcontractor'
    
    # All other cases (0, 1, 2, 3, 6, 9) = internal
    return 'internal'

# ========== חיבור לבסיס הנתונים ==========
ODBC_DRIVERS = [
    "ODBC Driver 17 for SQL Server",
    "ODBC Driver 18 for SQL Server",
    "ODBC Driver 13 for SQL Server",
    "SQL Server Native Client 11.0",
    "SQL Server",
]

def _detect_driver():
    """מציאת הדרייבר הראשון הזמין במערכת"""
    available = [d for d in pyodbc.drivers()]
    for preferred in ODBC_DRIVERS:
        if preferred in available:
            return preferred
    # fallback: כל דרייבר SQL Server שנמצא
    for d in available:
        if "SQL Server" in d or "sql server" in d.lower():
            return d
    raise RuntimeError(f"לא נמצא ODBC Driver ל-SQL Server. דרייברים זמינים: {available}")

def get_connection(retries=3):
    """יצירת חיבור לבסיס הנתונים Priority עם ניסיונות חוזרים"""
    driver = _detect_driver()
    connection_string = (
        f"DRIVER={{{driver}}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']};"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout=30"
    )
    
    for attempt in range(retries):
        try:
            conn = pyodbc.connect(connection_string)
            conn.autocommit = True  # מונע נעילות
            return conn
        except Exception as e:
            if attempt < retries - 1:
                print(f"  [RETRY] חיבור נכשל, מנסה שוב ({attempt + 1}/{retries})...")
                time.sleep(1)
            else:
                raise e

# ========== בדיקה אם שם מכיל אותיות ==========
def has_alpha(text: str) -> bool:
    """בדיקה אם הטקסט מכיל לפחות אות אחת (עברית או אנגלית)"""
    if not text:
        return False
    return any(c.isalpha() for c in text)

def is_english_char(c: str) -> bool:
    """בדיקה אם תו הוא אנגלי"""
    return 'A' <= c <= 'Z' or 'a' <= c <= 'z'

def fix_reversed_english(text: str) -> str:
    """
    תיקון טקסט אנגלי הפוך בתוך טקסט עברי.
    מילים אנגליות מופיעות הפוך בגלל RTL - מהפך רק את החלקים האנגליים.
    """
    if not text:
        return text
    
    result = []
    current_english = []
    
    for char in text:
        if is_english_char(char):
            current_english.append(char)
        else:
            if current_english:
                # הפוך את המילה האנגלית
                result.append(''.join(reversed(current_english)))
                current_english = []
            result.append(char)
    
    # טיפול בסוף המחרוזת
    if current_english:
        result.append(''.join(reversed(current_english)))
    
    return ''.join(result)

# ========== בניית תעודות החזרה אחרונות עם פירוט לפי חודש ==========
def build_recent_returns(return_documents: List[Dict[str, Any]]) -> Dict[str, Any]:
    """בניית אובייקט תעודות החזרה - רק חודשיים אחרונים"""
    if not return_documents:
        return {
            'count': 0,
            'revenue': 0,
            'period': 'חודשיים אחרונים',
            'byMonth': []
        }
    
    # חישוב טווח חודשיים אחרונים
    now = datetime.now()
    current_month_key = f"{now.year}-{now.month:02d}"
    
    # חודש קודם
    if now.month == 1:
        prev_month_key = f"{now.year - 1}-12"
    else:
        prev_month_key = f"{now.year}-{now.month - 1:02d}"
    
    valid_months = {current_month_key, prev_month_key}
    
    # מיון לפי חודש - רק חודשיים אחרונים
    months = {}
    hebrew_months = ['ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 
                     'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר']
    
    filtered_docs = []
    for doc in return_documents:
        try:
            # תאריך בפורמט DD/MM/YYYY
            date_str = doc.get('openDate', '')
            if date_str:
                parts = date_str.split('/')
                if len(parts) == 3:
                    month_num = int(parts[1])
                    year = parts[2]
                    month_key = f"{year}-{month_num:02d}"
                    
                    # סינון - רק חודשיים אחרונים
                    if month_key not in valid_months:
                        continue
                    
                    filtered_docs.append(doc)
                    month_name = f"{hebrew_months[month_num - 1]} {year}"
                    
                    if month_key not in months:
                        months[month_key] = {'month': month_name, 'count': 0, 'revenue': 0}
                    
                    months[month_key]['count'] += 1
                    months[month_key]['revenue'] += doc.get('value', 0)
        except:
            pass
    
    # מיון לפי חודש (מהאחרון לראשון)
    by_month = sorted(months.values(), key=lambda x: x['month'], reverse=True)
    for m in by_month:
        m['revenue'] = round(m['revenue'], 2)
    
    return {
        'count': len(filtered_docs),
        'revenue': round(sum(d.get('value', 0) for d in filtered_docs), 2),
        'period': 'חודשיים אחרונים',
        'byMonth': by_month
    }

# ========== שליפת נתוני לקוח ==========
def fetch_customer_data(cust_id, shared_conn=None, scoring_config: dict = None) -> Dict[str, Any]:
    """
    שליפת כל נתוני לקוח
    cust_id יכול להיות:
    - CUST = מזהה פנימי של Priority (מספר)
    - CUSTNAME = מספר לקוח/HP (מחרוזת או מספר)
    הפונקציה תנסה למצוא קודם לפי CUST, ואם לא נמצא - לפי CUSTNAME
    """
    if scoring_config is None:
        scoring_config = DEFAULT_SCORING_CONFIG
    own_connection = shared_conn is None
    conn = shared_conn if shared_conn else get_connection()
    cursor = conn.cursor()
    
    # שליפת מידע בסיסי על הלקוח - עמודות בסיסיות בלבד
    # ניסיון ראשון: חיפוש לפי CUSTNAME (מספר לקוח/HP) - זה מה שהמשתמש בדרך כלל מזין
    cursor.execute("""
        SELECT CUSTOMERS.CUST, CUSTNAME, CUSTDES, ADDRESS, PHONE, SHIPTYPES.STDES AS SHIPMETHOD
        FROM CUSTOMERS
        LEFT JOIN SHIPTYPES ON CUSTOMERS.SHIPTYPE = SHIPTYPES.SHIPTYPE
        WHERE CUSTNAME = ?
    """, str(cust_id))
    
    customer_row = cursor.fetchone()
    
    if customer_row:
        print(f"  [INFO] נמצא לפי CUSTNAME={cust_id} -> CUST={customer_row.CUST}")
        # עדכון cust_id למזהה הפנימי הנכון לשאילתות הבאות
        cust_id = customer_row.CUST
    else:
        # אם לא נמצא לפי CUSTNAME, ננסה לפי CUST (מזהה פנימי)
        print(f"  [INFO] לא נמצא לפי CUSTNAME={cust_id}, מחפש לפי CUST...")
        cursor.execute("""
            SELECT CUSTOMERS.CUST, CUSTNAME, CUSTDES, ADDRESS, PHONE, SHIPTYPES.STDES AS SHIPMETHOD
            FROM CUSTOMERS
            LEFT JOIN SHIPTYPES ON CUSTOMERS.SHIPTYPE = SHIPTYPES.SHIPTYPE
            WHERE CUSTOMERS.CUST = ?
        """, cust_id)
        customer_row = cursor.fetchone()
        if customer_row:
            print(f"  [INFO] נמצא לפי CUST={cust_id}")
    
    if not customer_row:
        cursor.close()
        if own_connection:
            conn.close()
        raise ValueError(f"לקוח {cust_id} לא נמצא")
    
    # בחירת שם הלקוח - מעדיפים CUSTDES אם הוא מכיל טקסט עברי/אנגלי, אחרת CUSTNAME
    custname = (customer_row.CUSTNAME or '').strip()
    custdes = (customer_row.CUSTDES or '').strip()
    
    # בדיקה אם יש שם תקין (עם אותיות) - אם לא, דילוג על הלקוח
    if not has_alpha(custdes) and not has_alpha(custname):
        cursor.close()
        if own_connection:
            conn.close()
        raise ValueError(f"[SKIP] לקוח {cust_id} - שם מורכב רק ממספרים: '{custdes or custname}'")
    
    # אם CUSTDES מכיל אותיות (לא רק מספרים), נעדיף אותו
    if has_alpha(custdes):
        company_name = custdes
    elif has_alpha(custname):
        company_name = custname
    else:
        company_name = custdes or custname
    
    # תיקון טקסט אנגלי הפוך
    company_name = fix_reversed_english(company_name)
    
    # CUST = מזהה פנימי של Priority
    # CUSTNAME = מספר הלקוח כפי שמוצג למשתמש (ה"ח.פ." או מספר לקוח)
    customer = {
        'id': str(customer_row.CUST),  # מזהה פנימי לשימוש בשאילתות
        'hp': custname if custname else str(customer_row.CUST),  # מספר לקוח להצגה
        'companyName': company_name,
        'address': (customer_row.ADDRESS or '').strip(),
        'phone': (customer_row.PHONE or '').strip(),
        'state': '',
        'shippingMethod': fix_reversed_english((customer_row.SHIPMETHOD or '').strip()),  # שיטת שינוע מ-SHIPTYPES
    }
    
    # ========== שליפת אנשי קשר מ-PHONEBOOK ==========
    # סינון לאנשי קשר פעילים בלבד (INACTIVE != 'Y')
    contacts = []
    try:
        cursor.execute("""
            SELECT NAME, CELLPHONE, EMAIL
            FROM PHONEBOOK
            WHERE CUST = ? AND NAME IS NOT NULL
              AND (INACTIVE IS NULL OR INACTIVE != 'Y')
            ORDER BY NAME
        """, cust_id)
        
        for row in cursor.fetchall():
            contact_name = (row.NAME or '').strip()
            if contact_name:
                contacts.append({
                    'name': fix_reversed_english(contact_name),
                    'phone': (row.CELLPHONE or '').strip(),
                    'email': (row.EMAIL or '').strip(),
                    'title': ''
                })
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת אנשי קשר: {e}")
        pass
    
    # ========== שליפת תלונות מ-MED_COMPLAINT ==========
    complaints = []
    try:
        cursor.execute("""
            SELECT *
            FROM MED_COMPLAINT
            WHERE CUST = ?
            ORDER BY 1 DESC
        """, cust_id)
        
        # שליפת שמות העמודות
        columns = [column[0] for column in cursor.description]
        print(f"  [DEBUG] MED_COMPLAINT columns: {columns}")
        
        for row in cursor.fetchall():
            complaint_data = {}
            for i, col in enumerate(columns):
                val = row[i]
                # המרת תאריכי Priority אם יש
                if 'DATE' in col.upper() and isinstance(val, (int, float)) and val > 0:
                    dt = priority_date_to_datetime(int(val))
                    complaint_data[col] = format_date(dt) if dt else str(val)
                else:
                    complaint_data[col] = str(val).strip() if val else ''
            complaints.append(complaint_data)
        
        if complaints:
            print(f"  [INFO] נמצאו {len(complaints)} תלונות")
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת תלונות: {e}")
        pass
    
    # ========== שליפת סוכן מ-CUSTOMERS ==========
    shipping_method = ''
    agent_name = ''
    delivery_days = ''
    try:
        cursor.execute("""
            SELECT c.CUST, 
                   a.AGENTCODE, a.AGENTNAME
            FROM CUSTOMERS c
            LEFT JOIN AGENTS a ON c.AGENT = a.AGENT
            WHERE c.CUST = ?
        """, cust_id)
        
        agent_row = cursor.fetchone()
        if agent_row:
            agent_name = fix_reversed_english((agent_row.AGENTNAME or '').strip())
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת סוכן: {e}")
        pass
    
    # ========== שליפת חשבוניות מ-INVOICES ==========
    # INVOICES - מכיל סכומים, הנחות, מטבע
    # QPRICE = סכום לפני הנחה
    # VATPRICE = סכום אחרי הנחה (לפני מע"מ) - זה מה שהלקוח שילם בפועל
    # DISCOUNT = אחוז הנחה
    # DISPRICE = סכום ההנחה בש"ח
    # TOTPRICE = סכום כולל מע"מ
    invoices = []
    monthly_revenue = defaultdict(lambda: {'revenue': 0, 'count': 0})
    invoices_seen = set()  # מניעת כפילויות
    
    try:
        cursor.execute("""
            SELECT DISTINCT
                IVNUM,
                IVDATE,
                TOTPRICE,
                VAT,
                QPRICE,
                VATPRICE,
                DISPRICE,
                DISCOUNT
            FROM INVOICES
            WHERE CUST = ? 
              AND IVDATE > 0
              AND IVNUM LIKE 'I%'
            ORDER BY IVDATE DESC
        """, cust_id)
        
        rows = cursor.fetchall()
        
        for row in rows:
            inv_num = (row.IVNUM or '').strip()
            
            # מניעת כפילויות
            if inv_num in invoices_seen:
                continue
            invoices_seen.add(inv_num)
            
            inv_date = priority_date_to_datetime(row.IVDATE)
            if inv_date and inv_date.year >= 2020:
                total_price = float(row.TOTPRICE or 0)
                vat = float(row.VAT or 0)
                qprice = float(row.QPRICE or 0)    # מחיר לפני הנחה
                vatprice = float(row.VATPRICE or 0) # מחיר אחרי הנחה, לפני מע"מ
                disprice = float(row.DISPRICE or 0) # סכום הנחה מ-Priority (ישיר)
                discount_pct = float(row.DISCOUNT or 0)  # אחוז הנחה מ-Priority

                # netPrice = VATPRICE (מחיר אחרי הנחה, לפני מע"מ) - זה מה שהלקוח שילם
                net_price = vatprice if vatprice > 0 else (total_price - vat)

                # סכום ההנחה: מחשבים QPRICE × אחוז_הנחה (הכי מדויק לפי Priority)
                # גיבוי 1: DISPRICE (שדה סכום הנחה מ-Priority)
                # גיבוי 2: QPRICE - VATPRICE
                if discount_pct > 0 and qprice > 0:
                    discount_amount = round(qprice * (discount_pct / 100), 2)
                elif disprice > 0:
                    discount_amount = disprice
                elif qprice > 0 and vatprice > 0:
                    discount_amount = max(qprice - vatprice, 0)
                else:
                    discount_amount = 0
                
                invoices.append({
                    'invoiceNumber': inv_num,
                    'date': format_date(inv_date),
                    'year': inv_date.year,
                    'month': inv_date.month,
                    'totalPrice': total_price,
                    'grossPrice': round(qprice, 2),  # לפני הנחה
                    'netPrice': round(net_price, 2),  # אחרי הנחה
                    'vat': vat,
                    'discount': round(discount_amount, 2),  # סכום ההנחה המחושב
                    'discountPct': discount_pct,
                    'currency': 'ILS'
                })
                
                # סיכום חודשי
                month_key = f"{inv_date.year}-{inv_date.month:02d}"
                monthly_revenue[month_key]['revenue'] += net_price
                monthly_revenue[month_key]['count'] += 1
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת חשבוניות: {e}")
    
    # ========== שליפת הזמנות ==========
    orders = []
    try:
        cursor.execute("""
            SELECT ORD, ORDNAME, CURDATE, TOTPRICE, QPRICE, VAT, DISPRICE
            FROM ORDERS
            WHERE CUST = ? AND CURDATE > 0
            ORDER BY CURDATE DESC
        """, cust_id)
        
        for row in cursor.fetchall():
            ord_date = priority_date_to_datetime(row.CURDATE)
            if ord_date and ord_date.year >= 2020:
                orders.append({
                    'orderId': row.ORD,
                    'orderName': (row.ORDNAME or '').strip(),
                    'date': format_date(ord_date),
                    'year': ord_date.year,
                    'month': ord_date.month,
                    'totalPrice': float(row.TOTPRICE or 0),
                    'netPrice': float(row.QPRICE or 0),
                    'vat': float(row.VAT or 0),
                    'discountAmount': float(row.DISPRICE or 0),
                    'closed': False
                })
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת הזמנות: {e}")
    
    # ========== שליפת הצעות מחיר ==========
    quotes = []
    try:
        cursor.execute("""
            SELECT CPROFNUM, UDATE, TOTPRICE, QPRICE, VAT, DISPRICE
            FROM CPROF
            WHERE CUST = ? AND UDATE > 0
            ORDER BY UDATE DESC
        """, cust_id)
        
        for row in cursor.fetchall():
            quote_date = priority_date_to_datetime(row.UDATE)
            if quote_date and quote_date.year >= 2020:
                quotes.append({
                    'quoteNumber': (row.CPROFNUM or '').strip(),
                    'date': format_date(quote_date),
                    'year': quote_date.year,
                    'month': quote_date.month,
                    'totalPrice': float(row.TOTPRICE or 0),
                    'netPrice': float(row.QPRICE or 0),
                    'vat': float(row.VAT or 0),
                    'discountAmount': float(row.DISPRICE or 0)
                })
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת הצעות מחיר (CPROF): {e}")
    
    # ========== שליפת פירוט הזמנות - רמת הזמנה (לא שורות) ==========
    orders_detail = []
    calibration_types = defaultdict(lambda: {'total': 0, 'internal': 0, 'external': 0, 'subcontractor': 0})
    calibration_by_location = []
    orders_seen = set()
    internal_total = 0
    external_total = 0
    
    try:
        # שליפה ברמת הזמנה - כל הזמנה פעם אחת
        cursor.execute("""
            SELECT 
                o.ORDNAME, o.CURDATE, o.QPRICE, o.TOTPRICE, o.DISPRICE,
                (SELECT COUNT(*) FROM ORDERITEMS oi WHERE oi.ORD = o.ORD) as LINE_COUNT
            FROM ORDERS o
            WHERE o.CUST = ? AND o.CURDATE > 0
            ORDER BY o.CURDATE DESC
        """, cust_id)
        
        for row in cursor.fetchall():
            ord_date = priority_date_to_datetime(row.CURDATE)
            if ord_date and ord_date.year >= 2020:
                ordname = (row.ORDNAME or '').strip()
                if ordname in orders_seen:
                    continue
                orders_seen.add(ordname)
                
                qprice = float(row.QPRICE or 0)  # מחיר לפני מע"מ
                totprice = float(row.TOTPRICE or 0)  # מחיר כולל מע"מ
                disprice = float(row.DISPRICE or 0)  # סכום הנחה
                line_count = int(row.LINE_COUNT or 0)
                
                # חישוב אחוז הנחה נכון: disprice / (qprice + disprice) * 100
                base_price = qprice + disprice
                discount_pct = round((disprice / base_price) * 100, 1) if base_price > 0 else 0
                
                orders_detail.append({
                    'orderNumber': ordname,
                    'quotation': '',
                    'orderDate': format_date(ord_date),
                    'year': ord_date.year,
                    'description': f'{line_count} פריטים',
                    'serialNo': '',
                    'discountPct': discount_pct,
                    'priceAfterDiscount': qprice
                })
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת פירוט הזמנות: {e}")
    
    # שליפת נתוני כיול בנפרד - כולל פילוח לפי שנים וחודשים
    calibration_by_year = defaultdict(lambda: defaultdict(int))  # {partdes: {year: count}}
    calibration_by_month = defaultdict(lambda: defaultdict(int))  # {partdes: {YYYY-MM: count}}
    try:
        cursor.execute("""
            SELECT 
                o.ORDNAME, p.PARTDES, p.PARTNAME, o.CURDATE,
                SUM(oi.QUANT) as TOTAL_QUANT
            FROM ORDERITEMS oi
            JOIN ORDERS o ON oi.ORD = o.ORD
            JOIN PART p ON oi.PART = p.PART
            WHERE o.CUST = ? AND o.CURDATE > 0
            GROUP BY o.ORDNAME, p.PARTDES, p.PARTNAME, o.CURDATE
        """, cust_id)
        
        for row in cursor.fetchall():
            ordname = (row.ORDNAME or '').strip()
            partdes = (row.PARTDES or '').strip()
            partname = (row.PARTNAME or '').strip()
            # Priority stores quantities with 3 decimal places as integers (1000 = 1.0)
            raw_quant = row.TOTAL_QUANT or 0
            quant = int(raw_quant / 1000) if raw_quant >= 1000 else max(1, int(raw_quant))
            ord_date = priority_date_to_datetime(row.CURDATE)
            
            location = get_location_from_part(partname)
            
            if partdes:
                calibration_types[partdes]['total'] += quant
                if location == 'external':
                    calibration_types[partdes]['external'] += quant
                    external_total += quant
                elif location == 'subcontractor':
                    calibration_types[partdes]['subcontractor'] += quant
                    external_total += quant
                else:
                    calibration_types[partdes]['internal'] += quant
                    internal_total += quant
                
                # מגמה לפי שנים (2024-2026 בלבד)
                if ord_date and 2024 <= ord_date.year <= 2026:
                    calibration_by_year[partdes][ord_date.year] += quant
                    # פילוח חודשי (2024-2026)
                    month_key = f"{ord_date.year}-{ord_date.month:02d}"
                    calibration_by_month[partdes][month_key] += quant
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת נתוני כיול: {e}")
    
    # המרת סוגי כיול לרשימה
    colors = ["hsl(215 100% 50%)", "hsl(180 70% 45%)", "hsl(280 60% 60%)", 
              "hsl(40 90% 60%)", "hsl(340 70% 60%)", "hsl(120 50% 50%)", "hsl(0 70% 60%)"]
    
    calibration_types_list = []
    calibration_trends = []  # מגמות לפי מחלקות ושנים
    
    for idx, (name, stats) in enumerate(sorted(calibration_types.items(), key=lambda x: x[1]['total'], reverse=True)):
        calibration_types_list.append({
            'name': name,
            'value': stats['total'],
            'color': colors[idx % len(colors)]
        })
        
        # התפלגות לפי מיקום
        total = stats['total']
        if total > 0:
            calibration_by_location.append({
                'name': name,
                'total': total,
                'internal': stats['internal'],
                'external': stats['external'],
                'internalPct': int((stats['internal'] / total) * 100),
                'externalPct': int((stats['external'] / total) * 100)
            })
        
        # מגמות לפי שנים
        year_data = calibration_by_year.get(name, {})
        y2024 = year_data.get(2024, 0)
        y2025 = year_data.get(2025, 0)
        y2026 = year_data.get(2026, 0)
        
        # חישוב מגמה: השוואה בין שנה אחרונה לקודמת
        if y2025 > 0 or y2026 > 0 or y2024 > 0:
            # מגמה: אם 2025 > 2024 = עלייה, אם פחות = ירידה
            if y2025 > 0 and y2024 > 0:
                trend_pct = round(((y2025 - y2024) / y2024) * 100, 1)
                trend = 'up' if trend_pct > 5 else ('down' if trend_pct < -5 else 'stable')
            elif y2026 > 0 and y2025 > 0:
                trend_pct = round(((y2026 - y2025) / y2025) * 100, 1)
                trend = 'up' if trend_pct > 5 else ('down' if trend_pct < -5 else 'stable')
            else:
                trend_pct = 0
                trend = 'stable'
            
            # הוספת נתונים חודשיים לכל סוג כיול
            month_data = calibration_by_month.get(name, {})
            monthly_list = [
                {'month': k, 'count': v}
                for k, v in sorted(month_data.items())
                if k.startswith('202')  # רק 2024-2026
            ]
            
            calibration_trends.append({
                'name': name[:40],  # קיצור שם ארוך
                'y2024': y2024,
                'y2025': y2025,
                'y2026': y2026,
                'total': y2024 + y2025 + y2026,
                'trend': trend,
                'trendPct': trend_pct,
                'color': colors[idx % len(colors)],
                'monthly': monthly_list[-24:] if monthly_list else []  # 24 חודשים אחרונים
            })
    
    # חישוב אחוז פנים/חוץ כללי - ישמר זמנית, יחושב מחדש אחרי טעינת devices_list
    calibration_location_split = {'internal': 50, 'external': 50}
    
    # ========== שליפת רשימת מכשירים מ-SERNUMBERS + MBA_SERNORD ==========
    # MBA_SERNORD.NEXTCALIB הוא המקור הראשי לתאריך הכיול הבא (2,607 לקוחות)
    # SERNUMBERS.NEXTMAINTDATE משמש כגיבוי
    devices_list = []
    today = datetime.now()
    try:
        cursor.execute("""
            SELECT
                sn.SERNUM,
                sn.NEXTMAINTDATE,
                sn.LASTMAINTDATE,
                p.PARTNAME, p.PARTDES,
                MAX(CASE WHEN so.NEXTCALIB > 0 THEN so.NEXTCALIB ELSE 0 END) AS NEXTCALIB_ORD,
                MAX(CASE WHEN so.LASTMAINTDATE > 0 THEN so.LASTMAINTDATE ELSE 0 END) AS LASTMAINT_ORD
            FROM SERNUMBERS sn
            LEFT JOIN MBA_SERNORD so ON so.SERN = sn.SERN
            LEFT JOIN PART p ON sn.PART = p.PART
            WHERE sn.CUST = ? AND sn.SERNUM IS NOT NULL AND sn.SERNUM != ''
            GROUP BY sn.SERN, sn.SERNUM, p.PARTNAME, p.PARTDES, sn.NEXTMAINTDATE, sn.LASTMAINTDATE
        """, cust_id)
        
        for row in cursor.fetchall():
            serial_no = (row.SERNUM or '').strip()
            device_name = (row.PARTDES or '').strip()
            partname = (row.PARTNAME or '').strip()
            
            # MBA_SERNORD.NEXTCALIB הוא המקור הראשי; NEXTMAINTDATE הוא גיבוי
            next_calib_ord = getattr(row, 'NEXTCALIB_ORD', 0) or 0
            last_maint_ord = getattr(row, 'LASTMAINT_ORD', 0) or 0

            next_maint = priority_date_to_datetime(next_calib_ord) or priority_date_to_datetime(row.NEXTMAINTDATE)
            last_maint = priority_date_to_datetime(last_maint_ord) or priority_date_to_datetime(row.LASTMAINTDATE)
            
            # אם אין תאריך כיול הבא — השתמש בתאריך האחרון + 12 חודשים
            if not next_maint and last_maint:
                next_maint = last_maint + relativedelta(months=12)
            
            if next_maint:
                status = 'expired' if next_maint < today else 'active'
            else:
                status = 'active'
            
            # Determine location from part number suffix (מק"ט)
            device_location = get_location_from_part(partname)
            
            if serial_no:
                devices_list.append({
                    'serialNo': serial_no,
                    'deviceName': device_name,
                    'model': partname,
                    'manufacturer': '',
                    'lastCalDate': format_date(last_maint),
                    'nextCalDate': format_date(next_maint),
                    'calibrationInterval': 12,  # ברירת מחדל
                    'status': status,
                    'location': device_location
                })
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת מכשירים: {e}")
    
    # ========== שליפת תאריכי כיול מ-QCCData.datasheet ==========
    global qccdata_available
    serial_cal_dates = {}
    
    # דילוג אם כבר ידוע שאין גישה ל-QCCData
    if not qccdata_available:
        pass  # לא מנסים להתחבר
    else:
        try:
            # התחברות לבסיס נתונים QCCData
            qcc_driver = _detect_driver()
            qcc_connection_string = (
                f"DRIVER={{{qcc_driver}}};"
                f"SERVER={SQL_CONFIG['server']};"
                f"DATABASE=QCCData;"
                f"UID={SQL_CONFIG['username']};"
                f"PWD={SQL_CONFIG['password']};"
                f"TrustServerCertificate=yes"
            )
            qcc_conn = pyodbc.connect(qcc_connection_string)
            qcc_cursor = qcc_conn.cursor()
            
            # שליפת תאריכי כיול לפי מספר לקוח (hp)
            qcc_cursor.execute("""
                SELECT 
                    [Serial_No],
                    [Cal_Date],
                    [Next_Cal_Date],
                    [Device description]
                FROM [dbo].[datasheet]
                WHERE [Customer_Num] = ?
            """, hp)
            
            for row in qcc_cursor.fetchall():
                serial = (row.Serial_No or '').strip()
                if serial:
                    cal_date = row.Cal_Date
                    next_cal = row.Next_Cal_Date
                    device_desc = (getattr(row, 'Device description', '') or '').strip()
                    
                    serial_cal_dates[serial] = {
                        'lastCalDate': cal_date,
                        'nextCalDate': next_cal,
                        'deviceName': device_desc
                    }
            
            qcc_cursor.close()
            qcc_conn.close()
            
            if serial_cal_dates:
                print(f"  [INFO] נמצאו {len(serial_cal_dates)} תאריכי כיול מ-QCCData")
        except pyodbc.Error as e:
            error_msg = str(e)
            # בדיקה אם מדובר בשגיאת גישה לבסיס נתונים
            if "Cannot open database" in error_msg or "Login failed" in error_msg:
                with qccdata_lock:
                    if qccdata_available:  # הדפסה רק פעם אחת
                        qccdata_available = False
                        print(f"  [WARN] אין גישה ל-QCCData - ממשיך ללא תאריכי כיול מהמעבדה")
            else:
                print(f"  [WARN] שגיאה בשליפה מ-QCCData: {e}")
        except Exception as e:
            print(f"  [WARN] שגיאה בשליפה מ-QCCData: {e}")
    
    # עדכון תאריכי כיול במכשירים מ-QCCData
    updated_count = 0
    for device in devices_list:
        serial = device.get('serialNo', '')
        # הסרת קידומת מספר לקוח אם קיימת (לדוגמה: "1014-123" -> "123")
        serial_clean = serial
        if '-' in serial:
            serial_clean = serial.split('-', 1)[1] if serial.count('-') == 1 else serial
        
        # חיפוש במספר סידורי מלא או מקוצר
        qcc_data = serial_cal_dates.get(serial) or serial_cal_dates.get(serial_clean)
        
        if qcc_data:
            last_cal = qcc_data.get('lastCalDate')
            next_cal = qcc_data.get('nextCalDate')
            
            # עדכון תאריכי כיול
            if last_cal:
                if isinstance(last_cal, datetime):
                    device['lastCalDate'] = format_date(last_cal)
                else:
                    device['lastCalDate'] = last_cal.strftime('%d/%m/%Y') if hasattr(last_cal, 'strftime') else str(last_cal)
            
            if next_cal:
                if isinstance(next_cal, datetime):
                    device['nextCalDate'] = format_date(next_cal)
                    if next_cal < today:
                        device['status'] = 'expired'
                    else:
                        device['status'] = 'active'
                elif hasattr(next_cal, 'strftime'):
                    device['nextCalDate'] = next_cal.strftime('%d/%m/%Y')
                    # עדכון סטטוס
                    if next_cal < today.date() if hasattr(next_cal, 'date') else next_cal < today:
                        device['status'] = 'expired'
                    else:
                        device['status'] = 'active'
            
            # עדכון שם מכשיר אם חסר
            if not device.get('deviceName') and qcc_data.get('deviceName'):
                device['deviceName'] = qcc_data['deviceName']
            
            updated_count += 1
    
    if updated_count > 0:
        print(f"  [INFO] עודכנו {updated_count} מכשירים עם תאריכי כיול מ-QCCData")
    
    # חישוב אחוז פנים/חוץ כללי מרשימת המכשירים
    internal_devices = len([d for d in devices_list if d.get('location') == 'internal'])
    external_devices = len([d for d in devices_list if d.get('location') == 'external'])
    total_devices_loc = internal_devices + external_devices
    if total_devices_loc > 0:
        internal_pct = round((internal_devices / total_devices_loc) * 100)
        external_pct = 100 - internal_pct
        calibration_location_split = {
            'internal': internal_pct,
            'external': external_pct
        }
    
    # שליפת מיקום כיול (פנים/חוץ) מההזמנות לפי מספר סידורי
    # דילוג על שאילתה זו אם טבלת SERIALS לא קיימת - נשתמש בברירת מחדל
    serial_locations = {}
    
    # חישוב התפלגות לפי מחלקה מרשימת המכשירים
    dept_stats = {}
    for d in devices_list:
        device_name = d.get('deviceName', '') or ''
        serial_no = d.get('serialNo', '') or ''
        # שימוש במיקום מההזמנות, אם קיים
        location = serial_locations.get(serial_no, d.get('location', 'internal'))
        
        # זיהוי מחלקה לפי שם המכשיר
        n = device_name.lower()
        if 'טמפ' in n or 'temp' in n or 'חום' in n or 'תנור' in n:
            dept = 'טמפרטורה'
        elif 'אלקטרו' in n or 'elec' in n or 'חשמל' in n:
            dept = 'אלקטרוניקה'
        elif 'לחץ' in n or 'press' in n or 'מנומטר' in n:
            dept = 'לחץ'
        elif 'מימד' in n or 'dimen' in n or 'אורך' in n or 'מד ' in n or 'זוי' in n or 'angle' in n:
            dept = 'אורך וזווית'
        elif 'משקל' in n or 'mass' in n or 'כוח' in n:
            dept = 'משקל/כוח'
        elif 'זרימה' in n or 'flow' in n:
            dept = 'זרימה'
        else:
            dept = 'אחר'
        
        if dept not in dept_stats:
            dept_stats[dept] = {'internal': 0, 'external': 0}
        
        if location == 'external':
            dept_stats[dept]['external'] += 1
        else:
            dept_stats[dept]['internal'] += 1
    
    # בניית calibration_by_location מהנתונים החדשים
    calibration_by_location = []
    for dept, stats in sorted(dept_stats.items(), key=lambda x: x[1]['internal'] + x[1]['external'], reverse=True):
        total = stats['internal'] + stats['external']
        if total > 0:
            calibration_by_location.append({
                'name': dept,
                'total': total,
                'internal': stats['internal'],
                'external': stats['external'],
                'internalPct': round((stats['internal'] / total) * 100),
                'externalPct': round((stats['external'] / total) * 100)
            })
    
    cursor.close()
    
    # ========== שליפת תעודות החזרה לכל השנים ==========
    # חשוב: לפני סגירת החיבור!
    return_docs_by_year = {2024: [], 2025: [], 2026: []}
    try:
        ret_cursor = conn.cursor()
        ret_cursor.execute("""
            SELECT 
                d.DOCNO,
                DATEADD(n, d.CURDATE, '01/01/1988') as OpenDate,
                d.TOTPRICE - d.VAT as CostAfterDiscount
            FROM DOCUMENTS d
            WHERE d.CUST = ? 
              AND d.TYPE = 'N'
              AND YEAR(DATEADD(n, d.CURDATE, '01/01/1988')) >= 2024
            ORDER BY d.CURDATE DESC
        """, cust_id)
        
        for row in ret_cursor.fetchall():
            open_date = row.OpenDate
            if open_date:
                year = open_date.year
                if year in return_docs_by_year:
                    return_docs_by_year[year].append({
                        'value': float(row.CostAfterDiscount or 0)
                    })
        ret_cursor.close()
        # הדפסת סיכום תעודות החזרה לפי שנה
        for y, docs in return_docs_by_year.items():
            if docs:
                total_val = sum(d['value'] for d in docs)
                print(f"  [INFO] תעודות החזרה {y}: {len(docs)} (₪{total_val:,.0f})")
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת תעודות החזרה לפי שנה: {e}")
    
    # ========== חישוב סיכום פיננסי ==========
    # הכנסות = רק מחשבוניות (VATPRICE - אחרי הנחה)
    # הזמנות = נתון נפרד, לא קשור להכנסות
    financials = []
    for year in [2024, 2025, 2026]:
        year_invoices = [i for i in invoices if i['year'] == year]
        year_orders = [o for o in orders if o['year'] == year]
        year_quotes = [q for q in quotes if q['year'] == year]
        year_returns = return_docs_by_year.get(year, [])
        
        # הכנסות = רק מחשבוניות (אחרי הנחה, לפני מע"מ)
        invoices_net = round(sum(i['netPrice'] for i in year_invoices), 2)
        invoices_discounts = round(sum(i['discount'] for i in year_invoices), 2)
        
        # סיכום הזמנות - נתון נפרד
        orders_net = round(sum(o['netPrice'] for o in year_orders), 2)
        orders_discounts = round(sum(o['discountAmount'] for o in year_orders), 2)
        
        # סיכום הצעות מחיר
        quotes_net = round(sum(q['netPrice'] for q in year_quotes), 2)
        quotes_discounts = round(sum(q['discountAmount'] for q in year_quotes), 2)
        
        # סיכום תעודות החזרה
        returns_revenue = round(sum(r['value'] for r in year_returns), 2)
        returns_count = len(year_returns)
        
        # יחס המרה: הצעות מחיר לחשבוניות
        # לפי כמות הזמנות (לאחור תאימות)
        conversion_rate_count = round((len(year_invoices) / len(year_orders) * 100), 1) if len(year_orders) > 0 else 0
        # לפי סכום הזמנות (לאחור תאימות)
        conversion_rate_amount = round((invoices_net / orders_net * 100), 1) if orders_net > 0 else 0
        # יחס המרה הצעות לחשבוניות (חדש)
        quotes_conversion_count = round((len(year_invoices) / len(year_quotes) * 100), 1) if len(year_quotes) > 0 else 0
        quotes_conversion_amount = round((invoices_net / quotes_net * 100), 1) if quotes_net > 0 else 0
        
        financials.append({
            'year': year,
            'invoicesCount': len(year_invoices),
            'invoicesRevenue': invoices_net,
            'invoicesDiscounts': invoices_discounts,
            'ordersCount': len(year_orders),
            'ordersRevenue': orders_net,
            'ordersDiscounts': orders_discounts,
            'revenue': invoices_net,  # הכנסות = רק חשבוניות
            'discountsTotal': invoices_discounts,
            'quotesCount': len(year_quotes),
            'quotesRevenue': quotes_net,
            'quotesDiscounts': quotes_discounts,
            'returnsCount': returns_count,  # כמות תעודות החזרה
            'returnsRevenue': returns_revenue,  # סכום תעודות החזרה
            'conversionRate': conversion_rate_count,  # יחס המרה לפי כמות (הזמנות)
            'conversionRateAmount': conversion_rate_amount,  # יחס המרה לפי סכום (הזמנות)
            'quotesConversionCount': quotes_conversion_count,  # יחס המרה הצעות לחשבוניות
            'quotesConversionAmount': quotes_conversion_amount  # יחס המרה סכום הצעות לחשבוניות
        })
    
    # ========== חישוב ציון לקוח ==========
    # הגדרות נטענות מ-scoring_config (מה-API או ברירת מחדל)
    weights = scoring_config.get('weights', DEFAULT_SCORING_CONFIG['weights'])
    thresholds = scoring_config.get('thresholds', DEFAULT_SCORING_CONFIG['thresholds'])
    max_values = scoring_config.get('maxValues', DEFAULT_SCORING_CONFIG['maxValues'])
    
    # 1. ותק - מספר חודשים מאז הרכישה הראשונה
    all_dates = []
    for inv in invoices:
        if inv.get('date'):
            try:
                d = datetime.strptime(inv['date'], '%d/%m/%Y')
                all_dates.append(d)
            except:
                pass
    for ord in orders:
        if ord.get('date'):
            try:
                d = datetime.strptime(ord['date'], '%d/%m/%Y')
                all_dates.append(d)
            except:
                pass
    
    tenure_months = 0
    first_purchase_date = None
    if all_dates:
        first_purchase_date = min(all_dates)
        tenure_months = (today.year - first_purchase_date.year) * 12 + (today.month - first_purchase_date.month)
    
    # 2. סכום רכישות - סה"כ הכנסות ב-24 חודשים אחרונים
    cutoff_date = today - timedelta(days=730)  # 24 חודשים
    recent_revenue = sum(
        inv['netPrice'] for inv in invoices 
        if inv.get('date') and datetime.strptime(inv['date'], '%d/%m/%Y') > cutoff_date
    )
    
    # 3. תדירות - כמה חודשים עם פעילות מתוך 24 אחרונים (חשבוניות + הזמנות)
    active_months = set()
    for inv in invoices:
        if inv.get('date'):
            try:
                d = datetime.strptime(inv['date'], '%d/%m/%Y')
                if d > cutoff_date:
                    active_months.add(f"{d.year}-{d.month:02d}")
            except:
                pass
    for ord in orders:
        if ord.get('date'):
            try:
                d = datetime.strptime(ord['date'], '%d/%m/%Y')
                if d > cutoff_date:
                    active_months.add(f"{d.year}-{d.month:02d}")
            except:
                pass
    frequency_rate = len(active_months) / 24.0  # 0-1
    
    # חישוב ציונים מנורמלים (0-100) לפי הגדרות מותאמות
    max_tenure = max_values.get('tenureMonths', 60)
    max_revenue = max_values.get('revenueAmount', 500000)
    
    tenure_score = min(100, (tenure_months / max_tenure) * 100) if max_tenure > 0 else 0
    revenue_score = min(100, (recent_revenue / max_revenue) * 100) if max_revenue > 0 else 0
    frequency_score = frequency_rate * 100
    
    # ציון משוקלל לפי משקולות מותאמות
    w_tenure = weights.get('tenure', 25) / 100.0
    w_revenue = weights.get('revenue', 40) / 100.0
    w_frequency = weights.get('frequency', 35) / 100.0
    
    weighted_score = round(
        (tenure_score * w_tenure) + 
        (revenue_score * w_revenue) + 
        (frequency_score * w_frequency)
    )
    
    # דירוג אותיות לפי ספים מותאמים
    t_a = thresholds.get('A', 85)
    t_b = thresholds.get('B', 70)
    t_c = thresholds.get('C', 55)
    t_d = thresholds.get('D', 40)
    
    if weighted_score >= t_a:
        grade = 'A'
    elif weighted_score >= t_b:
        grade = 'B'
    elif weighted_score >= t_c:
        grade = 'C'
    elif weighted_score >= t_d:
        grade = 'D'
    else:
        grade = 'E'
    
    customer_score = {
        'score': weighted_score,
        'grade': grade,
        'breakdown': {
            'tenure': round(tenure_score, 1),
            'revenue': round(revenue_score, 1),
            'frequency': round(frequency_score, 1)
        },
        'metrics': {
            'tenureMonths': tenure_months,
            'firstPurchase': format_date(first_purchase_date) if first_purchase_date else '',
            'recentRevenue': round(recent_revenue, 2),
            'activeMonths': len(active_months)
        }
    }
    
    # ========== שליפת תעודות החזרה (כל התעודות מ-2024) ==========
    return_documents = []
    pending_forecast = {'totalDocuments': 0, 'totalValue': 0}
    try:
        # שליפה ראשית: השאילתה הפשוטה (ללא JOINs) עובדת תמיד — זהה לשאילתת financials
        _sql_main = """
            SELECT 
                d.DOCNO,
                DATEADD(n, d.CURDATE, '01/01/1988') as OpenDate,
                d.TOTPRICE - d.VAT as CostAfterDiscount
            FROM DOCUMENTS d
            WHERE d.CUST = ? 
              AND d.TYPE = 'N'
              AND DATEADD(n, d.CURDATE, '01/01/1988') >= '2024-01-01'
              AND DATEADD(n, d.CURDATE, '01/01/1988') <= EOMONTH(GETDATE())
            ORDER BY d.CURDATE DESC
        """
        # שליפת סטטוס + LinesCount כשאילתה משנית (על cursor נפרד)
        _sql_with_stats = """
            SELECT 
                d.DOCNO,
                ds.STATDES,
                (SELECT COUNT(*) FROM DLINE dl WHERE dl.DOC = d.DOC) AS LinesCount
            FROM DOCUMENTS d
            LEFT JOIN DOCUMENTSA da ON d.DOC = da.DOC
            LEFT JOIN DOCSTATS ds ON da.ASSEMBLYSTATUS = ds.DOCSTAT
            WHERE d.CUST = ? 
              AND d.TYPE = 'N'
              AND DATEADD(n, d.CURDATE, '01/01/1988') >= '2024-01-01'
              AND DATEADD(n, d.CURDATE, '01/01/1988') <= EOMONTH(GETDATE())
        """
        
        doc_cursor = conn.cursor()
        doc_cursor.execute(_sql_main, cust_id)
        
        main_rows = {}
        for row in doc_cursor.fetchall():
            doc_no = (row.DOCNO or '').strip()
            open_date = row.OpenDate
            cost = round(float(row.CostAfterDiscount or 0), 2)
            doc_date = open_date.strftime('%d/%m/%Y') if open_date else ''
            main_rows[doc_no] = {
                'documentNumber': doc_no,
                'openDate': doc_date,
                'value': cost,
                'status': '',
                'linesCount': 0
            }
        doc_cursor.close()
        
        # נסיון לשליפת סטטוסים ו-LinesCount (אופציונלי — cursor נפרד)
        if main_rows:
            try:
                stats_cursor = conn.cursor()
                stats_cursor.execute(_sql_with_stats, cust_id)
                for row in stats_cursor.fetchall():
                    doc_no = (row.DOCNO or '').strip()
                    if doc_no in main_rows:
                        status = (row.STATDES or '').strip()
                        # דילוג על טיוטות בלבד
                        if 'טיוטא' in status:
                            del main_rows[doc_no]
                            continue
                        main_rows[doc_no]['status'] = status
                        main_rows[doc_no]['linesCount'] = int(getattr(row, 'LinesCount', 0) or 0)
                stats_cursor.close()
            except Exception:
                pass  # הסטטוסים לא קריטיים — השאילתה הראשית כבר שמרה הכל
        
        return_documents = list(main_rows.values())
        
        pending_forecast = {
            'totalDocuments': len(return_documents),
            'totalValue': round(sum(d['value'] for d in return_documents), 2)
        }
        
        print(f"\n  [SUMMARY] תעודות החזרה: {len(return_documents)} (₪{pending_forecast['totalValue']:,.0f})")
    except Exception as e:
        print(f"  [WARN] שגיאה בשליפת תעודות החזרה: {e}")
    
    # סגירת החיבור אחרי כל השאילתות
    if own_connection:
        conn.close()
    
    # ========== יצירת התראות כיול ==========
    alerts = []
    expired_devices = [d for d in devices_list if d['status'] == 'expired']
    
    # התראה על כל מכשיר שפג תוקף הכיול שלו
    for d in expired_devices[:10]:  # 10 ראשונים
        alerts.append({
            'type': 'error',
            'title': f'{d["deviceName"][:40]} - כיול באיחור',
            'serialNo': d['serialNo'],
            'lastCalDate': d.get('lastCalDate', ''),
            'nextCalDate': d.get('nextCalDate', ''),
            'location': d.get('location', 'internal'),
            'message': f'פג תוקף הכיול'
        })
    
    # התראה על מכשירים שתוקף הכיול שלהם יפוג בקרוב (30 יום)
    soon_to_expire = []
    for d in devices_list:
        if d['status'] == 'active' and d.get('nextCalDate'):
            try:
                next_date = datetime.strptime(d['nextCalDate'], '%d/%m/%Y')
                days_until = (next_date - today).days
                if 0 < days_until <= 30:
                    soon_to_expire.append({'device': d, 'days': days_until})
            except:
                pass
    
    # מיון לפי ימים שנותרו והוספה להתראות
    soon_to_expire.sort(key=lambda x: x['days'])
    for item in soon_to_expire[:10]:  # 10 ראשונים
        d = item['device']
        alerts.append({
            'type': 'warning',
            'title': f'{d["deviceName"][:40]} - {item["days"]} ימים',
            'serialNo': d['serialNo'],
            'lastCalDate': d.get('lastCalDate', ''),
            'nextCalDate': d.get('nextCalDate', ''),
            'location': d.get('location', 'internal'),
            'message': f'נותרו {item["days"]} ימים לכיול'
        })
    
    # ========== בניית אובייקט הנתונים המלא ==========
    customer_data = {
        'id': customer['id'],
        'companyName': customer['companyName'],
        'hp': customer['hp'],
        'address': customer['address'],
        'phone': customer['phone'],
        'shippingMethod': customer.get('shippingMethod', ''),  # שיטת שינוע מ-SHIPTYPES
        'agentName': agent_name,
        'contacts': contacts[:20],
        'complaints': complaints[:50],  # תלונות מ-MED_COMPLAINT
        'financials': financials,
        'invoices': invoices[:100],
        'orders': orders[:100],
        'quotes': quotes[:100],
        'ordersDetail': orders_detail[:100],
        'totalOrdersCount': len(orders_detail),  # סה"כ הזמנות ייחודיות
        'calibrationTypes': calibration_types_list[:50],
        'calibrationTrends': sorted(calibration_trends, key=lambda x: x['total'], reverse=True)[:20],
        'calibrationLocationSplit': calibration_location_split,
        'calibrationByLocation': calibration_by_location[:15],
        'deviceInventory': {
            'totalDevices': len(devices_list),
            'activeDevices': len([d for d in devices_list if d['status'] == 'active']),
            'outForCalibration': len([d for d in devices_list if d['status'] == 'expired'])
        },
        'monthlyCalibrationDistribution': [],
        'monthlyRevenue': [
            {'month': k, 'revenue': round(v['revenue'], 2), 'count': v['count']}
            for k, v in sorted(monthly_revenue.items(), reverse=True)
        ][:24],  # 24 חודשים אחרונים
        'devicesList': devices_list,  # כל המכשירים - ללא הגבלה
        'recentCalibrations': [],
        'alerts': alerts,  # התראות כיול אוטומטיות
        'meetingNotes': [],
        'customerScore': customer_score,
        'returnDocuments': return_documents,  # תעודות החזרה - היסטוריה מלאה מ-2024
        'pendingForecast': pending_forecast,  # סיכום צפי
        'recentReturns': build_recent_returns(return_documents)
    }
    
    return customer_data

# ========== שליחת נתונים לשרת ==========
def sync_to_replit(customer_data: Dict[str, Any]) -> tuple:
    """שליחת נתוני לקוח לשרת Replit. מחזיר (הצלחה, הודעת שגיאה)"""
    import time as _time
    max_retries = 3
    retry_delays = [2, 5, 10]  # המתנה בשניות בין ניסיונות
    for attempt in range(max_retries):
        try:
            response = requests.post(
                REPLIT_API_URL,
                json=customer_data,
                headers={'Content-Type': 'application/json'},
                timeout=45
            )
            if response.status_code == 200:
                return (True, None)
            elif response.status_code in (503, 429, 502) and attempt < max_retries - 1:
                _time.sleep(retry_delays[attempt])
                continue
            else:
                return (False, f"HTTP {response.status_code}")
        except requests.exceptions.Timeout:
            if attempt < max_retries - 1:
                _time.sleep(retry_delays[attempt])
                continue
            return (False, "Timeout")
        except requests.exceptions.ConnectionError as e:
            if attempt < max_retries - 1:
                _time.sleep(retry_delays[attempt])
                continue
            return (False, f"Connection error to {REPLIT_API_URL[:40]}")
        except Exception as e:
            return (False, str(e)[:30])
    return (False, "Max retries exceeded")

# ========== שליפת כל הלקוחות ==========
def fetch_all_customers() -> List[int]:
    """שליפת רשימת כל הלקוחות מטבלת CUSTOMERS"""
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT DISTINCT CUST FROM CUSTOMERS WHERE CUST > 0
        ORDER BY CUST
    """)
    
    customers = [row[0] for row in cursor.fetchall() if row[0]]
    
    cursor.close()
    conn.close()
    
    return customers

# ========== עיבוד לקוח בודד ==========
lock = threading.Lock()
success_count = 0
fail_count = 0
processed_count = 0

def process_customer(cust_id: int, total: int, shared_conn=None, scoring_config: dict = None) -> bool:
    """עיבוד וסנכרון לקוח בודד"""
    global success_count, fail_count, processed_count
    
    try:
        customer_data = fetch_customer_data(cust_id, shared_conn, scoring_config)
        success, error_msg = sync_to_replit(customer_data)
        
        with lock:
            processed_count += 1
            if success:
                success_count += 1
                inv_count = len(customer_data.get('invoices', []))
                ord_count = len(customer_data.get('ordersDetail', []))
                cal_count = len(customer_data.get('calibrationTypes', []))
                print(f"[{processed_count}/{total}] ✓ {customer_data['companyName'][:25]} ({inv_count} חשב', {ord_count} פריטים, {cal_count} סוגים)")
            else:
                fail_count += 1
                print(f"[{processed_count}/{total}] ✗ לקוח {cust_id} - {error_msg}")
        
        return success
        
    except ValueError as e:
        # לקוחות עם שם לא תקין - דילוג שקט
        with lock:
            processed_count += 1
        return False
        
    except Exception as e:
        with lock:
            processed_count += 1
            fail_count += 1
            print(f"[{processed_count}/{total}] ✗ לקוח {cust_id} - {str(e)[:50]}")
        return False

# ========== Main ==========
def search_customer(search_term: str):
    """חיפוש לקוח לפי שם"""
    print(f"\n{'='*60}")
    print(f"  Priority ERP Sync v{VERSION} - Customer Search")
    print(f"  Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
    print(f"  Search: {search_term}")
    print(f"{'='*60}\n")
    
    try:
        conn = get_connection()
        cursor = conn.cursor()
        
        # חיפוש לקוחות
        cursor.execute("""
            SELECT CUST, CUSTNAME, CUSTDES, PHONE
            FROM CUSTOMERS
            WHERE CUSTNAME LIKE ? OR CUSTDES LIKE ?
            ORDER BY CUST
        """, f'%{search_term}%', f'%{search_term}%')
        
        results = cursor.fetchall()
        
        if not results:
            print(f"[INFO] לא נמצאו לקוחות עם '{search_term}'")
        else:
            print(f"[INFO] נמצאו {len(results)} לקוחות:\n")
            print(f"{'CUST':<10} {'CUSTNAME':<20} {'CUSTDES':<30}")
            print("-" * 60)
            for row in results:
                cust = str(row.CUST)
                custname = (row.CUSTNAME or '').strip()[:18]
                custdes = (row.CUSTDES or '').strip()[:28]
                print(f"{cust:<10} {custname:<20} {custdes:<30}")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"\n[ERROR] שגיאה: {str(e)}")

def sync_single_customer(cust_id: int):
    """סנכרון לקוח יחיד"""
    global success_count, fail_count, processed_count
    success_count = 0
    fail_count = 0
    processed_count = 0
    
    print(f"\n{'='*60}")
    print(f"  Priority ERP Sync v{VERSION} - Single Customer")
    print(f"  Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
    print(f"  Customer: {cust_id}")
    print(f"{'='*60}\n")
    
    # טעינת הגדרות ציון מה-API
    scoring_config = fetch_scoring_config(REPLIT_API_URL)
    
    try:
        print(f"[INFO] שולף נתוני לקוח {cust_id}...")
        customer_data = fetch_customer_data(cust_id, scoring_config=scoring_config)
        print(f"[INFO] נמצא: {customer_data['companyName']}")
        
        inv_count = len(customer_data.get('invoices', []))
        ord_count = len(customer_data.get('ordersDetail', []))
        cal_count = len(customer_data.get('calibrationTypes', []))
        loc_count = len(customer_data.get('calibrationByLocation', []))
        dev_count = len(customer_data.get('devicesList', []))
        
        print(f"[DATA] חשבוניות: {inv_count}, פריטי הזמנה: {ord_count}")
        print(f"[DATA] סוגי כיול: {cal_count}, לפי מיקום: {loc_count}")
        print(f"[DATA] מכשירים: {dev_count}")
        
        print(f"\n[SEND] שולח ל-Replit...")
        success, error_msg = sync_to_replit(customer_data)
        
        if success:
            print(f"\n[OK] ✓ לקוח {cust_id} סונכרן בהצלחה!")
        else:
            print(f"\n[ERROR] ✗ שליחה ל-Replit נכשלה: {error_msg}")
            
    except Exception as e:
        print(f"\n[ERROR] ✗ שגיאה: {str(e)}")

# ========== Ship API (UPS Israel) Integration ==========

def get_ship_config():
    try:
        from config import SHIP_API_CONFIG
        return SHIP_API_CONFIG
    except ImportError:
        import os
        return {
            'base_url': os.environ.get('SHIP_API_URL', 'https://newbetaapi.ship.co.il'),
            'email': os.environ.get('SHIP_API_EMAIL', ''),
            'password': os.environ.get('SHIP_API_PASSWORD', ''),
            'customer_id': os.environ.get('SHIP_CUSTOMER_ID', '699226')
        }

def ship_api_authenticate(config):
    # Option 1: use a pre-set token from config (copied from browser localStorage)
    # Keys to check: 'auth_token' (localStorage key), 'token', 'access_token'
    static_token = config.get('auth_token') or config.get('token') or config.get('access_token')
    if static_token:
        print(f"[SHIP] ✓ משתמש ב-token מ-config (מ-DevTools)")
        return static_token

    try:
        import requests as _req
    except ImportError:
        print("[SHIP] מתקין requests...")
        import subprocess, sys
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'requests', '-q'])
        import requests as _req

    base = config['base_url']
    app_base = 'https://newbetaapp.ship.co.il'

    session = _req.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'he-IL,he;q=0.9,en-US;q=0.8,en;q=0.7',
    })

    # Step 1: visit the web app to get WAF session cookies
    try:
        print("[SHIP] מאתחל סשן עם cookies מהאתר...")
        session.get(app_base, timeout=15, allow_redirects=True)
        session.get(f"{app_base}/#/login", timeout=15, allow_redirects=True)
    except Exception:
        pass

    # Option 2: use manually-provided cookies from browser (bypasses WAF)
    manual_cookies = config.get('cookies')
    if manual_cookies:
        print("[SHIP] משתמש ב-cookies מהדפדפן...")
        for pair in manual_cookies.split(';'):
            pair = pair.strip()
            if '=' in pair:
                k, v = pair.split('=', 1)
                session.cookies.set(k.strip(), v.strip(), domain='newbetaapi.ship.co.il')
                session.cookies.set(k.strip(), v.strip(), domain='newbetaapp.ship.co.il')

    # Step 2: Try API login
    for payload in [
        {'email': config['email'], 'password': config['password'], 'customerId': config['customer_id']},
        {'email': config['email'], 'password': config['password']},
    ]:
        try:
            resp = session.post(f"{base}/api/v1/users/login", json=payload, timeout=60,
                                headers={'Origin': app_base, 'Referer': f'{app_base}/'})
            if resp.status_code == 200:
                result = resp.json()
                token = result.get('access_token') or result.get('token') or result.get('accessToken')
                if token:
                    print(f"[SHIP] ✓ התחברות הצליחה!")
                    return token
        except Exception:
            pass

    # WAF is blocking automated requests.
    # Tell the user how to get the token manually from the browser.
    print("\n[SHIP] ✗ ה-WAF של ship.co.il חוסם בקשות אוטומטיות.")
    print("[SHIP]   כדי לסנכרן נתוני Ship, בצע את השלבים הבאים:")
    print("[SHIP]   1. פתח Chrome ועבור ל-https://newbetaapp.ship.co.il")
    print("[SHIP]   2. התחבר עם המייל והסיסמה שלך")
    print("[SHIP]   3. לחץ F12 → Application → Local Storage → https://newbetaapp.ship.co.il")
    print("[SHIP]   4. חפש מפתח בשם 'auth_token' - העתק את הערך")
    print("[SHIP]   5. הוסף לקובץ config.py:")
    print("[SHIP]      SHIP_API_CONFIG = {")
    print("[SHIP]        ...  # הגדרות הקיימות")
    print("[SHIP]        'auth_token': 'הדבק-כאן-את-הערך'")
    print("[SHIP]      }")
    print("[SHIP]   6. הרץ שוב: py sync-customer-data.py --ship")
    print()
    return None

def ship_api_request(config, token, method, path, params=None):
    import urllib.request
    import urllib.parse
    import urllib.error
    
    url = f"{config['base_url']}{path}"
    if params:
        url += '?' + urllib.parse.urlencode(params)
    
    req = urllib.request.Request(url, method=method, headers={
        'Authorization': f'Bearer {token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    })
    
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read().decode('utf-8')
            return resp.status, json.loads(data) if data else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        return e.code, body
    except Exception as e:
        return 0, str(e)

def ship_api_discover(config, token):
    import urllib.parse
    print(f"\n[SHIP] מגלה endpoints זמינים...")
    
    endpoints_to_try = [
        ('GET', '/api/v1/shipments', None),
        ('GET', '/api/v1/shipments/list', None),
        ('GET', '/api/v1/shipment', None),
        ('GET', '/api/v1/Shipment/List', None),
        ('GET', '/api/v1/Shipment/History', None),
        ('GET', '/api/v1/reports', None),
        ('GET', '/api/v1/reports/shipments', None),
        ('GET', '/api/v1/billing', None),
        ('GET', '/api/v1/costs', None),
        ('GET', '/api/v1/tracking', None),
        ('GET', '/api/v1/orders', None),
        ('GET', '/api/v1/account', None),
        ('GET', '/api/v1/customer', None),
        ('GET', '/api/v1/customer/shipments', None),
        ('GET', '/api/Shipments', None),
        ('GET', '/api/Shipment', None),
        ('GET', '/api/Reports', None),
        ('GET', '/api/Tracking', None),
        ('GET', '/api/Orders', None),
        ('GET', '/api/Account', None),
        ('GET', '/api/shipments', {'fromDate': '2025-01-01', 'toDate': '2025-12-31'}),
        ('GET', '/api/v1/shipments', {'fromDate': '2025-01-01', 'toDate': '2025-12-31'}),
        ('GET', f'/api/v1/customers/{config["customer_id"]}/shipments', None),
        ('GET', '/api/v1/Shipment/GetShipments', None),
        ('GET', '/api/v1/Shipment/GetList', None),
        ('GET', '/api/GetShipments', None),
        ('GET', '/api/Shipment/GetShipments', None),
    ]
    
    found_endpoints = []
    
    for method, path, params in endpoints_to_try:
        status, response = ship_api_request(config, token, method, path, params)
        status_icon = '✓' if 200 <= status < 300 else '→' if status in [301, 302, 307, 308] else '✗'
        response_preview = str(response)[:120] if response else ''
        print(f"  {status_icon} [{status}] {method} {path} {f'?{urllib.parse.urlencode(params)}' if params else ''}")
        if response_preview and status != 404:
            print(f"       {response_preview}")
        
        if 200 <= status < 300:
            found_endpoints.append((method, path, params, response))
    
    if found_endpoints:
        print(f"\n[SHIP] ✓ נמצאו {len(found_endpoints)} endpoints עובדים:")
        for method, path, params, resp in found_endpoints:
            print(f"  - {method} {path}")
            if isinstance(resp, dict):
                print(f"    Keys: {list(resp.keys())[:10]}")
            elif isinstance(resp, list):
                print(f"    Items: {len(resp)} רשומות")
                if resp:
                    print(f"    Sample keys: {list(resp[0].keys()) if isinstance(resp[0], dict) else 'N/A'}")
    else:
        print(f"\n[SHIP] ✗ לא נמצאו endpoints עובדים")
        print(f"       ייתכן שצריך endpoints שונים - בדוק עם Ship API docs")
    
    return found_endpoints

def ship_api_fetch_shipments(config, token, from_date=None, to_date=None):
    if not from_date:
        from_date = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')
    if not to_date:
        to_date = datetime.now().strftime('%Y-%m-%d')
    
    print(f"[SHIP] שולף משלוחים מ-{from_date} עד {to_date}...")
    
    cid = config.get('customer_id', '699226')
    # Customer-specific endpoints first (most likely to work), then generic fallbacks
    possible_endpoints = [
        (f'/api/v1/customers/{cid}/shipments', {'fromDate': from_date, 'toDate': to_date}),
        (f'/api/v1/customers/{cid}/shipments', {'from': from_date, 'to': to_date}),
        (f'/api/v1/customers/{cid}/shipments', {'startDate': from_date, 'endDate': to_date}),
        (f'/api/v1/customers/{cid}/shipments', {}),
        ('/api/v1/Shipment/History', {'fromDate': from_date, 'toDate': to_date}),
        ('/api/v1/shipments', {'fromDate': from_date, 'toDate': to_date}),
        ('/api/v1/Shipment/List', {'fromDate': from_date, 'toDate': to_date}),
        ('/api/v1/Shipment/GetShipments', {'fromDate': from_date, 'toDate': to_date}),
        ('/api/Shipments', {'fromDate': from_date, 'toDate': to_date}),
        ('/api/shipments', {'from': from_date, 'to': to_date}),
        ('/api/v1/shipments', {'from': from_date, 'to': to_date}),
        ('/api/v1/shipments', {'startDate': from_date, 'endDate': to_date}),
    ]
    
    for path, base_params in possible_endpoints:
        params_str = '&'.join(f"{k}={v}" for k, v in base_params.items()) if base_params else '(ללא פרמטרים)'
        print(f"[SHIP]   מנסה: {path} [{params_str}]")
        status, response = ship_api_request(config, token, 'GET', path, base_params)
        print(f"[SHIP]   → HTTP {status}")
        if 200 <= status < 300 and response:
            if isinstance(response, list):
                print(f"[SHIP] ✓ נמצאו {len(response)} משלוחים ב-{path}")
                return response
            elif isinstance(response, dict):
                list_key = None
                for key in ['data', 'shipments', 'Shipments', 'items', 'Items', 'results', 'Results', 'list', 'List']:
                    if key in response and isinstance(response[key], list):
                        list_key = key
                        break
                
                if list_key:
                    first_page = response[list_key]
                    total = response.get('Total') or response.get('total') or response.get('TotalCount') or 0
                    page_size = len(first_page)
                    print(f"[SHIP] ✓ נמצאו {page_size} משלוחים (מתוך {total} סה\"כ) ב-{path} -> {list_key}")
                    
                    # Paginate if there are more results
                    all_shipments = list(first_page)
                    if total > page_size and page_size > 0:
                        page = 2
                        page_param_names = ['page', 'Page', 'pageNumber', 'PageNumber', 'offset', 'skip']
                        size_param_names = ['pageSize', 'PageSize', 'limit', 'Limit', 'take', 'Take']
                        
                        while len(all_shipments) < total:
                            paged_params = dict(base_params)
                            paged_params['page'] = page
                            paged_params['pageSize'] = page_size
                            
                            pg_status, pg_response = ship_api_request(config, token, 'GET', path, paged_params)
                            if pg_status != 200 or not pg_response:
                                break
                            
                            if isinstance(pg_response, dict) and list_key in pg_response:
                                page_items = pg_response[list_key]
                            elif isinstance(pg_response, list):
                                page_items = pg_response
                            else:
                                break
                            
                            if not page_items:
                                break
                            
                            all_shipments.extend(page_items)
                            print(f"[SHIP]   עמוד {page}: {len(page_items)} משלוחים (סה\"כ: {len(all_shipments)})")
                            page += 1
                            
                            if len(all_shipments) >= total:
                                break
                    
                    print(f"[SHIP] ✓ סה\"כ {len(all_shipments)} משלוחים")
                    return all_shipments
                
                print(f"[SHIP] ✓ נמצא מידע ב-{path}: {list(response.keys())}")
                return response
    
    print(f"[SHIP] ✗ לא הצלחתי למצוא endpoint לשליפת משלוחים")
    return None

def ship_api_send_to_replit(shipments, replit_base_url):
    if not shipments:
        print(f"[SHIP] אין נתונים לשלוח")
        return
    
    sync_url = replit_base_url.replace('/api/sync/customer-data', '/api/sync/ship-data')
    
    print(f"[SHIP] שולח {len(shipments) if isinstance(shipments, list) else 1} רשומות ל-Replit...")
    
    try:
        payload = {
            'shipments': shipments if isinstance(shipments, list) else [shipments],
            'syncedAt': datetime.now().isoformat(),
            'source': 'ship_api',
            'clearFirst': True
        }
        
        resp = requests.post(sync_url, json=payload, timeout=30)
        if resp.status_code == 200:
            result = resp.json()
            print(f"[SHIP] ✓ נשלחו בהצלחה: {result}")
        else:
            print(f"[SHIP] ✗ שגיאה בשליחה: {resp.status_code} - {resp.text[:200]}")
    except Exception as e:
        print(f"[SHIP] ✗ שגיאת שליחה: {str(e)}")

def run_department_sync(years=None):
    """סנכרון נתוני ביצוע מחלקות לפי שנה וסוכן"""
    if years is None:
        years = [2024, 2025, 2026]
    
    years_sql = ','.join(str(y) for y in years)
    base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    dept_url = f"{base_url}/api/sync/department-stats"
    
    print(f"\n{'='*60}")
    print(f"  ביצוע מחלקות - סנכרון שנים {years_sql}")
    print(f"  → {dept_url}")
    print(f"{'='*60}\n")
    
    # NOTE: Revenue is calculated WITHOUT the SERNTRANS/MBA_SERNTRANSCALL joins
    # to avoid fan-out (one invoice item × multiple serial numbers = inflated revenue).
    # Call count uses a separate subquery with those joins so counts stay correct.
    query = f"""
SELECT
  rev.dept_code,
  rev.dept_name,
  rev.year,
  rev.agent_code,
  rev.agent_name,
  rev.customer_count,
  rev.revenue,
  COALESCE(calls.call_count, 0) AS call_count
FROM (
  SELECT
    DEPT.DEPTNAME                                        AS dept_code,
    DEPT.DEPTDES                                         AS dept_name,
    YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')) AS year,
    AGENTS.AGENTCODE                                     AS agent_code,
    AGENTS.AGENTNAME                                     AS agent_name,
    COUNT(DISTINCT CUSTOMERS.CUST)                       AS customer_count,
    SUM(
      INVOICEITEMS.QPRICE
      * CURRENCIES.EXCHANGE
      * (100.0 - INVOICEITEMS.TOTPERCENT) / 100.0
    )                                                    AS revenue
  FROM amaba.dbo.INVOICES
  INNER JOIN amaba.dbo.CUSTOMERS    ON CUSTOMERS.CUST      = INVOICES.CUST
  INNER JOIN amaba.dbo.CURRENCIES   ON CURRENCIES.CURRENCY = INVOICES.CURRENCY
  INNER JOIN amaba.dbo.INVOICEITEMS ON INVOICEITEMS.IV     = INVOICES.IV
  INNER JOIN amaba.dbo.PART         ON INVOICEITEMS.PART   = PART.PART
  LEFT  JOIN amaba.dbo.MBA_PART     ON PART.PART           = MBA_PART.PART
  INNER JOIN amaba.dbo.DEPT         ON MBA_PART.DEPT       = DEPT.DEPT
  INNER JOIN amaba.dbo.AGENTS       ON CUSTOMERS.AGENT     = AGENTS.AGENT
  WHERE (INVOICES.TYPE = 'C' OR INVOICES.TYPE = 'F')
    AND YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')) IN ({years_sql})
    AND INVOICES.IVNUM NOT LIKE 'T%'
    AND INVOICEITEMS.TQUANT <> 0
  GROUP BY
    DEPT.DEPTNAME,
    DEPT.DEPTDES,
    YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')),
    AGENTS.AGENTCODE,
    AGENTS.AGENTNAME
) rev
LEFT JOIN (
  SELECT
    DEPT.DEPTNAME                                        AS dept_code,
    YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')) AS year,
    AGENTS.AGENTCODE                                     AS agent_code,
    COUNT(DISTINCT DOCUMENTS_Q.DOCNO)                    AS call_count
  FROM amaba.dbo.INVOICES
  INNER JOIN amaba.dbo.CUSTOMERS    ON CUSTOMERS.CUST      = INVOICES.CUST
  INNER JOIN amaba.dbo.CURRENCIES   ON CURRENCIES.CURRENCY = INVOICES.CURRENCY
  INNER JOIN amaba.dbo.INVOICEITEMS ON INVOICEITEMS.IV     = INVOICES.IV
  INNER JOIN amaba.dbo.PART         ON INVOICEITEMS.PART   = PART.PART
  LEFT  JOIN amaba.dbo.MBA_PART     ON PART.PART           = MBA_PART.PART
  INNER JOIN amaba.dbo.DEPT         ON MBA_PART.DEPT       = DEPT.DEPT
  INNER JOIN amaba.dbo.AGENTS       ON CUSTOMERS.AGENT     = AGENTS.AGENT
  INNER JOIN amaba.dbo.TRANSORDER   ON INVOICEITEMS.TRANS  = TRANSORDER.TRANS
  LEFT  JOIN amaba.dbo.SERNTRANS
    ON  TRANSORDER.DOC   = SERNTRANS.DOC
    AND TRANSORDER.TYPE  = SERNTRANS.TYPE
    AND TRANSORDER.KLINE = SERNTRANS.KLINE
  LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL
    ON  SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
    AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
    AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
    AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN
  LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q
    ON  MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC
  WHERE (INVOICES.TYPE = 'C' OR INVOICES.TYPE = 'F')
    AND YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')) IN ({years_sql})
    AND INVOICES.IVNUM NOT LIKE 'T%'
    AND INVOICEITEMS.TQUANT <> 0
  GROUP BY
    DEPT.DEPTNAME,
    YEAR(DATEADD(minute, INVOICES.IVDATE, '01/01/1988')),
    AGENTS.AGENTCODE
) calls
  ON  rev.dept_code  = calls.dept_code
  AND rev.year       = calls.year
  AND rev.agent_code = calls.agent_code
ORDER BY rev.year, rev.revenue DESC
"""
    
    try:
        conn = get_connection()
        cursor = conn.cursor()
        print("[DEPT] מריץ שאילתה... (עשוי לקחת מספר שניות)")
        cursor.execute(query)
        rows = cursor.fetchall()
        columns = [d[0] for d in cursor.description]
        cursor.close()
        conn.close()
        print(f"[DEPT] נמצאו {len(rows):,} שורות")
    except Exception as e:
        print(f"[DEPT] ✗ שגיאה בשאילתה: {e}")
        return
    
    stats = []
    for row in rows:
        d = dict(zip(columns, row))
        uid = f"{d.get('dept_code','')}__{d.get('year','')}_{d.get('agent_code','')}"
        stats.append({
            'id': uid,
            'deptCode': str(d.get('dept_code') or ''),
            'deptName': str(d.get('dept_name') or ''),
            'year': str(d.get('year') or ''),
            'agentCode': str(d.get('agent_code') or ''),
            'agentName': str(d.get('agent_name') or ''),
            'customerCount': float(d.get('customer_count') or 0),
            'callCount': float(d.get('call_count') or 0),
            'revenue': float(d.get('revenue') or 0),
        })
    
    if not stats:
        print("[DEPT] אין נתונים לשליחה")
        return
    
    try:
        resp = requests.post(dept_url, json={'stats': stats}, timeout=180)
        if resp.status_code == 200:
            result = resp.json()
            print(f"[DEPT] ✅ נשלחו {result.get('imported',0):,} שורות בהצלחה")
        else:
            print(f"[DEPT] ✗ שגיאה: {resp.status_code} - {resp.text[:300]}")
    except Exception as e:
        print(f"[DEPT] ✗ שגיאת שליחה: {e}")


def run_monthly_calls_sync(years=None):
    """סנכרון קריאות שירות חודשיות מ-Priority ERP (DOCUMENTS_Q)"""
    if years is None:
        years = [2024, 2025, 2026]
    years_sql = ','.join(str(y) for y in years)

    # Build the target URL
    base = REPLIT_API_URL.rsplit('/api/', 1)[0]
    target_url = f"{base}/api/sync/monthly-call-stats"

    print(f"\n{'='*60}")
    print(f"  סנכרון קריאות שירות חודשיות — שנים {years_sql}")
    print(f"  → {target_url}")
    print(f"{'='*60}\n")

    # גילוי עמודת סטטוס בטבלת DOCUMENTS
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DOCUMENTS'
          AND TABLE_CATALOG = 'amaba'
          AND (COLUMN_NAME LIKE '%STAT%'
            OR COLUMN_NAME LIKE '%CANCEL%'
            OR COLUMN_NAME LIKE '%STATUS%'
            OR COLUMN_NAME LIKE '%MBA%')
        ORDER BY COLUMN_NAME
    """)
    stat_cols = cursor.fetchall()
    cursor.close()

    if stat_cols:
        print("[MONTHLY-CALLS] עמודות סטטוס שנמצאו בטבלת DOCUMENTS:")
        for col in stat_cols:
            col_name, col_type = col[0], col[1]
            # הצג ערכים ייחודיים לכל עמודת סטטוס
            try:
                cursor3 = conn.cursor()
                cursor3.execute(f"SELECT DISTINCT [{col_name}] FROM amaba.dbo.DOCUMENTS WHERE DOCNO LIKE 'A%'")
                vals = [str(r[0]) for r in cursor3.fetchall()]
                cursor3.close()
                print(f"  • {col_name}  ({col_type}) — ערכים: {', '.join(vals)}")
            except Exception:
                print(f"  • {col_name}  ({col_type})")
    else:
        print("[MONTHLY-CALLS] לא נמצאו עמודות סטטוס — ממשיך ללא סינון מבוטלות")

    # חפש גם עמודות עם טקסט חופשי שעשויות להכיל תיאור סטטוס
    try:
        cursor4 = conn.cursor()
        cursor4.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'DOCUMENTS'
              AND TABLE_CATALOG = 'amaba'
              AND COLUMN_NAME LIKE '%DES%'
              AND DATA_TYPE IN ('varchar','nvarchar','char','nchar')
            ORDER BY COLUMN_NAME
        """)
        des_cols = cursor4.fetchall()
        cursor4.close()
        if des_cols:
            print("[MONTHLY-CALLS] עמודות תיאור נוספות (DES):")
            for col in des_cols:
                col_name, col_type = col[0], col[1]
                try:
                    cursor5 = conn.cursor()
                    cursor5.execute(f"SELECT DISTINCT [{col_name}] FROM amaba.dbo.DOCUMENTS WHERE DOCNO LIKE 'A%' AND [{col_name}] IS NOT NULL AND [{col_name}] <> ''")
                    vals = [str(r[0]).strip() for r in cursor5.fetchall()]
                    cursor5.close()
                    if vals:
                        print(f"  • {col_name}  ({col_type}) — {', '.join(vals[:10])}")
                except Exception:
                    pass
    except Exception:
        pass

    # חפש את השדה "מספר מבא" — דוגמה לערך: 2601595/2
    try:
        conn_find = get_connection()
        cur_cols = conn_find.cursor()
        cur_cols.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'DOCUMENTS'
              AND TABLE_CATALOG = 'amaba'
              AND DATA_TYPE IN ('varchar','nvarchar','char','nchar')
            ORDER BY COLUMN_NAME
        """)
        text_cols = [r[0] for r in cur_cols.fetchall()]
        cur_cols.close()

        search_val = '2601595/2'
        search_partial = '2601595'

        # חפש ב-DOCUMENTS
        print(f"\n[MONTHLY-CALLS] מחפש '{search_val}' בעמודות טקסט של DOCUMENTS...")
        found_in_docs = False
        for col in text_cols:
            try:
                cur_s = conn_find.cursor()
                cur_s.execute(f"SELECT TOP 1 DOCNO, [{col}] FROM amaba.dbo.DOCUMENTS WHERE [{col}] LIKE ?", f'%{search_partial}%')
                row = cur_s.fetchone()
                cur_s.close()
                if row:
                    print(f"  ✅ DOCUMENTS.{col}: DOCNO={row[0]}, ערך={row[1]}")
                    found_in_docs = True
            except Exception:
                pass
        if not found_in_docs:
            print("  לא נמצא ב-DOCUMENTS")

        # חפש ב-ORDERS (ORDNAME הוא שדה נפוץ לזה)
        print(f"[MONTHLY-CALLS] מחפש '{search_val}' ב-ORDERS...")
        try:
            cur_o = conn_find.cursor()
            cur_o.execute("SELECT TOP 5 ORDNAME, DOC, DOCNO FROM amaba.dbo.ORDERS WHERE ORDNAME LIKE ?", f'%{search_partial}%')
            rows_o = cur_o.fetchall()
            cur_o.close()
            if rows_o:
                for r in rows_o:
                    print(f"  ✅ ORDERS.ORDNAME={r[0]}, DOC={r[1]}, DOCNO={r[2]}")
            else:
                print("  לא נמצא ב-ORDERS.ORDNAME")
        except Exception as e:
            print(f"  ORDERS: {e}")

        # חפש בטבלות MBA נוספות
        for tbl in ['MBA_SERNTRANSCALL', 'MBA_SERNORD']:
            try:
                cur_t = conn_find.cursor()
                cur_t.execute(f"""
                    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME=? AND TABLE_CATALOG='amaba'
                    AND DATA_TYPE IN ('varchar','nvarchar','char','nchar')
                """, tbl)
                tbl_cols = [r[0] for r in cur_t.fetchall()]
                cur_t.close()
                for col in tbl_cols:
                    try:
                        cur_s2 = conn_find.cursor()
                        cur_s2.execute(f"SELECT TOP 1 [{col}] FROM amaba.dbo.{tbl} WHERE [{col}] LIKE ?", f'%{search_partial}%')
                        row = cur_s2.fetchone()
                        cur_s2.close()
                        if row:
                            print(f"  ✅ {tbl}.{col}: {row[0]}")
                    except Exception:
                        pass
            except Exception:
                pass

        conn_find.close()
    except Exception as e:
        print(f"[MONTHLY-CALLS] שגיאה בחיפוש שדה מבא: {e}")

    conn.close()

    # קריאות שירות = תעודות שה-DOCNO שלהן מתחיל ב-A (למשל A251234241)
    # מסנן: רק קריאות עם "מספר מבא" = קריאות שיש להן תעודת משלוח ב-MBA_SERNTRANSCALL
    query = f"""
SELECT
  YEAR(DATEADD(minute, D.CURDATE, '01/01/1988'))  AS yr,
  MONTH(DATEADD(minute, D.CURDATE, '01/01/1988')) AS mo,
  COUNT(DISTINCT D.DOCNO)                         AS call_count
FROM amaba.dbo.DOCUMENTS D
WHERE D.DOCNO LIKE 'A%'
  AND ISNULL(D.CANCEL, 'N') <> 'Y'
  AND EXISTS (
    SELECT 1 FROM amaba.dbo.MBA_SERNTRANSCALL SC
    WHERE SC.CALL = D.DOC
  )
  AND YEAR(DATEADD(minute, D.CURDATE, '01/01/1988')) IN ({years_sql})
GROUP BY
  YEAR(DATEADD(minute, D.CURDATE, '01/01/1988')),
  MONTH(DATEADD(minute, D.CURDATE, '01/01/1988'))
ORDER BY yr, mo
"""
    try:
        conn2 = get_connection()
        cursor = conn2.cursor()
        print("[MONTHLY-CALLS] מריץ שאילתה... (עשוי לקחת מספר שניות)")
        cursor.execute(query)
        rows = cursor.fetchall()
        cursor.close()
        conn2.close()
        print(f"[MONTHLY-CALLS] נמצאו {len(rows)} חודשים")
    except Exception as e:
        print(f"[MONTHLY-CALLS] ✗ שגיאה בשאילתה: {e}")
        return

    stats = []
    for row in rows:
        yr = int(row.yr)
        mo = int(row.mo)
        year_month = f"{yr}-{mo:02d}"
        stats.append({'yearMonth': year_month, 'callCount': float(row.call_count or 0)})
        print(f"  {year_month}: {int(row.call_count or 0):,} קריאות")

    if not stats:
        print("[MONTHLY-CALLS] אין נתונים לשליחה")
        return

    try:
        resp = requests.post(target_url, json={'stats': stats}, timeout=60)
        if resp.status_code == 200:
            result = resp.json()
            print(f"\n[MONTHLY-CALLS] ✅ נשלחו {result.get('imported', 0)} חודשים בהצלחה")
        else:
            print(f"[MONTHLY-CALLS] ✗ שגיאה: {resp.status_code} - {resp.text[:300]}")
    except Exception as e:
        print(f"[MONTHLY-CALLS] ✗ שגיאת שליחה: {e}")


def run_ship_sync(discover_only=False, from_date=None, to_date=None):
    import urllib.parse
    
    print(f"\n{'='*60}")
    print(f"  Ship API (UPS Israel) - {'גילוי endpoints' if discover_only else 'סנכרון משלוחים'}")
    print(f"{'='*60}\n")
    
    config = get_ship_config()
    
    if not config['email'] or not config['password']:
        print("[SHIP] ✗ חסרים פרטי התחברות ל-Ship API")
        print("       הגדר SHIP_API_CONFIG ב-config.py או משתני סביבה")
        return
    
    print(f"[SHIP] Base URL: {config['base_url']}")
    print(f"[SHIP] Customer ID: {config['customer_id']}")
    print(f"[SHIP] Email: {config['email']}")
    
    token = ship_api_authenticate(config)
    if not token:
        print("[SHIP] ✗ לא ניתן להתחבר. בדוק שם משתמש וסיסמה")
        return
    
    if discover_only:
        ship_api_discover(config, token)
        return
    
    shipments = ship_api_fetch_shipments(config, token, from_date, to_date)
    
    if shipments:
        ship_api_send_to_replit(shipments, REPLIT_API_URL)
    else:
        print("[SHIP] אין נתונים לסנכרון - נסה להריץ עם --ship-discover כדי לגלות endpoints")


def run_calibrator_dept_stats_sync(years=None):
    """סנכרון ביצוע מחלקות לפי כייל (ORDERS.DOER) — מי ביצע את העבודה בפועל"""
    if years is None:
        years = [2024, 2025, 2026]
    years_sql = ','.join(str(y) for y in years)

    base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    endpoint = f"{base_url}/api/sync/calibrator-dept-stats"

    SEP = "=" * 60
    print(f"\n{SEP}")
    print(f"  ביצוע מחלקות לפי כייל (ORDERS.DOER) - שנים {years_sql}")
    print(f"  → {endpoint}")
    print(f"{SEP}\n")

    # Query via ORDERS → ORDERITEMS → PART → (LEFT) MBA_PART → (LEFT) DEPT
    # Using LEFT JOINs so calibrators whose parts have no DEPT entry are still captured
    # ORDERS.DOER = the person who performed the order (calibrator)
    query = f"""
SELECT
  COALESCE(d.DEPTNAME, 'NONE')                            AS dept_code,
  COALESCE(d.DEPTDES,  N'ללא מחלקה')                      AS dept_name,
  YEAR(DATEADD(n, o.CURDATE, '01/01/1988'))               AS year,
  o.DOER                                                  AS doer,
  COUNT(DISTINCT o.CUST)                                  AS customer_count,
  SUM(oi.QPRICE)                                          AS revenue,
  COUNT(DISTINCT o.ORD)                                   AS call_count
FROM amaba.dbo.ORDERS o
INNER JOIN amaba.dbo.ORDERITEMS oi ON oi.ORD  = o.ORD
INNER JOIN amaba.dbo.PART        p  ON oi.PART = p.PART
LEFT  JOIN amaba.dbo.MBA_PART    mp ON p.PART  = mp.PART
LEFT  JOIN amaba.dbo.DEPT        d  ON mp.DEPT = d.DEPT
WHERE o.DOER IS NOT NULL AND o.DOER != 0
  AND o.CURDATE > 0
  AND YEAR(DATEADD(n, o.CURDATE, '01/01/1988')) IN ({years_sql})
GROUP BY
  d.DEPTNAME,
  d.DEPTDES,
  YEAR(DATEADD(n, o.CURDATE, '01/01/1988')),
  o.DOER
ORDER BY year, revenue DESC
"""

    try:
        conn = get_connection()
        cursor = conn.cursor()
        print("[CALIB-DEPT] מריץ שאילתה... (עשוי לקחת מספר שניות)")
        cursor.execute(query)
        rows = cursor.fetchall()
        columns = [d[0] for d in cursor.description]
        cursor.close()
        conn.close()
        print(f"[CALIB-DEPT] נמצאו {len(rows):,} שורות")
    except Exception as e:
        print(f"[CALIB-DEPT] ✗ שגיאה בשאילתה: {e}")
        return

    stats = []
    for row in rows:
        d = dict(zip(columns, row))
        doer = str(d.get('doer') or '')
        dept = str(d.get('dept_code') or '')
        year = str(d.get('year') or '')
        uid = f"{doer}__{dept}__{year}"
        stats.append({
            'id': uid,
            'doerId': doer,
            'deptCode': dept,
            'deptName': str(d.get('dept_name') or ''),
            'year': year,
            'customerCount': float(d.get('customer_count') or 0),
            'callCount': float(d.get('call_count') or 0),
            'revenue': float(d.get('revenue') or 0),
        })

    if not stats:
        print("[CALIB-DEPT] אין נתונים לשליחה")
        return

    try:
        resp = requests.post(endpoint, json={'stats': stats}, timeout=180)
        if resp.status_code == 200:
            result = resp.json()
            print(f"\n[CALIB-DEPT] ✅ נשלחו {result.get('imported', 0)} שורות בהצלחה")
        else:
            print(f"[CALIB-DEPT] ✗ שגיאה: {resp.status_code} - {resp.text[:300]}")
    except Exception as e:
        print(f"[CALIB-DEPT] ✗ שגיאת שליחה: {e}")


def run_calibrators_sync():
    """סנכרון כיילים מ-[kyulan].[dbo].[tblUsers] לשרת Replit"""
    base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    endpoint = f"{base_url}/api/sync/calibrators"

    SEP = "=" * 60
    print(f"\n{SEP}")
    print(f"  סנכרון כיילים → Replit")
    print(f"  כתובת: {endpoint}")
    print(f"{SEP}\n")

    conn = get_connection()
    c = conn.cursor()

    # שלב 1: שלוף משתמשים מ-kyulan.tblUsers
    print("[1] שולף כיילים מ-[kyulan].[dbo].[tblUsers]...")
    users = {}
    try:
        c.execute("""
            SELECT
                [ID],
                ISNULL([FirstNameHeb], '') AS fnHeb,
                ISNULL([LastNameHeb],  '') AS lnHeb,
                ISNULL([FirstNameEng], '') AS fnEng,
                ISNULL([LastNameEng],  '') AS lnEng,
                ISNULL([Department],   '') AS dept
            FROM [kyulan].[dbo].[tblUsers]
            WHERE [Active] = 1
            ORDER BY [LastNameHeb], [FirstNameHeb]
        """)
        for row in c.fetchall():
            uid, fnH, lnH, fnE, lnE, dept = row
            fullHeb = f"{fnH} {lnH}".strip()
            fullEng = f"{fnE} {lnE}".strip()
            users[uid] = {
                "userId": str(uid),
                "fullName": fullHeb or fullEng or None,
                "agentCode": dept or None,
                "calibrationCount": 0,
            }
        print(f"   ✅ נמצאו {len(users)} כיילים פעילים")
        for uid, u in users.items():
            print(f"   {uid:<6} | {u['fullName'] or '(ללא שם)':<28} | {u['agentCode'] or ''}")
    except Exception as e:
        print(f"   ⚠️  לא ניתן לגשת ל-kyulan.tblUsers: {e}")

    # שלב 2: ספור כיולים לכל מכייל
    print(f"\n[2] סופר כיולים לכל מכייל (MBA_SERNORD → ORDERS.DOER)...")
    try:
        c.execute("""
            SELECT o.DOER, COUNT(*) AS cnt
            FROM MBA_SERNORD s
            JOIN ORDERS o ON s.ORD = o.ORD
            WHERE o.DOER IS NOT NULL AND o.DOER != 0
            GROUP BY o.DOER
        """)
        counts = {int(row[0]): int(row[1]) for row in c.fetchall()}
        matched = 0
        for uid, cnt in counts.items():
            if uid in users:
                users[uid]["calibrationCount"] = cnt
                matched += 1
        unmatched = [str(uid) for uid in counts if uid not in users]
        print(f"   ✅ הותאמו {matched}/{len(counts)} ערכים")
        if unmatched:
            print(f"   ⚠️  DOER ללא התאמה: {', '.join(unmatched[:20])}")
    except Exception as e:
        print(f"   ⚠️  שגיאה בספירת כיולים: {e}")

    conn.close()

    # שלב 3: שלח ל-Replit
    payload = list(users.values())
    print(f"\n[3] שולח {len(payload)} כיילים ל-Replit...")
    try:
        resp = requests.post(
            endpoint,
            json={"calibrators": payload},
            timeout=30,
            headers={"Content-Type": "application/json"}
        )
        print(f"\n   HTTP {resp.status_code}")
        if resp.ok:
            data = resp.json()
            print(f"✅ נשמרו בהצלחה: {data.get('saved', '?')} כיילים")
        else:
            print(f"❌ שגיאה {resp.status_code}: {resp.text[:300]}")
    except Exception as e:
        print(f"❌ שגיאת חיבור: {e}")

    print(f"\n{SEP}")
    print("  סיום סנכרון כיילים")
    print(f"{SEP}\n")


def sync_all_return_documents(conn):
    """שאילתה גלובלית — כל תעודות ההחזרה מ-2024 לכל הלקוחות"""
    base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    endpoint = f"{base_url}/api/sync/company-return-documents"

    SEP = "=" * 60
    print(f"\n{SEP}")
    print(f"  סנכרון תעודות החזרה גלובלי")
    print(f"  → {endpoint}")
    print(f"{SEP}\n")

    cursor = conn.cursor()
    sql = """
        SELECT
            d.DOCNO,
            DATEADD(n, d.CURDATE, '01/01/1988') AS OpenDate,
            d.TOTPRICE - d.VAT AS CostAfterDiscount,
            ds.STATDES,
            d.CUST AS CustId,
            c.CUSTDES AS CustomerName
        FROM DOCUMENTS d
        LEFT JOIN DOCUMENTSA da ON d.DOC = da.DOC
        LEFT JOIN DOCSTATS ds ON da.ASSEMBLYSTATUS = ds.DOCSTAT
        LEFT JOIN CUSTOMERS c ON d.CUST = c.CUST
        WHERE d.TYPE = 'N'
          AND DATEADD(n, d.CURDATE, '01/01/1988') >= '2024-01-01'
          AND DATEADD(n, d.CURDATE, '01/01/1988') <= EOMONTH(GETDATE())
        ORDER BY d.CURDATE DESC
    """
    try:
        cursor.execute(sql)
    except Exception as e:
        print(f"[COMPANY-RETURNS] ✗ שגיאת שאילתה: {e}")
        cursor.close()
        return

    documents = []
    for row in cursor.fetchall():
        doc_no = str(row.DOCNO or '').strip()
        open_date = row.OpenDate
        cost = round(float(row.CostAfterDiscount or 0), 2)
        status = str(row.STATDES or '').strip()

        if 'טיוטא' in status or 'מבוטלת' in status:
            continue

        cust_id = str(row.CustId or '').strip()
        customer_name = str(row.CustomerName or '').strip()
        month = open_date.strftime('%Y-%m') if open_date else ''
        doc_date = open_date.strftime('%d/%m/%Y') if open_date else ''

        documents.append({
            'docNumber': doc_no,
            'customerName': customer_name,
            'customerId': cust_id,
            'openDate': doc_date,
            'value': cost,
            'status': status,
            'month': month,
        })

    cursor.close()
    print(f"[COMPANY-RETURNS] נמצאו {len(documents)} תעודות החזרה")

    try:
        headers = {'Content-Type': 'application/json'}
        if SYNC_SECRET:
            headers['x-sync-secret'] = SYNC_SECRET
        resp = requests.post(endpoint, json={'documents': documents},
                             headers=headers, timeout=60)
        if resp.ok:
            data = resp.json()
            print(f"[COMPANY-RETURNS] ✓ נשמרו {data.get('saved', '?')} תעודות")
        else:
            print(f"[COMPANY-RETURNS] ✗ {resp.status_code}: {resp.text[:200]}")
    except Exception as e:
        print(f"[COMPANY-RETURNS] ✗ שגיאת שליחה: {e}")

    print(f"{SEP}\n")


def sync_all_calibration_alerts(conn):
    """שאילתה גלובלית — כל המכשירים עם תאריכי כיול מכל הלקוחות, ללא הגבלת [:10]"""
    base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    endpoint = f"{base_url}/api/sync/company-calibration-alerts"

    SEP = "=" * 60
    print(f"\n{SEP}")
    print(f"  סנכרון התראות כיול גלובלי")
    print(f"  → {endpoint}")
    print(f"{SEP}\n")

    cursor = conn.cursor()
    sql = """
        SELECT
            sn.CUST AS CustId,
            c.CUSTDES AS CustomerName,
            sn.SERNUM,
            p.PARTDES,
            p.PART AS PartNumber,
            sn.NEXTMAINTDATE,
            sn.LASTMAINTDATE,
            MAX(CASE WHEN so.NEXTCALIB > 0 THEN so.NEXTCALIB ELSE 0 END) AS NEXTCALIB_ORD,
            MAX(CASE WHEN so.LASTMAINTDATE > 0 THEN so.LASTMAINTDATE ELSE 0 END) AS LASTMAINT_ORD,
            (SELECT TOP 1 o2.ORDNAME
             FROM MBA_SERNORD so2
             JOIN ORDERS o2 ON so2.ORD = o2.ORD
             WHERE so2.SERN = sn.SERN
             ORDER BY so2.LASTMAINTDATE DESC) AS LAST_ORDNAME
        FROM SERNUMBERS sn
        LEFT JOIN MBA_SERNORD so ON so.SERN = sn.SERN
        LEFT JOIN PART p ON sn.PART = p.PART
        LEFT JOIN CUSTOMERS c ON sn.CUST = c.CUST
        WHERE sn.SERNUM IS NOT NULL AND sn.SERNUM != ''
        GROUP BY sn.SERN, sn.SERNUM, p.PARTDES, p.PART, sn.NEXTMAINTDATE, sn.LASTMAINTDATE, sn.CUST, c.CUSTDES
    """
    try:
        cursor.execute(sql)
    except Exception as e:
        print(f"[COMPANY-CAL-ALERTS] ✗ שגיאת שאילתה: {e}")
        cursor.close()
        return

    today = datetime.now()
    alerts = []
    for row in cursor.fetchall():
        serial_no = str(row.SERNUM or '').strip()
        device_name = str(row.PARTDES or '').strip()
        cust_id = str(row.CustId or '').strip()
        customer_name = str(row.CustomerName or '').strip()

        next_calib_ord = getattr(row, 'NEXTCALIB_ORD', 0) or 0
        last_maint_ord = getattr(row, 'LASTMAINT_ORD', 0) or 0
        part_number = str(getattr(row, 'PartNumber', '') or '').strip()

        next_maint = priority_date_to_datetime(next_calib_ord) or priority_date_to_datetime(row.NEXTMAINTDATE)
        last_maint = priority_date_to_datetime(last_maint_ord) or priority_date_to_datetime(row.LASTMAINTDATE)

        if not next_maint and last_maint:
            next_maint = last_maint + relativedelta(months=12)

        if not next_maint:
            continue

        alert_type = 'error' if next_maint < today else 'warning'
        location = get_location_from_part(part_number)

        alerts.append({
            'customerId': cust_id,
            'customerName': customer_name,
            'serialNo': serial_no,
            'deviceName': device_name,
            'nextCalDate': format_date(next_maint),
            'lastCalDate': format_date(last_maint),
            'type': alert_type,
            'location': location,
        })

    cursor.close()
    print(f"[COMPANY-CAL-ALERTS] נמצאו {len(alerts)} מכשירים עם תאריכי כיול")

    # Send in batches to avoid 413 Request Entity Too Large
    # Uses syncId approach: insert all batches with a unique syncId,
    # then on the LAST batch send isLast=True to atomically delete old rows.
    # This prevents data loss if two syncs overlap.
    import uuid as _uuid
    BATCH_SIZE = 5000
    total_batches = (len(alerts) + BATCH_SIZE - 1) // BATCH_SIZE
    sync_id = str(_uuid.uuid4())
    total_sent = 0
    total_saved = 0
    for i in range(0, len(alerts), BATCH_SIZE):
        chunk = alerts[i:i + BATCH_SIZE]
        batch_num = i // BATCH_SIZE + 1
        is_last = (i + BATCH_SIZE >= len(alerts))
        try:
            headers = {'Content-Type': 'application/json'}
            if SYNC_SECRET:
                headers['x-sync-secret'] = SYNC_SECRET
            resp = requests.post(endpoint, json={
                    'alerts': chunk,
                    'syncId': sync_id,
                    'isLast': is_last,
                    'batchIndex': batch_num - 1,
                    'totalBatches': total_batches
                }, headers=headers, timeout=120)
            if resp.ok:
                data = resp.json()
                saved = data.get('saved', 0)
                total_saved += saved
                total_sent += len(chunk)
                print(f"[COMPANY-CAL-ALERTS] ✓ באצ' {batch_num}: נשמרו {saved} התראות (סהכ {total_sent}/{len(alerts)})")
            else:
                print(f"[COMPANY-CAL-ALERTS] ✗ באצ' {batch_num}: {resp.status_code}: {resp.text[:200]}")
                break
        except Exception as e:
            print(f"[COMPANY-CAL-ALERTS] ✗ באצ' {batch_num}: שגיאת שליחה: {e}")
            break

    print(f"[COMPANY-CAL-ALERTS] סהכ נשמרו {total_saved} התראות כיול")
    print(f"{SEP}\n")


# ─── Operational Query ────────────────────────────────────────────────────────
OPERATIONAL_QUERY = """
SELECT TOP 5000
    DOCUMENTS.DOCNO                  AS [תעודת משלוח]
  , FORMAT(DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך תעודת משלוח]
  , CUSTOMERS.CUSTNAME               AS [מספר לקוח]
  , CUSTOMERS.CUSTDES                AS [שם לקוח]
  , CUSTOMERS.MBA_NOINVOICE          AS [ללא חשבונית לפריט]
  , AGENTS.AGENTCODE                 AS [מספר סוכן]
  , AGENTS.AGENTNAME                 AS [שם סוכן]
  , CUSTOMERS1.CUSTNAME              AS [מספר לקוח מרכז]
  , CUSTOMERS1.CUSTDES               AS [שם לקוח מרכז]
  , ZONES.ZONECODE                   AS [קוד אזור]
  , ZONES.ZONEDES                    AS [תאור אזור]
  , CTYPE.CTYPECODE                  AS [קוד סוג לקוח]
  , CTYPE.CTYPENAME                  AS [תאור סוג לקוח]
  , CTYPE2.CTYPE2CODE                AS [קוד סיווג נוסף]
  , CTYPE2.CTYPE2NAME                AS [תיאור סיווג נוסף]
  , PART.PARTNAME                    AS [מקט]
  , PART.PARTDES                     AS [תאור מקט]
  , PART.MBA_PARTSET                 AS [מקט סט]
  , TRANSORDER6.MBA_PARTSET          AS [מקט סט קליטה]
  , TRANSORDER.TQUANT/1000           AS [כמות]
  , CASE WHEN (TRANSORDER6.MBA_PARTSET = 'Y') THEN (TRANSORDER.TQUANT/1000) ELSE 1 END AS [כמות מחושבת]
  , FAMILY.FAMILYNAME                AS [קוד משפחת מוצר]
  , FAMILY.FAMILYDES                 AS [שם משפחת מוצר]
  , DEPT.DEPTNAME                    AS [מספר מחלקה]
  , DEPT.DEPTDES                     AS [שם מחלקה]
  , PARTPRICE.PRICE                  AS [מחיר מחירון]
  , DOCUMENTS_Q.DOCNO                AS [קריאת שרות]
  , SERNUMBERS.FREE1                 AS [מספר סידורי]
  , FORMAT(DATEADD(minute, TRANSORDER_QW.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך הכיול]
  , USERS.USERNAME                   AS [שם כייל]
  FROM amaba.dbo.DOCUMENTS
  INNER JOIN amaba.dbo.CUSTOMERS       ON (DOCUMENTS.CUST = CUSTOMERS.CUST)
  INNER JOIN amaba.dbo.TRANSORDER      ON (DOCUMENTS.DOC = TRANSORDER.DOC)
  INNER JOIN amaba.dbo.PART            ON (TRANSORDER.PART = PART.PART)
  INNER JOIN amaba.dbo.FAMILY          ON (PART.FAMILY = FAMILY.FAMILY)
  LEFT  JOIN amaba.dbo.MBA_PART        ON (PART.PART = MBA_PART.PART)
  INNER JOIN amaba.dbo.AGENTS          ON (CUSTOMERS.AGENT = AGENTS.AGENT)
  INNER JOIN amaba.dbo.CUSTOMERS AS CUSTOMERS1 ON (CUSTOMERS.MCUST = CUSTOMERS1.CUST)
  INNER JOIN amaba.dbo.ZONES           ON (CUSTOMERS.ZONE = ZONES.ZONE)
  INNER JOIN amaba.dbo.CTYPE           ON (CUSTOMERS.CTYPE = CTYPE.CTYPE)
  INNER JOIN amaba.dbo.CTYPE2          ON (CUSTOMERS.CTYPE2 = CTYPE2.CTYPE2)
  LEFT  JOIN amaba.dbo.DEPT            ON (MBA_PART.DEPT = DEPT.DEPT)
  LEFT  JOIN amaba.dbo.PARTPRICE       ON (PART.PART = PARTPRICE.PART
                                           AND PARTPRICE.QUANT = 1000
                                           AND PARTPRICE.PLIST = -1
                                           AND PARTPRICE.PLDATE = (
                                             SELECT amaba.dbo.PRICELISTDATE.PLDATE
                                             FROM   amaba.dbo.PRICELISTDATE
                                             WHERE  PRICELISTDATE.PLIST = -1
                                             AND    PRICELISTDATE.VALID = 'Y'))
  LEFT  JOIN amaba.dbo.SERNTRANS       ON (TRANSORDER.DOC  = SERNTRANS.DOC
                                           AND TRANSORDER.TYPE  = SERNTRANS.TYPE
                                           AND TRANSORDER.KLINE = SERNTRANS.KLINE)
  LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL ON (SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
                                           AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
                                           AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
                                           AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN)
  LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q ON (MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLS       ON (DOCUMENTS_Q.DOC = SERVCALLS.DOC)
  LEFT  JOIN amaba.dbo.SERNUMBERS      ON (SERVCALLS.SERN  = SERNUMBERS.SERN)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER_QW ON (DOCUMENTS_Q.DOC = TRANSORDER_QW.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLITEMS   ON (TRANSORDER_QW.TRANS = SERVCALLITEMS.TRANS)
  LEFT  JOIN system.dbo.USERS          ON (SERVCALLITEMS.MBA_TECHNICIAN = USERS.T$USER)
  LEFT  JOIN amaba.dbo.MBA_TRANSORDER  ON (TRANSORDER.TRANS = MBA_TRANSORDER.TRANS)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER6 ON (MBA_TRANSORDER.NTRANS = TRANSORDER6.TRANS)
  WHERE  DOCUMENTS.TYPE = 'D'
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') >= ?
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') <= ?
  AND    DOCUMENTS_Q.TYPE = 'Q'
"""

# ─── Financial Query ───────────────────────────────────────────────────────────
FINANCIAL_QUERY = """
SELECT TOP 10000
    INVOICES.IVNUM      AS [חשבונית]
  , FORMAT(DATEADD(minute, INVOICES.IVDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך החשבונית]
  , CUSTOMERS.CUSTNAME  AS [מספר לקוח]
  , CUSTOMERS.CUSTDES   AS [שם לקוח]
  , INVOICEITEMS.KLINE  AS [שורה בחשבונית]
  , INVOICEITEMS.TQUANT/1000  AS [כמות בפירוט החשבונית]
  , CASE
      WHEN (PART.MBA_COSTING = 'Y' AND TRANSORDER6.MBA_PARTSET <> 'Y' AND DOCUMENTS_Q.DOC IS NULL)
        THEN (INVOICEITEMS.TQUANT/1000)
      ELSE
        CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR TRANSORDER6.MBA_PARTSET = 'Y' OR DOCUMENTS_Q.DOC = 0)
          THEN (INVOICEITEMS.TQUANT/1000)
          ELSE 1
        END
    END                 AS [כמות מיוחדת בפירוט חשבונית]
  , PART.PARTNAME       AS [מק"ט]
  , PART.PARTDES        AS [תאור מוצר]
  , PART.MBA_COSTING    AS [לתמחור בלבד]
  , TRANSORDER6.MBA_COSTING  AS [לתמחור בלבד קליטה]
  , PART.MBA_PARTSET    AS [מקט סט?]
  , TRANSORDER6.MBA_PARTSET  AS [מק"ט סט קליטה]
  , CURRENCIES.CODE     AS [מטבע]
  , CURRENCIES.EXCHANGE AS [שער חליפין]
  , INVOICEITEMS.PRICE  AS [מחיר ליחידה]
  , INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE  AS [מחיר ליחידיה (בשקלים)]
  , INVOICEITEMS.TOTPERCENT   AS [הנחה כללית]
  , INVOICEITEMS.T$PERCENT    AS [הנחה לשורה]
  , INVOICEITEMS.PRICE * (100.0 - INVOICEITEMS.T$PERCENT)/100.0  AS [מחיר ליחידה אחרי הנחה]
  , (INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE) * (100.0 - INVOICEITEMS.T$PERCENT)/100.0  AS [מחיר ליחידה אחרי הנחה (בשקלים)]
  , INVOICEITEMS.QPRICE AS [סה"כ מחיר]
  , INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE  AS [סהכ מחיר (בשקלים)]
  , INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100)  AS [סהכ מחיר לשורה כולל הנחה כללית]
  , (INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100)  AS [סהכ לשורה כולל הנחה כללית (בשקלים)]
  , (INVOICEITEMS.PRICE * (100.0 - INVOICEITEMS.T$PERCENT)/100.0) * (100 - INVOICEITEMS.TOTPERCENT)/100.0  AS [מחיר ליחידה אחרי כל ההנחות]
  , ((INVOICEITEMS.PRICE * CURRENCIES.EXCHANGE) * (100.0 - INVOICEITEMS.T$PERCENT)/100.0) * (100 - INVOICEITEMS.TOTPERCENT)/100.0  AS [מחיר ליחידה אחרי כל ההנחות (בשקלים)]
  , CASE
      WHEN (INVOICEITEMS.TQUANT/1000 = (CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR DOCUMENTS_Q.DOC = 0 OR DOCUMENTS_Q.DOC IS NULL) THEN (INVOICEITEMS.TQUANT/1000) ELSE 1 END))
        THEN (INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100))
      ELSE ((INVOICEITEMS.QPRICE * ((100 - INVOICEITEMS.TOTPERCENT)/100)) / ABS(INVOICEITEMS.TQUANT/1000))
    END  AS [סהכ לשורה בחשבונית כולל חריגים]
  , CASE
      WHEN (INVOICEITEMS.TQUANT/1000 = (CASE WHEN (TRANSORDER6.MBA_COSTING = 'Y' OR TRANSORDER6.MBA_PARTSET = 'Y' OR DOCUMENTS_Q.DOC = 0 OR DOCUMENTS_Q.DOC IS NULL) THEN (INVOICEITEMS.TQUANT/1000) ELSE 1 END))
        THEN ((INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100))
      ELSE (((INVOICEITEMS.QPRICE * CURRENCIES.EXCHANGE) * ((100 - INVOICEITEMS.TOTPERCENT)/100)) / ABS(INVOICEITEMS.TQUANT/1000))
    END  AS [סהכ לשורה בחשבונית כולל חריגים (בשקלים)]
  , DOCUMENTS_Q.DOC     AS [ק.ש]
  , INVOICES.DISPRICE   AS [סהכ כותרת]
  , INVOICES.DISPRICE * CURRENCIES.EXCHANGE  AS [סהכ כותרת (בשקלים)]
  , DOCUMENTS.DOCNO     AS [תעודת משלוח]
  , PART.MBA_OUTCALIB   AS [כיול חוץ]
  , PART.MBA_INCALIB    AS [כיול פנים]
  , FAMILY.FAMILYNAME   AS [קוד משפחת מוצר]
  , FAMILY.FAMILYDES    AS [שם משפחת מוצר]
  , DEPT.DEPTNAME       AS [מספר מחלקה]
  , DEPT.DEPTDES        AS [שם מחלקה]
  , PARTPRICE.PRICE     AS [מחיר מחירון בסיס]
  , AGENTS.AGENTCODE    AS [מספר סוכן]
  , AGENTS.AGENTNAME    AS [שם סוכן]
  , CUSTOMERS1.CUSTNAME AS [מספר לקוח מרכז]
  , CUSTOMERS1.CUSTDES  AS [שם לקוח מרכז]
  , ZONES.ZONECODE      AS [קוד אזור]
  , ZONES.ZONEDES       AS [תאור אזור]
  , CTYPE.CTYPECODE     AS [קוד סוג לקוח]
  , CTYPE.CTYPENAME     AS [תאור סוג לקוח]
  , CTYPE2.CTYPE2CODE   AS [קוד סיווג נוסף ללקוח]
  , CTYPE2.CTYPE2NAME   AS [תיאור סיווג נוסף ללקוח]
  , DOCUMENTS_Q.DOCNO   AS [קריאת שרות]
  , SERNUMBERS.FREE1    AS [מספר סידורי]
  , FORMAT(DATEADD(minute, TRANSORDER_QW.CURDATE, '01/01/1988'), 'dd/MM/yy')  AS [תאריך הכיול]
  , USERS.USERNAME      AS [שם כייל בעברית]
FROM amaba.dbo.INVOICES
INNER JOIN amaba.dbo.FNCTRANS      ON (FNCTRANS.FNCTRANS = INVOICES.FNCTRANS)
INNER JOIN amaba.dbo.CUSTOMERS     ON (CUSTOMERS.CUST = INVOICES.CUST)
INNER JOIN amaba.dbo.CURRENCIES    ON (CURRENCIES.CURRENCY = INVOICES.CURRENCY)
LEFT  JOIN amaba.dbo.CURREGITEMS   ON (CURREGITEMS.CURRENCY = INVOICES.CURRENCY
                                    AND CURREGITEMS.CURDATE = CASE WHEN (INVOICES.CURRENCY = -1) THEN 0 ELSE INVOICES.IVDATE END)
INNER JOIN amaba.dbo.INVOICEITEMS  ON (INVOICEITEMS.IV = INVOICES.IV)
INNER JOIN amaba.dbo.PART          ON (INVOICEITEMS.PART = PART.PART)
INNER JOIN amaba.dbo.FAMILY        ON (PART.FAMILY = FAMILY.FAMILY)
LEFT  JOIN amaba.dbo.MBA_PART      ON (PART.PART = MBA_PART.PART)
INNER JOIN amaba.dbo.DEPT          ON (MBA_PART.DEPT = DEPT.DEPT)
LEFT  JOIN amaba.dbo.PARTPRICE     ON (PART.PART = PARTPRICE.PART
                                    AND PARTPRICE.QUANT = 1000
                                    AND PARTPRICE.PLIST = -1
                                    AND PARTPRICE.PLDATE = (
                                      SELECT amaba.dbo.PRICELISTDATE.PLDATE
                                      FROM   amaba.dbo.PRICELISTDATE
                                      WHERE  amaba.dbo.PRICELISTDATE.PLIST = -1
                                      AND    amaba.dbo.PRICELISTDATE.VALID = 'Y'))
INNER JOIN amaba.dbo.TRANSORDER    ON (INVOICEITEMS.TRANS = TRANSORDER.TRANS)
INNER JOIN amaba.dbo.DOCUMENTS     ON (TRANSORDER.DOC = DOCUMENTS.DOC)
INNER JOIN amaba.dbo.AGENTS        ON (CUSTOMERS.AGENT = AGENTS.AGENT)
INNER JOIN amaba.dbo.CUSTOMERS AS CUSTOMERS1 ON (CUSTOMERS.MCUST = CUSTOMERS1.CUST)
INNER JOIN amaba.dbo.ZONES         ON (CUSTOMERS.ZONE = ZONES.ZONE)
INNER JOIN amaba.dbo.CTYPE         ON (CUSTOMERS.CTYPE = CTYPE.CTYPE)
INNER JOIN amaba.dbo.CTYPE2        ON (CUSTOMERS.CTYPE2 = CTYPE2.CTYPE2)
LEFT  JOIN amaba.dbo.SERNTRANS     ON (TRANSORDER.DOC   = SERNTRANS.DOC
                                    AND TRANSORDER.TYPE  = SERNTRANS.TYPE
                                    AND TRANSORDER.KLINE = SERNTRANS.KLINE)
LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL ON (SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
                                    AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
                                    AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
                                    AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN)
LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q ON (MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC)
LEFT  JOIN amaba.dbo.SERVCALLS     ON (DOCUMENTS_Q.DOC = SERVCALLS.DOC)
LEFT  JOIN amaba.dbo.SERNUMBERS    ON (SERVCALLS.SERN  = SERNUMBERS.SERN)
LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER_QW ON (DOCUMENTS_Q.DOC = TRANSORDER_QW.DOC
                                    AND TRANSORDER_QW.TYPE = 'Q')
LEFT  JOIN amaba.dbo.SERVCALLITEMS ON (TRANSORDER_QW.TRANS = SERVCALLITEMS.TRANS)
LEFT  JOIN system.dbo.USERS        ON (SERVCALLITEMS.MBA_TECHNICIAN = USERS.T$USER)
LEFT  JOIN amaba.dbo.MBA_TRANSORDER ON (TRANSORDER.TRANS = MBA_TRANSORDER.TRANS)
LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER6 ON (MBA_TRANSORDER.NTRANS = TRANSORDER6.TRANS)
WHERE (INVOICES.TYPE = 'C' OR INVOICES.TYPE = 'F')
AND   DATEADD(minute, INVOICES.IVDATE, '01/01/1988') >= ?
AND   DATEADD(minute, INVOICES.IVDATE, '01/01/1988') <= ?
AND   INVOICES.IVNUM NOT LIKE 'T%'
AND   INVOICEITEMS.TQUANT <> 0
ORDER BY INVOICEITEMS.KLINE
"""


def _rows_to_dicts(cursor) -> list:
    """המרת שורות pyodbc לרשימת מילונים."""
    columns = [col[0] for col in cursor.description]
    result = []
    for r in cursor.fetchall():
        d = {}
        for col, val in zip(columns, r):
            if val is None:
                d[col] = None
            elif hasattr(val, 'isoformat'):
                d[col] = val.isoformat()
            else:
                d[col] = val
        result.append(d)
    return result


def _push_batches(api_url: str, rows: list, sync_id: str, clear: bool, batch_size: int = 50):
    """שליחת שורות ל-API באצוות עם ניסיונות חוזרים."""
    import math
    total = len(rows)
    batches = math.ceil(total / batch_size)
    imported = 0
    for i in range(batches):
        batch = rows[i * batch_size:(i + 1) * batch_size]
        payload = {"rows": batch, "syncId": sync_id, "clearAll": clear and i == 0}
        for attempt in range(3):
            try:
                resp = requests.post(api_url, json=payload, timeout=90, verify=False)
                resp.raise_for_status()
                data = resp.json()
                imported += data.get("imported", 0)
                print(f"  Batch {i+1}/{batches}: {len(batch)} שורות → {data.get('imported', 0)} יובאו")
                break
            except Exception as e:
                if attempt == 2:
                    print(f"  [ERROR] batch {i+1}/{batches}: {e}")
                    raise
                print(f"  [retry {attempt+1}/3] {e}")
                time.sleep(3)
        if i < batches - 1:
            time.sleep(1)
    return imported


def run_operational_query_sync(date_from: str, date_to: str, clear: bool = False):
    """סנכרון שאילתת תפעול (תעודות משלוח מסוג D + קריאות שירות Q)."""
    print(f"\n[OPERATIONAL-QUERY] טווח: {date_from} → {date_to} | מחיקה: {clear}")
    d_from = datetime.strptime(date_from, "%Y-%m-%d").strftime("%m/%d/%Y")
    d_to   = datetime.strptime(date_to,   "%Y-%m-%d").strftime("%m/%d/%Y")

    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(OPERATIONAL_QUERY, d_from, d_to)
        rows = _rows_to_dicts(cursor)
    finally:
        conn.close()
    print(f"[OPERATIONAL-QUERY] נשלפו {len(rows):,} שורות מ-SQL Server")

    if not rows:
        print("[OPERATIONAL-QUERY] אין נתונים לסנכרון.")
        return

    base = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    api_url = f"{base}/api/sync/operational-query"
    sync_id = f"oq-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    total = _push_batches(api_url, rows, sync_id, clear)
    print(f"[OPERATIONAL-QUERY] ✓ סה\"כ יובאו: {total:,} שורות (syncId: {sync_id})")


def run_financial_query_sync(date_from: str, date_to: str, clear: bool = False):
    """סנכרון שאילתת פיננסים (חשבוניות)."""
    print(f"\n[FINANCIAL-QUERY] טווח: {date_from} → {date_to} | מחיקה: {clear}")
    d_from = datetime.strptime(date_from, "%Y-%m-%d").strftime("%m/%d/%Y")
    d_to   = datetime.strptime(date_to,   "%Y-%m-%d").strftime("%m/%d/%Y")

    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(FINANCIAL_QUERY, d_from, d_to)
        rows = _rows_to_dicts(cursor)
    finally:
        conn.close()
    print(f"[FINANCIAL-QUERY] נשלפו {len(rows):,} שורות מ-SQL Server")

    if not rows:
        print("[FINANCIAL-QUERY] אין נתונים לסנכרון.")
        return

    base = REPLIT_API_URL.replace('/api/sync/customer-data', '')
    api_url = f"{base}/api/sync/financial-query"
    sync_id = f"fq-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    total = _push_batches(api_url, rows, sync_id, clear)
    print(f"[FINANCIAL-QUERY] ✓ סה\"כ יובאו: {total:,} שורות (syncId: {sync_id})")


def main():
    global success_count, fail_count, processed_count
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='סנכרון לקוחות מ-Priority ERP')
    parser.add_argument('-c', '--customer', type=int, help='מספר לקוח ספציפי לסנכרון')
    parser.add_argument('-s', '--search', type=str, help='חיפוש לקוח לפי שם')
    parser.add_argument('--url', type=str, help='כתובת שרת Replit (למשל: https://your-app.replit.app)')
    parser.add_argument('--departments', action='store_true', help='סנכרון נתוני ביצוע מחלקות')
    parser.add_argument('--dept-years', type=str, default='2024,2025,2026', help='שנים לסנכרון מחלקות (ברירת מחדל: 2024,2025,2026)')
    parser.add_argument('--monthly-calls', action='store_true', help='סנכרון קריאות שירות חודשיות (DOCUMENTS_Q) לפי חודש')
    parser.add_argument('--calibrators', action='store_true', help='סנכרון כיילים מ-kyulan.tblUsers')
    parser.add_argument('--calib-dept-stats', action='store_true', help='סנכרון ביצוע מחלקות לפי כייל (ORDERS.DOER)')
    parser.add_argument('--ship', action='store_true', help='סנכרון משלוחים מ-Ship API (UPS)')
    parser.add_argument('--ship-discover', action='store_true', help='גילוי endpoints זמינים ב-Ship API')
    parser.add_argument('--ship-from', type=str, help='תאריך התחלה למשלוחים (YYYY-MM-DD)')
    parser.add_argument('--ship-to', type=str, help='תאריך סיום למשלוחים (YYYY-MM-DD)')
    parser.add_argument('--skip-to', type=int, default=0, help='דלג לאינדקס לקוח מסוים (לחידוש סנכרון שנקטע)')
    parser.add_argument('--global-sync', action='store_true', help='סנכרון גלובלי בלבד: תעודות החזרה + התראות כיול (ללא לולאת לקוחות)')
    parser.add_argument('--cal-alerts', action='store_true', help='סנכרון התראות כיול בלבד (מהיר, ללא תעודות החזרה ולולאת לקוחות)')
    parser.add_argument('--operational-query', action='store_true', help='סנכרון שאילתת תפעול (תעודות משלוח + קריאות שירות)')
    parser.add_argument('--financial-query', action='store_true', help='סנכרון שאילתת פיננסים (חשבוניות)')
    parser.add_argument('--date-from', type=str, help='תאריך התחלה YYYY-MM-DD (עבור --operational-query / --financial-query)')
    parser.add_argument('--date-to', type=str, help='תאריך סיום YYYY-MM-DD (עבור --operational-query / --financial-query)')
    parser.add_argument('--clear', action='store_true', help='מחק את כל השורות הקיימות לפני הכנסה (עבור שאילתות תפעול/פיננסים)')
    args = parser.parse_args()
    
    # עדכון URL אם צוין
    global REPLIT_API_URL
    if args.url:
        base_url = args.url.rstrip('/')
        REPLIT_API_URL = f"{base_url}/api/sync/customer-data"
        print(f"[CONFIG] Using custom URL: {REPLIT_API_URL}")
    
    # Department sync mode
    if args.departments:
        years = [int(y.strip()) for y in args.dept_years.split(',') if y.strip().isdigit()]
        run_department_sync(years=years)
        return

    # Monthly calls sync mode
    if args.monthly_calls:
        years = [int(y.strip()) for y in args.dept_years.split(',') if y.strip().isdigit()]
        run_monthly_calls_sync(years=years)
        return

    # Calibrators sync mode
    if args.calibrators:
        run_calibrators_sync()
        return

    # Calibrator dept stats sync mode (by ORDERS.DOER)
    if args.calib_dept_stats:
        years = [int(y.strip()) for y in args.dept_years.split(',') if y.strip().isdigit()]
        run_calibrator_dept_stats_sync(years=years)
        return
    
    # Ship API modes
    if args.ship_discover:
        run_ship_sync(discover_only=True)
        return
    
    if args.ship:
        run_ship_sync(discover_only=False, from_date=args.ship_from, to_date=args.ship_to)
        return

    # Global sync only (return documents + calibration alerts, no customer loop)
    if args.global_sync:
        print("\n[GLOBAL-SYNC] מריץ סנכרון גלובלי בלבד (תעודות החזרה + התראות כיול)...")
        base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
        trigger_url = f"{base_url}/api/sync/global-sync"
        headers = {'Content-Type': 'application/json'}
        if SYNC_SECRET:
            headers['x-sync-secret'] = SYNC_SECRET

        def _notify_sync_state(status: str, error: str = ''):
            try:
                payload = {'status': status}
                if error:
                    payload['error'] = error
                resp = requests.post(trigger_url, json=payload, headers=headers, timeout=10)
                if resp.ok:
                    print(f"[GLOBAL-SYNC] → סטטוס '{status}' דווח לשרת")
                else:
                    print(f"[GLOBAL-SYNC] ⚠ כשל בדיווח סטטוס: {resp.status_code}")
            except Exception as e:
                print(f"[GLOBAL-SYNC] ⚠ לא ניתן לדווח סטטוס: {e}")

        _notify_sync_state('running')
        try:
            global_conn = get_connection()
            try:
                sync_all_return_documents(global_conn)
                sync_all_calibration_alerts(global_conn)
                print("[GLOBAL-SYNC] ✓ סנכרון גלובלי הושלם בהצלחה")
                _notify_sync_state('complete')
            finally:
                global_conn.close()
                print("[GLOBAL-SYNC] חיבור נסגר")
        except Exception as e:
            print(f"[GLOBAL-SYNC] ✗ שגיאה: {e}")
            _notify_sync_state('error', str(e))
        return

    # Cal-alerts only mode (fast — no customer loop, no return documents)
    if args.cal_alerts:
        print("\n[CAL-ALERTS] מריץ סנכרון התראות כיול בלבד...")
        base_url = REPLIT_API_URL.replace('/api/sync/customer-data', '')
        print(f"[CAL-ALERTS] → {base_url}/api/sync/company-calibration-alerts")
        try:
            cal_conn = get_connection()
            try:
                sync_all_calibration_alerts(cal_conn)
                print("[CAL-ALERTS] ✓ סנכרון התראות כיול הושלם")
            finally:
                cal_conn.close()
                print("[CAL-ALERTS] חיבור נסגר")
        except Exception as e:
            print(f"[CAL-ALERTS] ✗ שגיאה: {e}")
        return

    # Operational query sync
    if args.operational_query:
        if not args.date_from or not args.date_to:
            today = datetime.now()
            date_to   = today.strftime("%Y-%m-%d")
            date_from = today.strftime("%Y-01-01")
        else:
            date_from = args.date_from
            date_to   = args.date_to
        run_operational_query_sync(date_from, date_to, clear=args.clear)
        return

    # Financial query sync
    if args.financial_query:
        if not args.date_from or not args.date_to:
            today = datetime.now()
            date_to   = today.strftime("%Y-%m-%d")
            date_from = today.strftime("%Y-01-01")
        else:
            date_from = args.date_from
            date_to   = args.date_to
        run_financial_query_sync(date_from, date_to, clear=args.clear)
        return

    # חיפוש לקוח
    if args.search:
        search_customer(args.search)
        return
    
    # אם נבחר לקוח ספציפי
    if args.customer:
        sync_single_customer(args.customer)
        return
    
    print(f"\n{'='*60}")
    print(f"  Priority ERP Sync v{VERSION}")
    print(f"  Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
    print(f"{'='*60}\n")
    
    # בדיקת חיבור
    try:
        conn = get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM CUSTOMERS")
        count = cursor.fetchone()[0]
        print(f"[OK] Connected: {count:,} לקוחות")
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"[ERROR] Connection failed: {str(e)}")
        return
    
    # שליפת רשימת לקוחות
    print("\n[INFO] שולף רשימת לקוחות פעילים...")
    customers = fetch_all_customers()
    print(f"[INFO] נמצאו {len(customers):,} לקוחות עם פעילות מ-2024")
    
    if not customers:
        print("[WARNING] לא נמצאו לקוחות לסנכרון")
        return
    
    # דילוג לאינדקס מסוים לחידוש סנכרון שנקטע
    if args.skip_to > 0:
        skip = min(args.skip_to, len(customers))
        print(f"[SKIP] מדלג לאינדקס {skip:,} (נשארו {len(customers) - skip:,} לקוחות)")
        customers = customers[skip:]
    
    # טעינת הגדרות ציון מה-API
    scoring_config = fetch_scoring_config(REPLIT_API_URL)
    
    # סנכרון מקבילי מלא - שליפה ושליחה מקביליות
    # הוקטן למניעת שגיאות "Connection is busy"
    BATCH_SIZE = 50  # גודל אצווה
    DB_WORKERS = 4   # מספר חוטים לשליפה מהדאטאבייס
    HTTP_WORKERS = 8  # מספר חוטים לשליחת HTTP (הוקטן מ-20 למניעת 503)
    BATCH_DELAY = 0.5  # המתנה בין אצוות בשניות
    
    print(f"\n[START] מתחיל סנכרון {len(customers)} לקוחות")
    print(f"        (מקבילי: {DB_WORKERS} חוטי DB, {HTTP_WORKERS} חוטי HTTP)...\n")
    
    success_count = 0
    fail_count = 0
    processed_count = 0
    
    # מאגר חיבורים לשליפה מקבילית - יוצרים יותר חיבורים מ-workers למניעת צוואר בקבוק
    connection_pool = []
    for _ in range(DB_WORKERS + 2):
        try:
            connection_pool.append(get_connection())
        except Exception as e:
            print(f"  [WARN] נכשל ביצירת חיבור: {e}")
    
    if not connection_pool:
        print("[ERROR] לא ניתן ליצור חיבורים לדאטאבייס")
        return
    
    print(f"[INFO] נוצרו {len(connection_pool)} חיבורים לדאטאבייס")
    
    # נעילה לגישה למאגר החיבורים
    pool_lock = threading.Lock()
    conn_index = [0]  # רשימה כדי שנוכל לשנות מתוך הפונקציה
    
    def get_pool_connection():
        with pool_lock:
            conn = connection_pool[conn_index[0] % len(connection_pool)]
            conn_index[0] += 1
            return conn
    
    def fetch_customer_worker(cust_id, total):
        """עובד לשליפת נתוני לקוח עם ניסיונות חוזרים"""
        global fail_count, processed_count
        max_retries = 3
        for attempt in range(max_retries):
            try:
                conn = get_pool_connection()
                customer_data = fetch_customer_data(cust_id, conn, scoring_config)
                return (customer_data, cust_id, None)
            except ValueError:
                return (None, cust_id, "skip")
            except Exception as e:
                error_str = str(e)
                # ניסיון חוזר רק על שגיאות חיבור
                if "Connection is busy" in error_str or "connection" in error_str.lower():
                    if attempt < max_retries - 1:
                        time.sleep(0.5 * (attempt + 1))  # המתנה מדורגת
                        continue
                return (None, cust_id, error_str)
        return (None, cust_id, "max retries exceeded")
    
    def send_to_replit_worker(customer_data, cust_id, total):
        """עובד לשליחת נתונים ל-Replit"""
        global success_count, fail_count, processed_count
        success, error_msg = sync_to_replit(customer_data)
        
        with lock:
            processed_count += 1
            if success:
                success_count += 1
                inv_count = len(customer_data.get('invoices', []))
                print(f"[{processed_count}/{total}] ✓ {customer_data['companyName'][:25]} ({inv_count} חשב')")
            else:
                fail_count += 1
                print(f"[{processed_count}/{total}] ✗ לקוח {cust_id} - {error_msg}")
        return success
    
    try:
        # עיבוד באצוות
        for batch_start in range(0, len(customers), BATCH_SIZE):
            batch = customers[batch_start:batch_start + BATCH_SIZE]
            batch_data = []
            
            # שלב 1: שליפת נתונים מקבילית
            with ThreadPoolExecutor(max_workers=DB_WORKERS) as db_executor:
                fetch_futures = {
                    db_executor.submit(fetch_customer_worker, cust_id, len(customers)): cust_id
                    for cust_id in batch
                }
                for future in as_completed(fetch_futures):
                    result = future.result()
                    if result[0] is not None:  # customer_data
                        batch_data.append((result[0], result[1]))
                    elif result[2] and result[2] != "skip":
                        with lock:
                            processed_count += 1
                            fail_count += 1
                    else:
                        with lock:
                            processed_count += 1
            
            # שלב 2: שליחה מקבילית ל-Replit
            with ThreadPoolExecutor(max_workers=HTTP_WORKERS) as http_executor:
                futures = [
                    http_executor.submit(send_to_replit_worker, data, cust_id, len(customers))
                    for data, cust_id in batch_data
                ]
                for future in as_completed(futures):
                    pass
            
            # המתנה בין אצוות למניעת שגיאות "Connection is busy"
            if batch_start + BATCH_SIZE < len(customers):
                time.sleep(BATCH_DELAY)
    finally:
        # סגירת כל החיבורים במאגר
        for conn in connection_pool:
            try:
                conn.close()
            except:
                pass
        print(f"\n[INFO] נסגרו {len(connection_pool)} חיבורי SQL")
    
    print(f"\n{'='*60}")
    print(f"  סיכום סנכרון")
    print(f"{'='*60}")
    print(f"  סה״כ לקוחות: {len(customers)}")
    print(f"  הצליחו: {success_count}")
    print(f"  נכשלו: {fail_count}")
    print(f"{'='*60}\n")

    # ======= סנכרון גלובלי — רץ לאחר לולאת הלקוחות =======
    print("\n[GLOBAL] מתחיל סנכרון שאילתות כלל-חברה...")
    try:
        global_conn = get_connection()
        try:
            sync_all_return_documents(global_conn)
            sync_all_calibration_alerts(global_conn)
        finally:
            global_conn.close()
            print("[GLOBAL] חיבור גלובלי נסגר")
    except Exception as e:
        print(f"[GLOBAL] ✗ שגיאה בסנכרון גלובלי: {e}")

if __name__ == "__main__":
    main()
