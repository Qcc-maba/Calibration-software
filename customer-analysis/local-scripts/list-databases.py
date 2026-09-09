#!/usr/bin/env python3
"""
סקריפט לרשימת בסיסי נתונים בשרת
"""

import pyodbc

try:
    from config import SQL_CONFIG
except ImportError:
    print("[ERROR] חסר config.py")
    exit(1)

def main():
    # נתחבר לשרת Priority (שעובד) ונרשום את כל בסיסי הנתונים
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE=master;"  # נתחבר ל-master לרשימת DBs
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    
    print("=" * 60)
    print(f"  מתחבר לשרת: {SQL_CONFIG['server']}")
    print("=" * 60)
    
    try:
        conn = pyodbc.connect(connection_string)
        cursor = conn.cursor()
        
        print("\n[1] בסיסי נתונים בשרת:")
        print("-" * 40)
        
        cursor.execute("""
            SELECT name, state_desc
            FROM sys.databases
            WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')
            ORDER BY name
        """)
        
        for row in cursor.fetchall():
            print(f"  {row[0]:<30} ({row[1]})")
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"[ERROR] {e}")

if __name__ == "__main__":
    main()
