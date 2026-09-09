"""
sync-operational-query.py
=========================
Fetches delivery document rows (type D) linked to service calls (type Q)
from Priority SQL Server and pushes them to the Replit dashboard.

Usage:
  python sync-operational-query.py --date-from 2024-01-01 --date-to 2024-12-31
  python sync-operational-query.py --date-from 2024-01-01 --date-to 2024-12-31 --clear

Options:
  --date-from   Start date  YYYY-MM-DD
  --date-to     End date    YYYY-MM-DD
  --clear       Delete all existing rows before inserting (full replace)
  --url         Dashboard API URL (default: https://qcc-analytics.replit.app)

Requirements:
  pip install pyodbc python-dotenv
"""

import argparse
import os
import sys
import math
import time
import json
import gzip
import ssl
import http.client
import urllib.parse
import pyodbc
from datetime import datetime


def post_json(url: str, payload: dict, timeout: int = 90, debug: bool = False) -> dict:
    """POST JSON using http.client directly — no redirect follow, full control."""
    parsed = urllib.parse.urlparse(url)
    body   = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    ctx    = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode    = ssl.CERT_NONE

    # http:// חייב HTTPConnection — אחרת סנכרון לשרת מקומי נופל על handshake כושל
    if parsed.scheme == "http":
        conn = http.client.HTTPConnection(parsed.netloc, timeout=timeout)
    else:
        conn = http.client.HTTPSConnection(parsed.netloc, context=ctx, timeout=timeout)
    try:
        conn.request("POST", parsed.path or "/", body=body, headers={
            "Content-Type":   "application/json; charset=utf-8",
            "Content-Length": str(len(body)),
            "Host":           parsed.netloc,
            "Accept":         "application/json",
        })
        resp   = conn.getresponse()
        status = resp.status
        reason = resp.reason
        enc    = resp.getheader("Content-Encoding", "")
        ctype  = resp.getheader("Content-Type", "")
        raw    = resp.read()
    finally:
        conn.close()

    if debug:
        print(f"    [debug] {status} {reason} | enc={enc!r} ct={ctype!r} | {len(raw)}B | {raw[:150]!r}", flush=True)

    # follow a single redirect if needed (POST → POST)
    if status in (301, 302, 307, 308):
        loc = resp.getheader("Location", "")
        print(f"    [redirect] {status} → {loc}", flush=True)
        return post_json(loc, payload, timeout=timeout, debug=debug)

    if "gzip" in enc.lower():
        raw = gzip.decompress(raw)

    if not raw:
        raise ValueError(f"Empty response (HTTP {status} {reason})")

    if status >= 400:
        raise ValueError(f"HTTP {status}: {raw[:200].decode('utf-8', errors='replace')}")

    return json.loads(raw.decode("utf-8"))

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# ─── Configuration ────────────────────────────────────────────────────────────
# Try loading from config.py (same folder) — supports both SQL_CONFIG dict
# and individual SQL_SERVER_ADDR/SQL_UID/SQL_PWD/SQL_DATABASE variables.
# Falls back to environment variables if config.py is not found.
try:
    import config as _cfg
    _c = getattr(_cfg, "SQL_CONFIG", {})
    SQL_SERVER = _c.get("server",   "") or getattr(_cfg, "SQL_SERVER_ADDR", "") or os.environ.get("SQL_SERVER_ADDR", "")
    SQL_UID    = _c.get("username", "") or getattr(_cfg, "SQL_UID",         "") or os.environ.get("SQL_UID",         "")
    SQL_PWD    = _c.get("password", "") or getattr(_cfg, "SQL_PWD",         "") or os.environ.get("SQL_PWD",         "")
    SQL_DB     = _c.get("database", "") or getattr(_cfg, "SQL_DATABASE",    "") or os.environ.get("SQL_DATABASE",    "amaba")
except ImportError:
    SQL_SERVER = os.environ.get("SQL_SERVER_ADDR", "")
    SQL_UID    = os.environ.get("SQL_UID", "")
    SQL_PWD    = os.environ.get("SQL_PWD", "")
    SQL_DB     = os.environ.get("SQL_DATABASE", "amaba")

