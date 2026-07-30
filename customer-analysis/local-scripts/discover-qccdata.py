#!/usr/bin/env python3
"""
סקריפט חקירה - מציאת עמודת מספר הזמנה ב-QCCData
"""

import pyodbc

try:
    from config import QCCDATA_CONFIG
except ImportError:
    print("[ERROR] חסר QCCDATA_CONFIG ב-config.py")
    exit(1)

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={QCCDATA_CONFIG['server']};"
        f"DATABASE={QCCDATA_CONFIG['database']};"
        f"UID={QCCDATA_CONFIG['username']};"
        f"PWD={QCCDATA_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def main():
    conn = get_connection()
    cursor = conn.cursor()
    
    print("=" * 60)
    print("  חקירת QCCData - חיפוש עמודת מספר הזמנה")
    print("=" * 60)
    
    # 1. הצגת כל העמודות בטבלת datasheet
    print("\n[1] עמודות בטבלת datasheet:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'datasheet'
        ORDER BY ORDINAL_POSITION
    """)
    
    columns = []
    for row in cursor.fetchall():
        col_name = row[0]
        col_type = row[1]
        col_len = row[2] or ''
        columns.append(col_name)
        print(f"  {col_name:<30} {col_type} {col_len}")
    
    # 2. חיפוש עמודות שמכילות "order" או "LA"
    print("\n[2] חיפוש עמודות עם 'order', 'ord', 'la':")
    print("-" * 40)
    
    order_cols = [c for c in columns if 'order' in c.lower() or 'ord' in c.lower() or c.lower() == 'la']
    if order_cols:
        for col in order_cols:
            print(f"  נמצא: {col}")
    else:
        print("  לא נמצאו עמודות עם 'order'")
    
    # 3. דגימה של נתונים מהטבלה
    print("\n[3] דגימת 5 רשומות (כל העמודות):")
    print("-" * 40)
    
    cursor.execute("SELECT TOP 5 * FROM [dbo].[datasheet]")
    sample_rows = cursor.fetchall()
    
    for i, row in enumerate(sample_rows):
        print(f"\n  רשומה {i+1}:")
        for j, col in enumerate(columns):
            val = row[j]
            if val:
                print(f"    {col}: {val}")
    
    # 4. חיפוש ערכים שמתחילים ב-LA
    print("\n[4] חיפוש ערכים שמתחילים ב-'LA':")
    print("-" * 40)
    
    for col in columns:
        try:
            cursor.execute(f"""
                SELECT TOP 3 [{col}]
                FROM [dbo].[datasheet]
                WHERE CAST([{col}] AS VARCHAR(100)) LIKE 'LA%'
            """)
            results = cursor.fetchall()
            if results:
                print(f"\n  עמודה: {col}")
                for r in results:
                    print(f"    {r[0]}")
        except:
            pass
    
    # 5. רשימת כל הטבלאות בבסיס הנתונים
    print("\n[5] כל הטבלאות ב-QCCData:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]}")
    
    cursor.close()
    conn.close()
    
    print("\n" + "=" * 60)
    print("  סיום חקירה")
    print("=" * 60)

if __name__ == "__main__":
    main()
