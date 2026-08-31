"""
Runs the STAGE -> PROD deployment in this folder, in the order RUNBOOK.md specifies.

    python deploy_prod.py --check            what is missing, writes nothing
    python deploy_prod.py --tranche A        one tranche
    python deploy_prod.py --all              A, then C, then B, verifying between

Why a script rather than pasting the files into SSMS: it stops at the first failed batch instead
of ploughing on, it runs the RUNBOOK's verification queries between tranches, and it prints one
line per object so a partial run is obvious. Everything it does is in the three .sql files - this
only sequences them.

Order is A -> C -> B and that is deliberate. B is the only tranche that can break something that
works today, so it goes last, after A's schema is in and C has proved the new objects compile
against it.

The connection comes from app/.env (REMOTE_DATABASE_URL_PROD). No credential is written here.

Nothing is wrapped in a transaction across objects, on purpose: a half-applied tranche is
recoverable by re-running the file, whereas a long transaction on a live database is not worth
the lock. Every statement in tranche A is guarded, and B and C are CREATE OR ALTER, so all three
files are safe to re-run from the top.
"""
import argparse
import os
import re
import sys

try:
    import pyodbc
except ImportError:
    sys.exit("pyodbc is required:  pip install pyodbc")

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ENV = os.path.join(REPO, "app", ".env")

TRANCHES = [
    ("A", "01-tranche-A-schema.sql", "schema - tables, columns, one widening, one index"),
    ("C", "03-tranche-C-new.sql", "objects PROD does not have yet - nothing calls them"),
    ("B", "02-tranche-B-changed.sql", "objects PROD already has - the only risky tranche"),
]

CHECKS = {
    "A": [
        ("7 new tables", """
            SELECT COUNT(*) FROM sys.tables WHERE name IN
              ('CrmDeviceDescription','CustomerPortalRequest','CustomerPortalRequestItem',
               'MeasurmentPointsToCalibrationCycles','OrderApprovalRequest','OrderNote',
               'UserSensorTablePreferences')""", 7),
        ("7 new columns", """
            SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
            WHERE (t.name='MeasurementDevices' AND c.name IN ('WorkRangeMin2','WorkRangeMax2','WorkRangeUnitId2'))
               OR (t.name='OrderDetailsItems'  AND c.name IN ('Tolerance','Resolution','SpecificationReferenceIds'))
               OR (t.name='Source'             AND c.name='SourceDisplayName')""", 7),
        # These were added after the first round. The check list did not cover them, so tranche A
        # reported "ok" while they were missing, and tranche C then failed on Invalid column name
        # 'IsPrimary'. A verification that only looks at part of a tranche is worse than none.
        ("6 later columns", """
            SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
            JOIN sys.schemas s ON s.schema_id = t.schema_id
            WHERE (t.name='CustomerContacts'     AND c.name IN ('IsPrimary','DoNotMail'))
               OR (t.name='stg_CustomerContacts' AND c.name IN ('IsPrimary','DoNotMail'))
               OR (t.name='MeasurementDevices'   AND c.name IN ('AllowMinOutOfRange','AllowMaxOutOfRange'))""", 6),
        ("MasterValue widened to (18,6)", """
            SELECT COUNT(*) FROM sys.columns c
            WHERE c.object_id=OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems')
              AND c.name='MasterValue' AND c.precision=18 AND c.scale=6""", 1),
        ("correction index present", """
            SELECT COUNT(*) FROM sys.indexes WHERE name='IX_MDC_Device_Version_Value'""", 1),
    ],
    "C": [
        ("the new objects compile", """
            SELECT COUNT(*) FROM sys.objects WHERE type IN ('P','FN','IF','TF','V') AND name IN
              ('GetCalibrationItems','RefreshDeviceDescriptions','fnUnreverseVisualText',
               'fnMasterValueAfterCorrection','fnHumidityAfterCorrection',
               'RefreshPackingDataFromPriority')""", 6),
    ],
    "B": [
        ("no object left without a definition", """
            SELECT COUNT(*) FROM sys.objects
            WHERE type IN ('P','FN','IF','TF','V') AND OBJECT_DEFINITION(object_id) IS NULL""", 0),
        ("the mocked literal is gone", """
            SELECT COUNT(*) FROM sys.sql_modules WHERE definition LIKE '%mocked_val%'""", 0),
    ],
}


def connection_string():
    if not os.path.exists(ENV):
        sys.exit(f"cannot find {ENV}")
    with open(ENV, encoding="utf-8", errors="ignore") as fh:
        m = re.search(r'REMOTE_DATABASE_URL_PROD\s*=\s*"?([^"\r\n]+)', fh.read())
    if not m:
        sys.exit("REMOTE_DATABASE_URL_PROD is not in app/.env")
    raw = m.group(1)
    parts = dict(
        p.split("=", 1) for p in raw.split("sqlserver://")[-1].split(";") if "=" in p
    )
    server = raw.split("sqlserver://")[-1].split(";")[0]
    return (
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={server};DATABASE={parts.get('database')};"
        f"UID={parts.get('user')};PWD={parts.get('password')};"
        "Encrypt=yes;TrustServerCertificate=yes"
    )


