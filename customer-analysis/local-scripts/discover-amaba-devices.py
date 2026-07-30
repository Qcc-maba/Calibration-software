#!/usr/bin/env python3
"""
חיפוש טבלאות מכשירים וכיולים ב-amaba
"""

import pyodbc

try:
    from config import SQL_CONFIG
except ImportError:
    print("[ERROR] חסר config.py")
    exit(1)

def main():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    
    print("=" * 60)
    print(f"  חיפוש טבלאות מכשירים וכיולים ב-{SQL_CONFIG['database']}")
    print("=" * 60)
    
    conn = pyodbc.connect(connection_string)
    cursor = conn.cursor()
    
    # דגימת הזמנות עם LA
    print("\n[1] דגימת הזמנות שמתחילות ב-LA:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TOP 20 ORDNAME, ORD, CUST, CURDATE
        FROM ORDERS
        WHERE ORDNAME LIKE 'LA%'
        ORDER BY CURDATE DESC
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]:<20} ORD={row[1]} CUST={row[2]}")
    
    # בדיקת סיומות
    print("\n[2] סיומות של מספרי הזמנות LA:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT RIGHT(RTRIM(ORDNAME), 1) as suffix, COUNT(*) as cnt
        FROM ORDERS
        WHERE ORDNAME LIKE 'LA%'
        GROUP BY RIGHT(RTRIM(ORDNAME), 1)
        ORDER BY cnt DESC
    """)
    
    for row in cursor.fetchall():
        suffix = row[0]
        location = 'חוץ' if suffix in ['7', '8'] else ('פנים' if suffix in ['0', '1'] else '?')
        print(f"  סיומת '{suffix}': {row[1]:,} הזמנות  ({location})")
    
    # עמודות ORDERITEMS
    print("\n[3] עמודות ב-ORDERITEMS:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'ORDERITEMS'
        ORDER BY ORDINAL_POSITION
    """)
    
    orderitem_cols = []
    for row in cursor.fetchall():
        orderitem_cols.append(row[0])
        print(f"  {row[0]:<30} {row[1]}")
    
    # דגימת ORDERITEMS
    print("\n[4] דגימת פריטי הזמנות LA:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TOP 10 oi.*, o.ORDNAME
        FROM ORDERITEMS oi
        JOIN ORDERS o ON oi.ORD = o.ORD
        WHERE o.ORDNAME LIKE 'LA%'
        ORDER BY o.CURDATE DESC
    """)
    
    for row in cursor.fetchall():
        ordname = row[-1]  # Last column is ORDNAME
        print(f"\n  הזמנה: {ordname}")
        for i, col in enumerate(orderitem_cols):
            val = row[i]
            if val and str(val).strip():
                print(f"    {col}: {val}")
    
    # חיפוש טבלאות עם SKA או PART
    print("\n[5] חיפוש טבלאות עם SKA:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TABLE_NAME, COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE COLUMN_NAME LIKE '%SKA%' OR COLUMN_NAME LIKE '%SERIAL%'
        ORDER BY TABLE_NAME
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]}.{row[1]}")
    
    cursor.close()
    conn.close()
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
