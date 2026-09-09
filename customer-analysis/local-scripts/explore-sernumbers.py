#!/usr/bin/env python3
"""
סקריפט לחקירת טבלת SERNUMBERS ב-Priority
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
        print(f"  Error: {e}")
    
    print("\n" + "=" * 60)
    print("5 דוגמאות מ-SERNUMBERS...")
    print("=" * 60)
    
    try:
        cursor.execute("SELECT TOP 5 * FROM SERNUMBERS")
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        print(f"  Columns: {', '.join(cols[:12])}")
        for row in rows:
            print(f"  {dict(zip(cols[:8], row[:8]))}")
    except Exception as e:
        print(f"  Error: {e}")
    
    print("\n" + "=" * 60)
    print("מכשירים של לקוח 320 (Matas)...")
    print("=" * 60)
    
    try:
        cursor.execute("SELECT TOP 10 * FROM SERNUMBERS WHERE CUST = 320")
        rows = cursor.fetchall()
        if rows:
            cols = [desc[0] for desc in cursor.description]
            print(f"  Columns: {', '.join(cols[:12])}")
            for row in rows:
                print(f"  {dict(zip(cols[:8], row[:8]))}")
        else:
            print("  No devices found for customer 320")
    except Exception as e:
        print(f"  Error: {e}")
    
    print("\n" + "=" * 60)
    print("קריאות שירות עם SERNUMBERS...")
    print("=" * 60)
    
    try:
        cursor.execute("""
            SELECT TOP 5 
                sc.DOC, sc.SERN, sc.STARTDATE, sc.EDATE,
                sn.SERNUM, sn.PARTNAME, sn.CUST
            FROM SERVCALLS sc
            JOIN SERNUMBERS sn ON sc.SERN = sn.SERN
        """)
        rows = cursor.fetchall()
        cols = [desc[0] for desc in cursor.description]
        for row in rows:
            print(f"  {dict(zip(cols, row))}")
    except Exception as e:
        print(f"  Error: {e}")
    
    conn.close()
    print("\n[OK] Done")

if __name__ == "__main__":
    main()
