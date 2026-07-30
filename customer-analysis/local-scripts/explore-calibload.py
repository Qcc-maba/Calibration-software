#!/usr/bin/env python3
"""
חקירת טבלאות כיול ב-Priority
Priority date format: minutes since 1988-01-01 --> DATEADD(n, col, '01/01/1988')
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

TEST_CUST = 10251  # מובילאיי

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

def run(cursor, label, sql, params=None):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    try:
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        rows = cursor.fetchall()
        cols = [d[0] for d in cursor.description]
        print(f"  עמודות: {cols}")
        print(f"  תוצאות: {len(rows)}")
        for row in rows[:10]:
            print(f"    {dict(zip(cols, row))}")
    except Exception as e:
        print(f"  שגיאה: {e}")

def main():
    conn = connect()
    cursor = conn.cursor()

    # 1. מבנה DOCUMENTS - לראות כמה עמודות רלוונטיות
    run(cursor, "עמודות DOCUMENTS (ראשונות 30)", """
        SELECT TOP 30 COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'DOCUMENTS'
        ORDER BY ORDINAL_POSITION
    """)

    # 2. DOCUMENTS עם MBA_NEXTCALIBDATE ולקוח ספציפי
    run(cursor, f"DOCUMENTS.MBA_NEXTCALIBDATE עבור לקוח {TEST_CUST}", f"""
        SELECT TOP 10
            d.DOC,
            d.CUST,
            d.TYPECODE,
            DATEADD(n, d.CURDATE, '01/01/1988') AS OpenDate,
            DATEADD(n, d.MBA_NEXTCALIBDATE, '01/01/1988') AS NextCalibDate,
            d.MBA_NEXTCALIBDATE
        FROM DOCUMENTS d
        WHERE d.CUST = {TEST_CUST}
          AND d.MBA_NEXTCALIBDATE > 0
        ORDER BY d.MBA_NEXTCALIBDATE DESC
    """)

    # 3. כמה DOCUMENTS יש עם MBA_NEXTCALIBDATE != 0 (כלל הלקוחות)
    run(cursor, "סה\"כ DOCUMENTS עם NBA_NEXTCALIBDATE > 0", """
        SELECT COUNT(*) as total_docs_with_calib,
               COUNT(DISTINCT CUST) as unique_customers
        FROM DOCUMENTS
        WHERE MBA_NEXTCALIBDATE > 0
    """)

    # 4. MBA_CALIBLOAD חיבור דרך DOCUMENTS ← EXTKEY
    run(cursor, f"MBA_CALIBLOAD → DOCUMENTS → לקוח {TEST_CUST}", f"""
        SELECT TOP 10
            cl.CALIBLOAD,
            cl.MBANUM,
            cl.STATCODE,
            DATEADD(n, cl.MBA_NEXTCALIBDATE, '01/01/1988') AS NextCalibDate,
            cl.PARTMODEL,
            cl.MNFCTRNAME,
            d.CUST
        FROM MBA_CALIBLOAD cl
        JOIN DOCUMENTS d ON cl.DOC = d.DOC
        WHERE d.CUST = {TEST_CUST}
          AND cl.MBA_NEXTCALIBDATE > 0
        ORDER BY cl.MBA_NEXTCALIBDATE DESC
    """)

    # 5. MBA_CALIBLOAD כלל הלקוחות - כמה יש עם תאריך כיול?
    run(cursor, "MBA_CALIBLOAD - כמה רשומות עם NextCalibDate?", """
        SELECT COUNT(*) as with_calib_date,
               COUNT(DISTINCT d.CUST) as unique_customers
        FROM MBA_CALIBLOAD cl
        JOIN DOCUMENTS d ON cl.DOC = d.DOC
        WHERE cl.MBA_NEXTCALIBDATE > 0
    """)

    # 6. MBA_SERNORD → SERNUMBERS.SERN → CUST עבור לקוח TEST_CUST
    run(cursor, f"MBA_SERNORD → SERNUMBERS → לקוח {TEST_CUST}", f"""
        SELECT TOP 10
            sn.SERNUM,
            sn.CUST,
            DATEADD(n, so.NEXTCALIB, '01/01/1988') AS NextCalibDate,
            DATEADD(n, so.LASTMAINTDATE, '01/01/1988') AS LastMaintDate,
            so.MAINTDAYS
        FROM MBA_SERNORD so
        JOIN SERNUMBERS sn ON so.SERN = sn.SERN
        WHERE sn.CUST = {TEST_CUST}
          AND so.NEXTCALIB > 0
        ORDER BY so.NEXTCALIB DESC
    """)

    # 7. MBA_SERNORD כלל הלקוחות - כמה יש NEXTCALIB > 0?
    run(cursor, "MBA_SERNORD - כמה SERN עם NEXTCALIB > 0?", """
        SELECT COUNT(*) as with_nextcalib,
               COUNT(DISTINCT sn.CUST) as unique_customers
        FROM MBA_SERNORD so
        JOIN SERNUMBERS sn ON so.SERN = sn.SERN
        WHERE so.NEXTCALIB > 0
    """)

    # 8. דוגמאות MBA_SERNORD עם NEXTCALIB > 0 (כלשהו)
    run(cursor, "MBA_SERNORD - דוגמאות עם NEXTCALIB > 0 (כלשהו)", """
        SELECT TOP 5
            sn.SERNUM, sn.CUST,
            DATEADD(n, so.NEXTCALIB, '01/01/1988') AS NextCalibDate,
            DATEADD(n, so.LASTMAINTDATE, '01/01/1988') AS LastMaintDate,
            so.MAINTDAYS
        FROM MBA_SERNORD so
        JOIN SERNUMBERS sn ON so.SERN = sn.SERN
        WHERE so.NEXTCALIB > 0
        ORDER BY so.NEXTCALIB DESC
    """)

    # 9. MBA_CALIBLOAD - דוגמאות עם תאריך כיול (כלשהו)
    run(cursor, "MBA_CALIBLOAD - דוגמאות עם NextCalibDate (כלשהו)", """
        SELECT TOP 5
            cl.MBANUM, cl.STATCODE, cl.PARTMODEL,
            DATEADD(n, cl.MBA_NEXTCALIBDATE, '01/01/1988') AS NextCalibDate,
            d.CUST
        FROM MBA_CALIBLOAD cl
        JOIN DOCUMENTS d ON cl.DOC = d.DOC
        WHERE cl.MBA_NEXTCALIBDATE > 0
        ORDER BY cl.MBA_NEXTCALIBDATE DESC
    """)

    conn.close()
    print(f"\n{'='*60}")
    print("  סיום")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
