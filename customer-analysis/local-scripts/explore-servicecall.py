#!/usr/bin/env python3
"""
סקריפט לחקירת טבלת SERVICECALL ב-Priority
הרץ: python explore-servicecall.py
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

def connect():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']};"
        f"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)

def main():
    conn = connect()
    cursor = conn.cursor()
    
    print("=" * 60)
    print("חיפוש טבלאות עם 'SERV' בשם...")
    print("=" * 60)
    
    cursor.execute("""
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_NAME LIKE '%SERV%'
        ORDER BY TABLE_NAME
    """)
    tables = cursor.fetchall()
    for t in tables:
        print(f"  - {t[0]}")
    
    print("\n" + "=" * 60)
    print("מבנה טבלת SERVCALLS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SERVCALLS'
            ORDER BY ORDINAL_POSITION
        """)
        columns = cursor.fetchall()
        if columns:
            for col in columns:
                print(f"  {col[0]}: {col[1]}({col[2] or ''})")
        else:
            print("  טבלה לא נמצאה או ריקה")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("דוגמא של 5 שורות מ-SERVCALLS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT TOP 5 DOC, SERN, PART, SERVTYPE, VALIDDATE, EXPIRYDATE, STARTDATE, EDATE 
            FROM SERVCALLS
        """)
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        print(f"  עמודות: {', '.join(cols)}")
        for row in rows:
            print(f"  {dict(zip(cols, row))}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("מבנה טבלת SERVCALLITEMS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SERVCALLITEMS'
            ORDER BY ORDINAL_POSITION
        """)
        columns = cursor.fetchall()
        for col in columns:
            print(f"  {col[0]}: {col[1]}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("חיפוש טבלת SERIAL NUMBERS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT TABLE_NAME 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_NAME LIKE '%SERIAL%' OR TABLE_NAME LIKE '%SERN%'
        """)
        tables = cursor.fetchall()
        for t in tables:
            print(f"  - {t[0]}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("מבנה טבלת SERNUMBERS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SERNUMBERS'
            ORDER BY ORDINAL_POSITION
        """)
        columns = cursor.fetchall()
        for col in columns:
            print(f"  {col[0]}: {col[1]}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("דוגמא מ-SERNUMBERS עבור לקוח 320...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT TOP 5 * FROM SERNUMBERS WHERE CUST = 320
        """)
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        print(f"  עמודות: {', '.join(cols[:15])}")
        for row in rows:
            print(f"  {dict(zip(cols[:10], row[:10]))}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("קריאות שירות עם פרטי מכשיר...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT TOP 3 
                sc.DOC, sc.SERN, sc.STARTDATE, sc.EDATE,
                sn.SERNUM, sn.PARTNAME, sn.CUST
            FROM SERVCALLS sc
            JOIN SERNUMBERS sn ON sc.SERN = sn.SERN
            WHERE sn.CUST = 320
        """)
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        for row in rows:
            print(f"  {dict(zip(cols, row))}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    print("\n" + "=" * 60)
    print("חיפוש עמודות עם 'CAL' או 'DATE' בשם...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'SERVCALLS'
            AND (COLUMN_NAME LIKE '%CAL%' OR COLUMN_NAME LIKE '%DATE%' OR COLUMN_NAME LIKE '%SERIAL%' OR COLUMN_NAME LIKE '%PART%')
            ORDER BY COLUMN_NAME
        """)
        cols = cursor.fetchall()
        for col in cols:
            print(f"  {col[0]}: {col[1]}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    conn.close()
    print("\n[OK] סיום")

if __name__ == "__main__":
    main()
