#!/usr/bin/env python3
"""
find-calibrators.py — מעניק גישה ל-QCCData לmkyulan ואז מחפש כיילים

שימוש:
  python find-calibrators.py --admin-user sa --admin-pwd <סיסמה>
  python find-calibrators.py --admin-windows          # Windows Admin Auth
"""
import pyodbc, argparse, sys

parser = argparse.ArgumentParser()
parser.add_argument('--admin-user',    type=str, help='משתמש מנהל SQL (sa / admin)')
parser.add_argument('--admin-pwd',     type=str, help='סיסמת מנהל SQL')
parser.add_argument('--admin-windows', action='store_true', help='Windows Admin Auth')
parser.add_argument('--db',            type=str, default='QCCData')
args = parser.parse_args()

try:
    from config import SQL_CONFIG
except ImportError:
    print("[ERROR] חסר config.py"); sys.exit(1)

SEP  = "=" * 60
srv  = SQL_CONFIG['server']
qdb  = args.db
user = SQL_CONFIG['username']
pwd  = SQL_CONFIG['password']

print(f"\n{SEP}")
print(f"  find-calibrators — מעניק גישה ל-{qdb} ומחפש כיילים")
print(f"  שרת: {srv}")
print(f"{SEP}\n")

# ---- שלב 1: התחבר עם חשבון מנהל ----
admin_conn = None

if args.admin_user and args.admin_pwd:
    cs = (f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={srv};DATABASE=master;"
          f"UID={args.admin_user};PWD={args.admin_pwd};Connect Timeout=10;")
    try:
        admin_conn = pyodbc.connect(cs)
        print(f"✅ חיבור מנהל: {args.admin_user}@master")
    except Exception as e:
        print(f"❌ {args.admin_user}@master: {str(e)[:100]}")

if not admin_conn and args.admin_windows:
    cs = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={srv};DATABASE=master;Trusted_Connection=yes;Connect Timeout=10;"
    try:
        admin_conn = pyodbc.connect(cs)
        print(f"✅ חיבור מנהל: Windows Auth@master")
    except Exception as e:
        print(f"❌ Windows Auth@master: {str(e)[:100]}")

if not admin_conn and not (args.admin_user or args.admin_windows):
    print("""
לא סופקו פרטי מנהל. הרץ עם אחת מהאפשרויות:

  python find-calibrators.py --admin-user sa --admin-pwd <סיסמה>
  python find-calibrators.py --admin-windows

(חשבון המנהל צריך הרשאות SYSADMIN או securityadmin על SQL Server)
""")
    sys.exit(1)

if not admin_conn:
    print("\n❌ כל ניסיונות החיבור למנהל נכשלו.")
    sys.exit(1)

# ---- שלב 2: הענק גישה ל-kyulan על QCCData ----
print(f"\n[1] מעניק גישה ל-{user} על {qdb}...")
ac = admin_conn.cursor()
ac.execute("SET NOCOUNT ON")
steps = [
    # ודא ש-kyulan קיים כ-login
    f"IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name='{user}') "
    f"EXEC sp_addlogin '{user}', '{pwd}'",
    # ודא שqdb DB user קיים
    f"USE [{qdb}]; "
    f"IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='{user}') "
    f"CREATE USER [{user}] FOR LOGIN [{user}]",
    # הענק db_datareader
    f"USE [{qdb}]; EXEC sp_addrolemember 'db_datareader', '{user}'",
]
for step in steps:
    try:
        ac.execute(step)
        admin_conn.commit()
        print(f"   ✅ {step[:80]}...")
    except Exception as e:
        err = str(e)
        if 'already' in err.lower() or 'already a member' in err.lower():
            print(f"   ℹ️  כבר קיים: {step[:60]}...")
        else:
            print(f"   ❌ {step[:60]}...\n      שגיאה: {err[:100]}")

admin_conn.close()

# ---- שלב 3: התחבר כ-kyulan ל-QCCData ----
print(f"\n[2] מתחבר כ-{user} ל-{qdb}...")
cs = (f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={srv};DATABASE={qdb};"
      f"UID={user};PWD={pwd};Connect Timeout=10;")
try:
    conn = pyodbc.connect(cs)
    print(f"✅ מחובר ל-{qdb}!")
except Exception as e:
    print(f"❌ עדיין לא ניתן להתחבר: {str(e)[:120]}")
    sys.exit(1)

c = conn.cursor()

# ---- שלב 4: רשימת טבלאות ----
print(f"\n[3] טבלאות ב-{qdb}:")
try:
    c.execute("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME")
    tables = [r[0] for r in c.fetchall()]
    print(f"   {tables}")
except Exception as e:
    print(f"   שגיאה: {e}")
    tables = []

# ---- שלב 5: חיפוש שמות כיילים ----
print(f"\n[4] חיפוש 'ערן שבח', 'משה כץ':")
try:
    c.execute("""
        SELECT t.TABLE_NAME, c.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLES t
        JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME=c.TABLE_NAME
        WHERE t.TABLE_TYPE='BASE TABLE'
          AND c.DATA_TYPE IN ('nvarchar','varchar','nchar','char')
    """)
    text_cols = c.fetchall()
    found = False
    for tbl, col in text_cols:
        try:
            c.execute(f"SELECT TOP 1 [{col}] FROM [{tbl}] WHERE [{col}] LIKE '%שבח%' OR [{col}] LIKE '%כץ%' OR [{col}] LIKE '%ערן%' OR [{col}] LIKE '%משה%'")
            row = c.fetchone()
            if row and row[0] and str(row[0]).strip():
                print(f"   ✅ [{tbl}].[{col}] = '{row[0]}'")
                found = True
        except: pass
    if not found:
        print("   לא נמצאו")
except Exception as e:
    print(f"   שגיאה: {e}")

# ---- שלב 6: טבלאות עם שמות ----
print(f"\n[5] טבלאות עם עמודות שם:")
for tbl in tables[:30]:
    try:
        c.execute(f"""
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME='{tbl}' AND (COLUMN_NAME IN ('FNAME','SNAME','NAME','FULLNAME','USERNAME','DISPLAYNAME'))
        """)
        name_cols = [r[0] for r in c.fetchall()]
        if name_cols:
            c.execute(f"SELECT TOP 3 * FROM [{tbl}]")
            cols = [d[0] for d in c.description]
            rows = c.fetchall()
            for row in rows:
                d = {k: v for k, v in zip(cols, row) if v is not None and str(v).strip() and str(v) not in ('0',' ')}
                if any(k in name_cols for k in d):
                    print(f"   [{tbl}]: {d}")
    except: pass

conn.close()
print(f"\n{SEP}\n  שלח לי את הפלט\n{SEP}\n")