def batches(path):
    with open(path, encoding="utf-8", newline="") as fh:
        return [b.strip() for b in re.split(r"(?im)^\s*GO\s*$", fh.read()) if b.strip()]


def label(batch):
    stripped = re.sub(r"/\*.*?\*/", "", batch, flags=re.S)
    return " ".join(stripped.split())[:74]


def verify(cur, tranche):
    print(f"  -- verifying {tranche}")
    good = True
    for name, sql, expected in CHECKS.get(tranche, []):
        cur.execute(sql)
        got = cur.fetchone()[0]
        mark = "ok  " if got == expected else "FAIL"
        if got != expected:
            good = False
        print(f"     {mark} {name}: expected {expected}, got {got}")
    return good


PLAIN_CREATE = re.compile(
    r"^[ \t]*CREATE[ \t]+(?!OR[ \t]+ALTER)(PROCEDURE|PROC|FUNCTION|VIEW)\b",
    re.IGNORECASE | re.MULTILINE,
)


def inspect(path, bs):
    """Refuse a file that would fail halfway through, rather than finding out on PROD.

    Two faults cost three failed runs before this existed. A plain CREATE on an object PROD
    already has stops with "There is already an object named X" - it happened to GetWorkPlanData,
    whose comment header mentions CREATE OR ALTER in prose, so a naive rewrite of the first match
    in the text changed the sentence and left the statement alone. And a procedure that reads a
    column from a table-valued function has to come after it, or it fails on Invalid column name.
    """
    problems = []
    for i, b in enumerate(bs, 1):
        m = PLAIN_CREATE.search(b)
        if m:
            problems.append(f"batch {i} uses a plain {m.group(1).upper()}, which cannot re-apply")

    order = [i for i, b in enumerate(bs)
             if re.search(r"(?im)^[ \t]*CREATE OR ALTER[ \t]+(FUNCTION|PROCEDURE)", b)]
    first_proc = next((i for i in order
                       if re.search(r"(?im)^[ \t]*CREATE OR ALTER[ \t]+PROCEDURE", bs[i])), None)
    last_func = max((i for i in order
                     if re.search(r"(?im)^[ \t]*CREATE OR ALTER[ \t]+FUNCTION", bs[i])), default=None)
    if first_proc is not None and last_func is not None and last_func > first_proc:
        problems.append("a function is created after a procedure; functions must come first")
    return problems


def run(cur, code, filename, note, dry):
    path = os.path.join(HERE, filename)
    bs = batches(path)
    print(f"\n=== tranche {code} - {note}")
    print(f"    {filename}, {len(bs)} batches")

    problems = inspect(path, bs)
    if problems:
        print("    refusing to run - the file itself is wrong:")
        for p in problems:
            print(f"      {p}")
        return False
    if dry:
        return True
    failed = 0
    for i, b in enumerate(bs, 1):
        try:
            cur.execute(b)
        except Exception as exc:  # noqa: BLE001 - the message is what matters
            failed += 1
            print(f"    {i:>3} FAIL  {label(b)}")
            print(f"         {str(exc)[:200]}")
            print(f"\n  stopping: tranche {code} failed at batch {i}. "
                  "Fix the cause and re-run - the file is safe to run again from the top.")
            return False
    print(f"    {len(bs)} batches applied")
    return verify(cur, code)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tranche", choices=["A", "B", "C"])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--check", action="store_true",
                    help="run the verification queries only, write nothing")
    args = ap.parse_args()

    cn = pyodbc.connect(connection_string(), autocommit=True)
    cur = cn.cursor()
    cur.execute("SELECT DB_NAME(), SUSER_SNAME()")
    db, who = cur.fetchone()
    print(f"connected to {db} as {who}")
    if db.lower() != "calibratorprod":
        sys.exit(f"refusing to run against {db} - this script is for CalibratorProd")

    if args.check:
        for code, _, _ in TRANCHES:
            verify(cur, code)
        return

    todo = TRANCHES if args.all else [t for t in TRANCHES if t[0] == args.tranche]
    if not todo:
        sys.exit("choose --tranche A|B|C, or --all, or --check")

    for code, filename, note in todo:
        if not run(cur, code, filename, note, dry=False):
            sys.exit(1)

    print("\ndone. Now check by eye, per RUNBOOK.md: the sign-in dropdown, work assignment, "
          "packing, the portal lobby, the sensor wizard, and saving a master reading of 250.")


if __name__ == "__main__":
    main()