DEFAULT_API_URL = "https://client-analytics-dashboard--eliran8hadad.replit.app"

# תקרת השורות מוזרקת מ---top. היא הייתה קבועה על 5000, ולכן סנכרון של שנה שלמה
# נחתך באמצע (הנתונים נעצרו ב-27/03/2024) בלי שום אזהרה.
QUERY = """
SELECT TOP __TOP__
    DOCUMENTS.DOCNO                  AS [תעודת משלוח]
  , FORMAT(DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך תעודת משלוח]
  , CUSTOMERS.CUSTNAME               AS [מספר לקוח]
  , CUSTOMERS.CUSTDES                AS [שם לקוח]
  , CUSTOMERS.MBA_NOINVOICE          AS [ללא חשבונית לפריט]
  , AGENTS.AGENTCODE                 AS [מספר סוכן]
  , AGENTS.AGENTNAME                 AS [שם סוכן]
  , CUSTOMERS1.CUSTNAME              AS [מספר לקוח מרכז]
  , CUSTOMERS1.CUSTDES               AS [שם לקוח מרכז]
  , ZONES.ZONECODE                   AS [קוד אזור]
  , ZONES.ZONEDES                    AS [תאור אזור]
  , CTYPE.CTYPECODE                  AS [קוד סוג לקוח]
  , CTYPE.CTYPENAME                  AS [תאור סוג לקוח]
  , CTYPE2.CTYPE2CODE                AS [קוד סיווג נוסף]
  , CTYPE2.CTYPE2NAME                AS [תיאור סיווג נוסף]
  , PART.PARTNAME                    AS [מקט]
  , PART.PARTDES                     AS [תאור מקט]
  , PART.MBA_PARTSET                 AS [מקט סט]
  , TRANSORDER6.MBA_PARTSET          AS [מקט סט קליטה]
  , TRANSORDER.TQUANT/1000           AS [כמות]
  , CASE WHEN (TRANSORDER6.MBA_PARTSET = 'Y') THEN (TRANSORDER.TQUANT/1000) ELSE 1 END AS [כמות מחושבת]
  , FAMILY.FAMILYNAME                AS [קוד משפחת מוצר]
  , FAMILY.FAMILYDES                 AS [שם משפחת מוצר]
  , DEPT.DEPTNAME                    AS [מספר מחלקה]
  , DEPT.DEPTDES                     AS [שם מחלקה]
  , PARTPRICE.PRICE                  AS [מחיר מחירון]
  , DOCUMENTS_Q.DOCNO                AS [קריאת שרות]
  , SERNUMBERS.FREE1                 AS [מספר סידורי]
  , FORMAT(DATEADD(minute, TRANSORDER_QW.CURDATE, '01/01/1988'), 'dd/MM/yy') AS [תאריך הכיול]
  , USERS.USERNAME                   AS [שם כייל]

  FROM amaba.dbo.DOCUMENTS
  INNER JOIN amaba.dbo.CUSTOMERS       ON (DOCUMENTS.CUST = CUSTOMERS.CUST)
  INNER JOIN amaba.dbo.TRANSORDER      ON (DOCUMENTS.DOC = TRANSORDER.DOC)
  INNER JOIN amaba.dbo.PART            ON (TRANSORDER.PART = PART.PART)
  INNER JOIN amaba.dbo.FAMILY          ON (PART.FAMILY = FAMILY.FAMILY)
  LEFT  JOIN amaba.dbo.MBA_PART        ON (PART.PART = MBA_PART.PART)
  INNER JOIN amaba.dbo.AGENTS          ON (CUSTOMERS.AGENT = AGENTS.AGENT)
  INNER JOIN amaba.dbo.CUSTOMERS AS CUSTOMERS1 ON (CUSTOMERS.MCUST = CUSTOMERS1.CUST)
  INNER JOIN amaba.dbo.ZONES           ON (CUSTOMERS.ZONE = ZONES.ZONE)
  INNER JOIN amaba.dbo.CTYPE           ON (CUSTOMERS.CTYPE = CTYPE.CTYPE)
  INNER JOIN amaba.dbo.CTYPE2          ON (CUSTOMERS.CTYPE2 = CTYPE2.CTYPE2)
  LEFT  JOIN amaba.dbo.DEPT            ON (MBA_PART.DEPT = DEPT.DEPT)
  LEFT  JOIN amaba.dbo.PARTPRICE       ON (PART.PART = PARTPRICE.PART
                                           AND PARTPRICE.QUANT = 1000
                                           AND PARTPRICE.PLIST = -1
                                           AND PARTPRICE.PLDATE = (
                                             SELECT amaba.dbo.PRICELISTDATE.PLDATE
                                             FROM   amaba.dbo.PRICELISTDATE
                                             WHERE  PRICELISTDATE.PLIST = -1
                                             AND    PRICELISTDATE.VALID = 'Y'))
  LEFT  JOIN amaba.dbo.SERNTRANS       ON (TRANSORDER.DOC  = SERNTRANS.DOC
                                           AND TRANSORDER.TYPE  = SERNTRANS.TYPE
                                           AND TRANSORDER.KLINE = SERNTRANS.KLINE)
  LEFT  JOIN amaba.dbo.MBA_SERNTRANSCALL ON (SERNTRANS.DOC   = MBA_SERNTRANSCALL.DOC
                                           AND SERNTRANS.TYPE  = MBA_SERNTRANSCALL.TYPE
                                           AND SERNTRANS.KLINE = MBA_SERNTRANSCALL.KLINE
                                           AND SERNTRANS.SERN  = MBA_SERNTRANSCALL.SERN)
  LEFT  JOIN amaba.dbo.DOCUMENTS AS DOCUMENTS_Q ON (MBA_SERNTRANSCALL.CALL = DOCUMENTS_Q.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLS       ON (DOCUMENTS_Q.DOC = SERVCALLS.DOC)
  LEFT  JOIN amaba.dbo.SERNUMBERS      ON (SERVCALLS.SERN  = SERNUMBERS.SERN)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER_QW ON (DOCUMENTS_Q.DOC = TRANSORDER_QW.DOC)
  LEFT  JOIN amaba.dbo.SERVCALLITEMS   ON (TRANSORDER_QW.TRANS = SERVCALLITEMS.TRANS)
  LEFT  JOIN system.dbo.USERS          ON (SERVCALLITEMS.MBA_TECHNICIAN = USERS.T$USER)
  LEFT  JOIN amaba.dbo.MBA_TRANSORDER  ON (TRANSORDER.TRANS = MBA_TRANSORDER.TRANS)
  LEFT  JOIN amaba.dbo.TRANSORDER AS TRANSORDER6 ON (MBA_TRANSORDER.NTRANS = TRANSORDER6.TRANS)

  WHERE  DOCUMENTS.TYPE = 'D'
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') >= ?
  AND    DATEADD(minute, DOCUMENTS.CURDATE, '01/01/1988') <= ?
  AND    DOCUMENTS_Q.TYPE = 'Q'
"""


