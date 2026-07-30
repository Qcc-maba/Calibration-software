#!/usr/bin/env python3
"""
חיפוש עמודות כיול בבסיס הנתונים של Priority
מחפש: NEXTCALDATE, NEXTCALIBRATIONDATE, NESTCALDATE, ועמודות דומות
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

def connect(database=None):
    db = database or SQL_CONFIG['database']
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={db};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']};"
        f"TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)

SEARCH_TERMS = [
    'NEXTCAL', 'NESTCAL', 'NEXTCALIB', 'LASTCAL', 'CALDATE',
    'CAL_DATE', 'CALIBRAT', 'NEXTMAINT', 'LASTMAINT',
    'NEXTSERVICE', 'SERVICEDATE'
]

def search_columns(cursor, database_name):
    print(f"\n{'='*60}")
    print(f"  מחפש ב-DATABASE: {database_name}")
    print(f"{'='*60}")

    like_clauses = " OR ".join([f"COLUMN_NAME LIKE '%{t}%'" for t in SEARCH_TERMS])
    query = f"""
        SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE ({like_clauses})
        ORDER BY TABLE_NAME, COLUMN_NAME
    """
    try:
        cursor.execute(query)
        rows = cursor.fetchall()
        if rows:
            current_table = None
            for row in rows:
                if row[0] != current_table:
                    current_table = row[0]
                    print(f"\n  טבלה: {current_table}")
                print(f"    ● {row[1]}  ({row[2]})")
        else:
            print("  לא נמצאו עמודות מתאימות")
    except Exception as e:
        print(f"  שגיאה: {e}")

def show_sernumbers_columns(cursor):
    print(f"\n{'='*60}")
    print("  כל עמודות טבלת SERNUMBERS:")
    print(f"{'='*60}")
    try:
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'SERNUMBERS'
            ORDER BY ORDINAL_POSITION
        """)
        for row in cursor.fetchall():
            marker = " ◄◄ כיול!" if any(t in row[0].upper() for t in SEARCH_TERMS) else ""
            print(f"  {row[0]}  ({row[1]}){marker}")
    except Exception as e:
        print(f"  שגיאה: {e}")

def show_sample_for_table(cursor, table, column, cust_id=10251):
    print(f"\n  דוגמה מ-{table}.{column} עבור לקוח {cust_id}:")
    try:
        cursor.execute(f"SELECT TOP 5 SERNUM, {column} FROM {table} WHERE CUST = ?", cust_id)
        rows = cursor.fetchall()
        if rows:
            for r in rows:
                print(f"    SERNUM={r[0]}  {column}={r[1]}")
        else:
            print(f"    (אין נתונים ללקוח {cust_id})")
    except Exception as e:
        print(f"    שגיאה: {e}")

def main():
    print("=" * 60)
    print("  חיפוש עמודות תאריך כיול ב-Priority")
    print("=" * 60)
    print(f"שרת: {SQL_CONFIG['server']}")

    # --- חיפוש ב-amaba ---
    try:
        conn = connect()
        cursor = conn.cursor()

        search_columns(cursor, SQL_CONFIG['database'])
        show_sernumbers_columns(cursor)

        # בדיקה ספציפית לשדות שהמשתמש ביקש
        for field in ['NEXTCALDATE', 'NEXTCALIBRATIONDATE', 'NESTCALDATE', 'LASTCALDATE', 'LASTCALIBRATIONDATE']:
            try:
                cursor.execute(f"""
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'SERNUMBERS' AND COLUMN_NAME = '{field}'
                """)
                count = cursor.fetchone()[0]
                exists = "✓ קיים!" if count > 0 else "✗ לא קיים"
                print(f"\n  SERNUMBERS.{field}: {exists}")
                if count > 0:
                    show_sample_for_table(cursor, 'SERNUMBERS', field)
            except Exception as e:
                print(f"  שגיאה בבדיקת {field}: {e}")

        conn.close()
    except Exception as e:
        print(f"\n✗ שגיאה בחיבור ל-{SQL_CONFIG['database']}: {e}")

    # --- חיפוש ב-QCCData ---
    try:
        conn2 = connect('QCCData')
        cursor2 = conn2.cursor()
        search_columns(cursor2, 'QCCData')
        conn2.close()
    except Exception as e:
        print(f"\n  [SKIP] לא ניתן להתחבר ל-QCCData: {e}")

    print(f"\n{'='*60}")
    print("  סיום חיפוש")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
