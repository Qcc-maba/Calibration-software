#!/usr/bin/env python3
"""
מציאת לקוחות שיש להם נתוני כיול ב-MBA_SERNORD
מציג CUSTNAME (HP) וכמות המכשירים עם NEXTCALIB
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

    print("=" * 65)
    print("  לקוחות עם נתוני כיול ב-MBA_SERNORD (TOP 20 לפי מכשירים)")
    print("=" * 65)

    cursor.execute("""
        SELECT TOP 20
            c.CUSTNAME AS HP,
            c.CUSTDES   AS Name,
            c.CUST      AS InternalID,
            COUNT(DISTINCT sn.SERN) AS DeviceCount,
            SUM(CASE WHEN so.NEXTCALIB > 0 THEN 1 ELSE 0 END) AS WithNextCalib,
            MAX(DATEADD(n, so.NEXTCALIB, '01/01/1988')) AS LatestNextCalib
        FROM MBA_SERNORD so
        JOIN SERNUMBERS sn ON so.SERN = sn.SERN
        JOIN CUSTOMERS  c  ON sn.CUST = c.CUST
        WHERE so.NEXTCALIB > 0
        GROUP BY c.CUSTNAME, c.CUSTDES, c.CUST
        ORDER BY WithNextCalib DESC
    """)

    rows = cursor.fetchall()
    print(f"{'HP':>8}  {'InternalID':>10}  {'Devices':>7}  {'WithCalib':>9}  {'LatestNext':>12}  Name")
    print("-" * 80)
    for r in rows:
        print(f"{str(r.HP):>8}  {str(r.InternalID):>10}  {r.DeviceCount:>7}  {r.WithNextCalib:>9}  "
              f"{str(r.LatestNextCalib)[:10]:>12}  {(r.Name or '')[:30]}")

    print()
    print("=" * 65)
    print("  לקוח אלביט 4316 (CUST=?) - מה ה-CUSTNAME שלו?")
    print("=" * 65)

    # בדוק ספציפית את הלקוחות שראינו קודם (cust_id=765,417,2519)
    for cust_int in [765, 417, 2519]:
        cursor.execute("""
            SELECT CUST, CUSTNAME, CUSTDES
            FROM CUSTOMERS WHERE CUST = ?
        """, cust_int)
        r = cursor.fetchone()
        if r:
            print(f"  CUST={cust_int} → CUSTNAME={r.CUSTNAME}  Name={r.CUSTDES}")
        else:
            print(f"  CUST={cust_int} → לא נמצא")

    conn.close()
    print("\n[OK] Done")

if __name__ == "__main__":
    main()