def parse_args():
    p = argparse.ArgumentParser(description="Sync operational query data to dashboard")
    p.add_argument("--date-from", required=True,
                   help="Start date YYYY-MM-DD (e.g. 2024-01-01)")
    p.add_argument("--date-to",   required=True,
                   help="End date   YYYY-MM-DD (e.g. 2024-12-31)")
    p.add_argument("--clear",     action="store_true",
                   help="Delete all existing rows before inserting")
    p.add_argument("--url",       default=DEFAULT_API_URL,
                   help=f"Dashboard base URL (default: {DEFAULT_API_URL})")
    p.add_argument("--batch",     type=int, default=50,
                   help="Rows per POST request (default: 50)")
    p.add_argument("--top",       type=int, default=5000,
                   help="Max rows to pull from SQL Server (default: 5000). "
                        "Raise it for a full year — the old fixed cap silently truncated the range.")
    p.add_argument("--sleep",     type=float, default=1.0,
                   help="Seconds between batches (default: 1). Use 0 for a local dashboard.")
    return p.parse_args()


def to_mssql_date(iso: str) -> str:
    """Convert YYYY-MM-DD to MM/DD/YYYY for MSSQL WHERE clause."""
    d = datetime.strptime(iso, "%Y-%m-%d")
    return d.strftime("%m/%d/%Y")


