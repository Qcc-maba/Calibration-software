"""
Runs the STAGE -> PROD deployment in this folder, in the order RUNBOOK.md specifies.

    python deploy_prod.py --check            what is missing, writes nothing
    python deploy_prod.py --tranche A        one tranche
    python deploy_prod.py --tranche H        the MBA-811 compensation hotfix on its own
    python deploy_prod.py --tranche D        the DATA loads - never part of --all
    python deploy_prod.py --all              A, then C, then B, then H, verifying between

Why a script rather than pasting the files into SSMS: it stops at the first failed batch instead
of ploughing on, it runs the RUNBOOK's verification queries between tranches, and it prints one
line per object so a partial run is obvious. Everything it does is in the .sql files alongside it -
this only sequences them.

Order is A -> C -> B and that is deliberate. B is the only tranche that can break something that
works today, so it goes last, after A's schema is in and C has proved the new objects compile
against it.

The connection comes from app/.env (REMOTE_DATABASE_URL_PROD). No credential is written here.

Nothing is wrapped in a transaction across objects, on purpose: a half-applied tranche is
recoverable by re-running the file, whereas a long transaction on a live database is not worth
the lock. Every statement in tranche A is guarded, and B, C and H are CREATE OR ALTER, so every
file is safe to re-run from the top.
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
    # Added 31/08 after the three tranches were already on PROD. Standalone on purpose: it is one
    # object, it corrects a number the wizard is showing wrong right now, and it must be runnable
    # without re-running anything else.
    ("H", "04-hotfix-MBA-811-equation.sql",
     "MBA-811 - compensation reads the range EQUATION instead of interpolating between points"),
    ("U", "06-hotfix-MBA-666-unreverse.sql",
     "MBA-666 - a space between two LTR runs is inside the span, not a separator"),
    # The only tranche that loads DATA rather than code, so it is last and it is not in --all.
    # Run it deliberately: python deploy_prod.py --tranche D
    ("D", "05-tranche-D-data.sql",
     "MBA-922/902/811 - the Priority phonebook, the kyulan instruments, their certificates"),
]

# --all deploys code. D puts rows in front of calibrators and is a decision, not a step.
CODE_TRANCHES = [t for t in TRANCHES if t[0] != "D"]

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
    "H": [
        ("compensation evaluates the range equation", """
            SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fnMasterValueAfterCorrection'))
                             LIKE '%TRY_CAST(t.CoefTxt AS FLOAT)%' THEN 1 ELSE 0 END""", 1),
        # The real check, and it takes about half a minute. Deviation is each row's own Equation
        # evaluated at Value1, and the function does not read that column - so calling it at Value1
        # must reproduce it. Any row it cannot parse, or matches to the neighbouring range, shows
        # up here. On STAGE this is 0 of 6,738 rows.
        ("no certificate row disagrees with its stored Deviation", """
            WITH Ranked AS (
                SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value1, c.Deviation,
                       Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
                FROM dbo.MeasurementDevicesCorrections AS c
                WHERE ISNULL(c.IsDeleted,0)=0 AND c.Equation IS NOT NULL AND c.Deviation IS NOT NULL),
            Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
            Single AS (SELECT MeasurementDevicesId FROM Newest
                       GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1)
            SELECT COUNT(*)
            FROM Newest AS n
            JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId
            CROSS APPLY dbo.fnMasterValueAfterCorrection(n.MeasurementDevicesId, n.Value1, n.MeasurementId) AS f
            WHERE f.Deviation IS NULL OR ABS(f.Deviation - n.Deviation) > 0.0001""", 0),
        # A count of 0 is also what an empty database returns. STAGE checks 6,738 rows and PROD
        # 1,358, so anything under a hundred means the check above passed by looking at nothing.
        ("...and it looked at more than a hundred of them", """
            WITH Ranked AS (
                SELECT c.MeasurementDevicesId, c.MeasurementId,
                       Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
                FROM dbo.MeasurementDevicesCorrections AS c
                WHERE ISNULL(c.IsDeleted,0)=0 AND c.Equation IS NOT NULL AND c.Deviation IS NOT NULL),
            Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
            Single AS (SELECT MeasurementDevicesId FROM Newest
                       GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1)
            SELECT CASE WHEN (SELECT COUNT(*) FROM Newest AS n
                              JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId)
                             > 100 THEN 1 ELSE 0 END""", 1),
        # The fault itself, stated so that any server can answer it. Ranges used to be matched
        # Value1 <= x < Value2, so every certificate's own highest point fell outside every range
        # and was reported as an excursion. Nofar's 31-98 is not the right check to ship here - PROD
        # does not carry that master, and a check that cannot run is a check nobody reads. Her three
        # numbers are pinned in database/tests/Test-fnMasterValueAfterCorrection.sql instead.
        ("no certificate's own top point reads as an excursion", """
            WITH Ranked AS (
                SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value2,
                       Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
                FROM dbo.MeasurementDevicesCorrections AS c
                WHERE ISNULL(c.IsDeleted,0)=0 AND c.Equation IS NOT NULL AND c.Value2 IS NOT NULL),
            Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
            Single AS (SELECT MeasurementDevicesId FROM Newest
                       GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1),
            Tops AS (SELECT n.MeasurementDevicesId, n.MeasurementId, n.Value2,
                            rn = ROW_NUMBER() OVER (PARTITION BY n.MeasurementDevicesId ORDER BY n.Value2 DESC)
                     FROM Newest AS n JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId)
            SELECT COUNT(*) FROM Tops AS t
            CROSS APPLY dbo.fnMasterValueAfterCorrection(t.MeasurementDevicesId,
                            CAST(t.Value2 AS DECIMAL(18,6)), t.MeasurementId) AS f
            WHERE t.rn = 1 AND (f.Extrapolated = 1 OR f.OutOfRange = 1)""", 0),
    ],
    # Baselines these are measured against, PROD 31/08 before tranche D:
    #   devices 2,070   masters with a certificate 200   contacts 2,571   orphaned rows 19,000
    "U": [
        ("the space fix is deployed", """
            SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.fnUnreverseVisualText'))
                             LIKE '%A SPACE BETWEEN TWO LTR RUNS%' THEN 1 ELSE 0 END""", 1),
        # An English device name whose words were in reverse order, and a Hebrew-context dash that
        # must NOT be pulled into the number beside it. One of each, because the two rules push in
        # opposite directions and a version that satisfies only one looks right on half the data.
        ("an English phrase keeps its word order", """
            SELECT CASE WHEN dbo.fnUnreverseVisualText(N'ALUMIS EGRAHCSID CITATSORTCELE')
                             = N'ELECTROSTATIC DISCHARGE SIMULA' THEN 1 ELSE 0 END""", 1),
        ("a dash between Hebrew and a number stays put", """
            SELECT CASE WHEN dbo.fnUnreverseVisualText(N'רכש פריטים נלווים - 528691')
                             = N'רכש פריטים נלווים - 196825' THEN 1 ELSE 0 END""", 1),
        ("punctuation between two Hebrew words is not reversed", """
            SELECT CASE WHEN dbo.fnUnreverseVisualText(N'בקר טמפ''+רגש')
                             = N'בקר טמפ''+רגש' THEN 1 ELSE 0 END""", 1),
    ],
    "D": [
        ("the kyulan instruments arrived", """
            SELECT CASE WHEN (SELECT COUNT(*) FROM dbo.MeasurementDevices
                              WHERE ISNULL(IsDeleted,0)=0) > 3400 THEN 1 ELSE 0 END""", 1),
        # The point of doing devices before certificates. Before tranche D this was 19,000; a
        # reattach without the devices would have left 18,865 of them.
        ("no correction row is left orphaned", """
            SELECT COUNT(*) FROM dbo.MeasurementDevicesCorrections
            WHERE ISNULL(IsDeleted,0)=0 AND MeasurementDevicesId IS NULL""", 0),
        ("masters carrying a certificate, was 200", """
            SELECT CASE WHEN (SELECT COUNT(DISTINCT MeasurementDevicesId)
                              FROM dbo.MeasurementDevicesCorrections
                              WHERE ISNULL(IsDeleted,0)=0) > 1000 THEN 1 ELSE 0 END""", 1),
        ("the phonebook grew past its 2,571 baseline", """
            SELECT CASE WHEN (SELECT COUNT(*) FROM dbo.CustomerContacts
                              WHERE ISNULL(IsDeleted,0)=0) > 2571 THEN 1 ELSE 0 END""", 1),
        # The compensation must still answer correctly on the certificates that just landed - the
        # same whole-database property tranche H asserts, re-run over a much larger population.
        ("every new certificate row still reproduces its Deviation", """
            WITH Ranked AS (
                SELECT c.MeasurementDevicesId, c.MeasurementId, c.Value1, c.Deviation,
                       Rnk = RANK() OVER (PARTITION BY c.MeasurementDevicesId ORDER BY c.CorVersion DESC)
                FROM dbo.MeasurementDevicesCorrections AS c
                WHERE ISNULL(c.IsDeleted,0)=0 AND c.Equation IS NOT NULL AND c.Deviation IS NOT NULL),
            Newest AS (SELECT * FROM Ranked WHERE Rnk = 1),
            Single AS (SELECT MeasurementDevicesId FROM Newest
                       GROUP BY MeasurementDevicesId HAVING COUNT(DISTINCT MeasurementId) = 1)
            SELECT COUNT(*)
            FROM Newest AS n
            JOIN Single AS s ON s.MeasurementDevicesId = n.MeasurementDevicesId
            CROSS APPLY dbo.fnMasterValueAfterCorrection(n.MeasurementDevicesId, n.Value1, n.MeasurementId) AS f
            WHERE f.Deviation IS NULL OR ABS(f.Deviation - n.Deviation) > 0.0001""", 0),
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
    ap.add_argument("--tranche", choices=["A", "B", "C", "H", "U", "D"])
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

    todo = CODE_TRANCHES if args.all else [t for t in TRANCHES if t[0] == args.tranche]
    if not todo:
        sys.exit("choose --tranche A|B|C|H|U|D, or --all, or --check")

    for code, filename, note in todo:
        if not run(cur, code, filename, note, dry=False):
            sys.exit(1)

    print("\ndone. Now check by eye, per RUNBOOK.md: the sign-in dropdown, work assignment, "
          "packing, the portal lobby, the sensor wizard, and saving a master reading of 250.")


if __name__ == "__main__":
    main()
