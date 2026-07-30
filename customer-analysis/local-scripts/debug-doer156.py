#!/usr/bin/env python3
"""
שאילתא ממוקדת אחת: מה ה-TECHNICIAN ID של אביחי ב-SERVCALLS?
"""

import pyodbc

try:
    from config import SQL_CONFIG
    print(f"[CONFIG] Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }

SEP = "=" * 70

def get_conn(db):
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={db};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(conn_str, timeout=60)

def run(cursor, title, sql, params=None):
    print(f"\n{SEP}")
    print(f"  {title}")
    print(SEP)
    try:
        cursor.execute(sql, params or [])
        cols = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
        print("  " + " | ".join(cols))
        print("  " + "-" * 70)
        if rows:
            for r in rows:
                print("  " + " | ".join(str(v) if v is not None else "NULL" for v in r))
        else:
            print("  *** אין תוצאות ***")
        print(f"\n  סה\"כ שורות: {len(rows)}")
    except Exception as e:
        print(f"  *** שגיאה: {e} ***")

conn = get_conn('amaba')
cur  = conn.cursor()

# 1. PHONEBOOK של אביחי — PHONEBOWNER = USERB = 157
run(cur, "1. PHONEBOOK WHERE PHONEBOWNER=157 (USERB של אביחי)",
    "SELECT PHONE, NAME, EMAIL, INACTIVE FROM amaba.dbo.PHONEBOOK WHERE PHONEBOWNER = 157")

# 2. USERSA T$USER=156 → SERVCALLS COUNT לפי שנה (TECHNICIAN=T$USER)
run(cur, "2. SERVCALLS WHERE TECHNICIAN=156 לפי שנה (T$USER ישיר)",
    """
    SELECT
      YEAR(DATEADD(n, AENDDATE, '01/01/1988')) AS year,
      COUNT(*) AS cnt
    FROM amaba.dbo.SERVCALLS
    WHERE TECHNICIAN = 156 AND AENDDATE > 0 AND YEAR(DATEADD(n, AENDDATE, '01/01/1988')) BETWEEN 2010 AND 2026
    GROUP BY YEAR(DATEADD(n, AENDDATE, '01/01/1988'))
    ORDER BY year
    """)

# 3. SERVCALLS WHERE TECHNICIAN=157 (USERB של אביחי) לפי שנה
run(cur, "3. SERVCALLS WHERE TECHNICIAN=157 (USERB של אביחי) לפי שנה",
    """
    SELECT
      YEAR(DATEADD(n, AENDDATE, '01/01/1988')) AS year,
      COUNT(*) AS cnt
    FROM amaba.dbo.SERVCALLS
    WHERE TECHNICIAN = 157 AND AENDDATE > 0 AND YEAR(DATEADD(n, AENDDATE, '01/01/1988')) BETWEEN 2010 AND 2026
    GROUP BY YEAR(DATEADD(n, AENDDATE, '01/01/1988'))
    ORDER BY year
    """)

# 4. רשימת כל TECHNICIAN + שם אפשרי מ-PHONEBOOK (PHONE=TECHNICIAN)
run(cur, "4. TECHNICIAN 2025-2026 עם שם מ-PHONEBOOK (PHONE=TECHNICIAN)",
    """
    SELECT
      sc.TECHNICIAN,
      pb.NAME,
      COUNT(*) AS cnt
    FROM amaba.dbo.SERVCALLS sc
    LEFT JOIN amaba.dbo.PHONEBOOK pb ON pb.PHONE = sc.TECHNICIAN
    WHERE sc.AENDDATE > 0
      AND YEAR(DATEADD(n, sc.AENDDATE, '01/01/1988')) IN (2025,2026)
    GROUP BY sc.TECHNICIAN, pb.NAME
    ORDER BY cnt DESC
    """)

# 5. PHONEBOOK שם אביחי — חיפוש רחב בכל עמודות טקסט
run(cur, "5. PHONEBOOK - חיפוש רחב Avihay / אביחי / avihay_am",
    """
    SELECT PHONE, NAME, EMAIL, CELLPHONE, PHONEBOWNER, INACTIVE
    FROM amaba.dbo.PHONEBOOK
    WHERE NAME  LIKE N'%אביחי%'
       OR NAME  LIKE N'%Avihay%'
       OR EMAIL LIKE N'%avihay%'
       OR EMAIL LIKE N'%amiga%'
    """)

conn.close()
print(f"\n{SEP}")
print("  סיום")
print(SEP)
