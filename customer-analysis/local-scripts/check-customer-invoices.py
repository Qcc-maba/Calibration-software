#!/usr/bin/env python3
"""
סקריפט לבדיקת חשבוניות לקוח ב-Priority
בודק אם יש אי-התאמה בין CUST ל-CUSTNAME ומחפש חשבוניות
"""

import pyodbc

try:
    from config import SQL_CONFIG
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def check_customer(search_term):
    conn = get_connection()
    cursor = conn.cursor()
    
    print(f"\n{'='*60}")
    print(f"חיפוש לקוח: {search_term}")
    print('='*60)
    
    # בדיקה 1: מציאת הלקוח
    print("\n[1] פרטי לקוח ב-CUSTOMERS:")
    cursor.execute("""
        SELECT CUST, CUSTNAME, CUSTDES 
        FROM CUSTOMERS 
        WHERE CUSTDES LIKE ? OR CUSTNAME = ? OR CUST = ?
    """, f'%{search_term}%', search_term, search_term)
    
    customers = cursor.fetchall()
    if not customers:
        print("   לא נמצא לקוח!")
        return
    
    for c in customers:
        print(f"   CUST (פנימי): {c.CUST}")
        print(f"   CUSTNAME (מספר לקוח): {c.CUSTNAME}")
        print(f"   CUSTDES (שם): {c.CUSTDES}")
        print()
        
        cust_id = c.CUST
        
        # בדיקה 2: חשבוניות ב-DOCUMENTS
        print(f"\n[2] חשבוניות ב-DOCUMENTS עבור CUST={cust_id}:")
        cursor.execute("""
            SELECT COUNT(*) as cnt, SUM(TOTPRICE) as total, SUM(VAT) as vat
            FROM DOCUMENTS 
            WHERE CUST = ? AND TYPE LIKE 'I%'
        """, cust_id)
        
        doc = cursor.fetchone()
        print(f"   מספר מסמכים מסוג I: {doc.cnt}")
        print(f"   סה\"כ TOTPRICE: {doc.total or 0:,.2f}")
        print(f"   סה\"כ VAT: {doc.vat or 0:,.2f}")
        print(f"   סה\"כ נטו: {(doc.total or 0) - (doc.vat or 0):,.2f}")
        
        # דוגמה של מסמכים אחרונים
        print(f"\n[3] 5 חשבוניות אחרונות:")
        cursor.execute("""
            SELECT TOP 5 DOCNO, TYPE, CURDATE, TOTPRICE, VAT
            FROM DOCUMENTS 
            WHERE CUST = ? AND TYPE LIKE 'I%'
            ORDER BY CURDATE DESC
        """, cust_id)
        
        docs = cursor.fetchall()
        if docs:
            for d in docs:
                net = (d.TOTPRICE or 0) - (d.VAT or 0)
                print(f"   {d.DOCNO} | TYPE={d.TYPE} | CURDATE={d.CURDATE} | נטו={net:,.2f}")
        else:
            print("   אין חשבוניות!")
        
        # בדיקה 3: כל סוגי המסמכים
        print(f"\n[4] כל סוגי המסמכים עבור לקוח זה:")
        cursor.execute("""
            SELECT TYPE, COUNT(*) as cnt, SUM(TOTPRICE) as total
            FROM DOCUMENTS 
            WHERE CUST = ?
            GROUP BY TYPE
            ORDER BY cnt DESC
        """, cust_id)
        
        types = cursor.fetchall()
        for t in types:
            print(f"   {t.TYPE}: {t.cnt} מסמכים, סה\"כ {t.total or 0:,.2f}")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        search = sys.argv[1]
    else:
        search = input("הכנס מספר לקוח או שם לחיפוש: ")
    
    check_customer(search)
    
    print("\n" + "="*60)
    print("סיום בדיקה")
