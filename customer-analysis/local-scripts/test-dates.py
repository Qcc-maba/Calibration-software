"""
בדיקת תאריכים - האם יש חשבוניות מינואר 2026
"""

import pyodbc
import os

# קריאת הגדרות מקובץ config (אותו פורמט כמו sync-customer-data.py)
try:
    from config import SQL_CONFIG
    SERVER = SQL_CONFIG['server']
    DATABASE = SQL_CONFIG['database']
    UID = SQL_CONFIG['username']
    PWD = SQL_CONFIG['password']
    print(f"[CONFIG] Server: {SERVER}/{DATABASE}")
except ImportError:
    SERVER = os.environ.get('SQL_SERVER', r'maba-priority\pri')
    DATABASE = os.environ.get('SQL_DATABASE', 'amaba')
    UID = os.environ.get('SQL_UID', '')
    PWD = os.environ.get('SQL_PWD', '')
    if not UID:
        print("[ERROR] חסר קובץ config.py")
        exit(1)

conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={UID};PWD={PWD}'

try:
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    
    print("=" * 50)
    
    # בדיקת תאריך נוכחי
    cursor.execute("SELECT GETDATE() as Today, EOMONTH(GETDATE()) as EndOfMonth")
    row = cursor.fetchone()
    print(f"תאריך נוכחי בשרת: {row.Today}")
    print(f"סוף החודש: {row.EndOfMonth}")
    print()
    
    # חשבוניות ינואר 2026 ללקוח 10009
    cursor.execute("""
        SELECT TOP 20
            i.IVNUM,
            DATEADD(n, i.IVDATE, '01/01/1988') as InvoiceDate,
            i.VATPRICE
        FROM INVOICES i
        WHERE i.CUST = 10009
          AND i.IVNUM LIKE 'I%'
          AND DATEADD(n, i.IVDATE, '01/01/1988') >= '2026-01-01'
        ORDER BY i.IVDATE DESC
    """)
    
    rows = cursor.fetchall()
    if rows:
        print(f"חשבוניות ינואר 2026 ללקוח 10009 ({len(rows)}):")
        for row in rows:
            print(f"  {row.IVNUM}: {row.InvoiceDate} | {row.VATPRICE:,.0f}")
    else:
        print("אין חשבוניות מינואר 2026 ללקוח 10009")
    
    print()
    print("=" * 50)
    
    conn.close()
    
except Exception as e:
    print(f"שגיאה: {e}")
