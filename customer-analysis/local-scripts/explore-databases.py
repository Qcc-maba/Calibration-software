#!/usr/bin/env python3
"""
סריקת מסד נתונים מלאה - כל הטבלאות, שורות, קשרים, ועמודות
מחפש גם היכן מופיע ID=156 (אביחי אמיגה)
"""

import pyodbc

try:
    from config import SQL_CONFIG
    print(f"[CONFIG] Server: {SQL_CONFIG['server']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }

TARGET_ID = 156
SEP  = "=" * 80
SEP2 = "-" * 80

def get_conn(db):
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={db};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(conn_str, timeout=60)

def scan_database(db_name):
    print(f"\n{'#'*80}")
    print(f"  מסד נתונים: {db_name}")
    print(f"{'#'*80}")

    conn = get_conn(db_name)
    cur  = conn.cursor()

    # ── 1. כל הטבלאות + מספר שורות ──────────────────────────────────────────
    print(f"\n{SEP}")
    print(f"  [{db_name}] טבלאות + מספר שורות")
    print(SEP)
    cur.execute("""
        SELECT t.TABLE_NAME,
               p.rows AS row_count
        FROM INFORMATION_SCHEMA.TABLES t
        JOIN sys.tables st ON st.name = t.TABLE_NAME
        JOIN sys.partitions p ON p.object_id = st.object_id AND p.index_id IN (0,1)
        WHERE t.TABLE_TYPE = 'BASE TABLE'
        ORDER BY p.rows DESC
    """)
    tables = cur.fetchall()
    print(f"  {'TABLE_NAME':<40} {'ROWS':>12}")
    print(f"  {'-'*40} {'-'*12}")
    table_names = []
    for t_name, rows in tables:
        print(f"  {t_name:<40} {rows:>12,}")
        table_names.append(t_name)
    print(f"\n  סה\"כ טבלאות: {len(table_names)}")

    # ── 2. כל הקשרים (FK) ────────────────────────────────────────────────────
    print(f"\n{SEP}")
    print(f"  [{db_name}] קשרי Foreign Key")
    print(SEP)
    cur.execute("""
        SELECT
            fk.name                        AS fk_name,
            tp.name                        AS parent_table,
            cp.name                        AS parent_col,
            tr.name                        AS ref_table,
            cr.name                        AS ref_col
        FROM sys.foreign_keys fk
        JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        JOIN sys.tables  tp ON tp.object_id = fkc.parent_object_id
        JOIN sys.columns cp ON cp.object_id = fkc.parent_object_id AND cp.column_id = fkc.parent_column_id
        JOIN sys.tables  tr ON tr.object_id = fkc.referenced_object_id
        JOIN sys.columns cr ON cr.object_id = fkc.referenced_object_id AND cr.column_id = fkc.referenced_column_id
        ORDER BY tp.name, cp.name
    """)
    fks = cur.fetchall()
    if fks:
        print(f"  {'טבלת-אב':<25} {'עמודה':<20} → {'טבלת-ייחוס':<25} {'עמודה':<20}")
        print(f"  {'-'*25} {'-'*20}   {'-'*25} {'-'*20}")
        for fk_name, pt, pc, rt, rc in fks:
            print(f"  {pt:<25} {pc:<20} → {rt:<25} {rc:<20}")
    else:
        print("  (אין FK מוגדרים - קשרים לוגיים בלבד)")
    print(f"\n  סה\"כ קשרים: {len(fks)}")

    # ── 3. חיפוש ID=156 בכל טבלה / עמודה INT ────────────────────────────────
    print(f"\n{SEP}")
    print(f"  [{db_name}] חיפוש ערך {TARGET_ID} בכל עמודות INT")
    print(SEP)

    # שלוף את כל עמודות INT לכל טבלה
    cur.execute("""
        SELECT TABLE_NAME, COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE DATA_TYPE IN ('int','smallint','tinyint','bigint')
          AND TABLE_NAME IN (
              SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
              WHERE TABLE_TYPE = 'BASE TABLE'
          )
        ORDER BY TABLE_NAME, ORDINAL_POSITION
    """)
    int_cols = cur.fetchall()

    # קבץ לפי טבלה
    from collections import defaultdict
    by_table = defaultdict(list)
    for tbl, col in int_cols:
        by_table[tbl].append(col)

    hits = []
    for tbl, cols in by_table.items():
        # בנה OR clause
        conditions = " OR ".join([f"[{c}] = {TARGET_ID}" for c in cols])
        sql = f"SELECT TOP 1 1 FROM [{tbl}] WHERE {conditions}"
        try:
            cur.execute(sql)
            row = cur.fetchone()
            if row:
                # מצאנו — איזו עמודה ספציפית?
                matched_cols = []
                for c in cols:
                    try:
                        cur.execute(f"SELECT COUNT(*) FROM [{tbl}] WHERE [{c}] = {TARGET_ID}")
                        cnt = cur.fetchone()[0]
                        if cnt > 0:
                            matched_cols.append((c, cnt))
                    except:
                        pass
                hits.append((tbl, matched_cols))
                for c, cnt in matched_cols:
                    print(f"  ✅ {tbl}.{c} = {TARGET_ID}  →  {cnt:,} שורות")
        except Exception as e:
            pass  # skip tables with errors

    if not hits:
        print(f"  ✗ לא נמצא {TARGET_ID} בשום טבלה ב-{db_name}")

    conn.close()
    return hits

# ── סריקה ──────────────────────────────────────────────────────────────────
print(SEP)
print(f"  סריקת מסד נתונים מלאה | מחפש ID={TARGET_ID} (אביחי אמיגה)")
print(SEP)

hits_amaba  = scan_database('amaba')
hits_kyulan = scan_database(***REMOVED***)

# ── סיכום כולל ────────────────────────────────────────────────────────────
print(f"\n{'#'*80}")
print(f"  סיכום: היכן ID={TARGET_ID} מופיע")
print(f"{'#'*80}")
all_hits = [('amaba', t, c, n) for t, cols in hits_amaba for c, n in cols] + \
           [(***REMOVED***, t, c, n) for t, cols in hits_kyulan for c, n in cols]
if all_hits:
    for db, tbl, col, cnt in all_hits:
        print(f"  ✅ [{db}] {tbl}.{col} = {TARGET_ID}  ({cnt:,} שורות)")
else:
    print(f"  ✗ ID={TARGET_ID} לא קיים בשום מקום בשתי הדטאבייסים")
print()