def connect_mssql():
    """Build pyodbc connection string from environment variables."""
    server = SQL_SERVER
    if not server:
        sys.exit("ERROR: SQL_SERVER_ADDR environment variable not set")

    # Handle "IP\\INSTANCE,PORT" format
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={server};"
        f"UID={SQL_UID};"
        f"PWD={SQL_PWD};"
        f"DATABASE={SQL_DB};"
        f"TrustServerCertificate=yes;"
    )
    print(f"  Connecting to SQL Server: {server} / {SQL_DB}...")
    return pyodbc.connect(conn_str, timeout=30)


def run():
    args = parse_args()
    date_from_ms = to_mssql_date(args.date_from)
    date_to_ms   = to_mssql_date(args.date_to)

    print(f"\n=== Operational Query Sync ===")
    print(f"  Date range : {args.date_from} → {args.date_to}")
    print(f"  Dashboard  : {args.url}")
    print(f"  Clear all  : {args.clear}")

    # ── Fetch from SQL Server ──────────────────────────────────────────────────
    conn   = connect_mssql()
    cursor = conn.cursor()
    cursor.execute(QUERY.replace("__TOP__", str(args.top)), date_from_ms, date_to_ms)

    columns = [col[0] for col in cursor.description]
    rows_raw = cursor.fetchall()
    conn.close()
    print(f"  Fetched    : {len(rows_raw)} rows from SQL Server")
    if len(rows_raw) == args.top:
        print(f"  WARNING    : hit the --top cap ({args.top}) — the range is probably truncated. "
              f"Re-run with a higher --top.")

    if not rows_raw:
        print("  Nothing to sync. Exiting.")
        return

    # Convert rows to list-of-dicts (stringify None)
    rows = []
    for r in rows_raw:
        d = {}
        for col, val in zip(columns, r):
            if val is None:
                d[col] = None
            elif hasattr(val, 'isoformat'):
                d[col] = val.isoformat()
            else:
                d[col] = val
        rows.append(d)

    # ── Push to dashboard ──────────────────────────────────────────────────────
    sync_id   = f"oq-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    api_url   = args.url.rstrip("/") + "/api/sync/operational-query"
    batch_sz  = args.batch
    batches   = math.ceil(len(rows) / batch_sz)
    total_imp = 0

    for i in range(batches):
        batch    = rows[i * batch_sz : (i + 1) * batch_sz]
        is_first = (i == 0)
        payload  = {
            "rows":     batch,
            "syncId":   sync_id,
            "clearAll": args.clear and is_first,
        }
        data = None
        for attempt in range(3):
            try:
                data = post_json(api_url, payload, debug=(i == 0 and attempt == 0))
                break
            except Exception as e:
                if attempt == 2:
                    print(f"  ERROR batch {i+1}/{batches}: {e}")
                    sys.exit(1)
                print(f"  Retry {attempt+1}/3: {e}")
                time.sleep(3)
        if data is None:
            print(f"  ERROR batch {i+1}/{batches}: no response after 3 attempts")
            sys.exit(1)
        total_imp += data.get("imported", 0)
        print(f"  Batch {i+1}/{batches}: pushed {len(batch)} rows → imported {data.get('imported',0)}")
        if i < batches - 1 and args.sleep > 0:
            time.sleep(args.sleep)

    print(f"\n✓ Done! Total imported: {total_imp} rows  (syncId: {sync_id})")


if __name__ == "__main__":
    run()
