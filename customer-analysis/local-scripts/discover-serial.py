#!/usr/bin/env python3
"""
חקירת טבלת SERIAL ו-PART
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
    print("  חקירת טבלאות SERIAL ו-PART")
    print("=" * 60)
    
    conn = pyodbc.connect(connection_string)
    cursor = conn.cursor()
    
    # עמודות SERIAL
    print("\n[1] עמודות בטבלת SERIAL:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'SERIAL'
        ORDER BY ORDINAL_POSITION
    """)
    
    serial_cols = []
    for row in cursor.fetchall():
        serial_cols.append(row[0])
        print(f"  {row[0]:<30} {row[1]}")
    
    # דגימת SERIAL
    print("\n[2] דגימת 5 רשומות מ-SERIAL:")
    print("-" * 40)
    
    cursor.execute("SELECT TOP 5 * FROM SERIAL ORDER BY SERIAL DESC")
    
    for row in cursor.fetchall():
        print(f"\n  רשומה:")
        for i, col in enumerate(serial_cols):
            val = row[i]
            if val and str(val).strip():
                print(f"    {col}: {val}")
    
    # עמודות PART
    print("\n[3] עמודות בטבלת PART:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'PART'
        ORDER BY ORDINAL_POSITION
    """)
    
    part_cols = []
    for row in cursor.fetchall():
        part_cols.append(row[0])
        print(f"  {row[0]:<30} {row[1]}")
    
    # דגימת PART
    print("\n[4] דגימת 5 פריטים מ-PART:")
    print("-" * 40)
    
    cursor.execute("SELECT TOP 5 PART, PARTNAME, PARTDES FROM PART")
    
    for row in cursor.fetchall():
        print(f"  PART={row[0]}: {row[1]} - {row[2]}")
    
    # חיפוש פריטים עם כיול
    print("\n[5] חיפוש פריטים הקשורים לכיול:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TOP 20 PART, PARTNAME, PARTDES
        FROM PART
        WHERE PARTDES LIKE N'%כיול%' OR PARTDES LIKE N'%טמפ%' 
           OR PARTDES LIKE N'%אלקטרו%' OR PARTDES LIKE N'%לחץ%'
           OR PARTDES LIKE N'%מימד%'
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]}: {row[1]} - {row[2]}")
    
    # טבלת FAMILY
    print("\n[6] חיפוש טבלת FAMILY:")
    print("-" * 40)
    
    cursor.execute("""
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME LIKE '%FAMILY%'
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]}")
    
    # קשר בין SERIAL להזמנות
    print("\n[7] קשר SERIAL להזמנות (ORDSERIAL):")
    print("-" * 40)
    
    cursor.execute("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'ORDSERIAL'
        ORDER BY ORDINAL_POSITION
    """)
    
    for row in cursor.fetchall():
        print(f"  {row[0]:<30} {row[1]}")
    
    cursor.close()
    conn.close()
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
