# Deploying STAGE → PROD

Handover for whoever runs this. Everything needed is in this folder. Written to be followed by a
person with SSMS; nothing here assumes you were in the conversation that produced it.

Regenerated from the live STAGE schema on **30/08/2026**. If more than a few days have passed,
regenerate rather than trusting these files — STAGE moves.

---

## What this deploys

| | |
|---|---|
| New tables | **7** |
| New columns on existing tables | **7** |
| Columns whose type changes | **1** |
| New index | **1** |
| Procedures/functions missing from PROD | **34** |
| Procedures/functions that exist on PROD with a different body | **28** |

## Read this before anything else

**One of these changes fixes a bug that is live in production right now.**

`MeasurmentPointsToOrderDetailsItems.MasterValue` is `DECIMAL(10,8)` on PROD. Precision 10 with
scale 8 leaves *two digits before the decimal point*, so the column cannot hold 100.

A calibrator entering any master reading of 100 or more gets an arithmetic overflow, the save is
rejected, and **nothing on screen says so** — the typed value stays in the box and the row's
`UpdatedDate` still moves, so it looks saved. Master 31-77's certificate runs to 349.98 °C and
others reach 1104, so this is most of the real working range.

It is fixed in tranche A. If you deploy nothing else, deploy that.

## Connection

```
Server    51.17.121.203
Database  CalibratorProd
Login     app_prod
```

The password is in `app/.env` under `REMOTE_DATABASE_URL_PROD`. It is deliberately not written here.

`app_prod` can create and alter objects, and it loaded the data in tranche D. It **cannot** create
SQL Agent jobs: it reaches `msdb` through guest but cannot read `sysjobs`. That needs a one-time
grant from a sysadmin — the last section of this document.

---

## Do not touch these

PROD carries four objects that do **not** exist on STAGE. They are the sync monitoring and they are
live:

```
dbo.usp_SyncHealthCheck
etl.usp_SyncRunEnd
etl.usp_SyncRunReport
etl.usp_SyncRunStart
```

Nothing in these scripts references them. If any step appears to want to drop one, stop — you are
running the wrong file.

---

## Order: A → C → B

The order matters. B and C contain procedures that read the tables, columns and index created in A.
Running them first leaves procedures that compile but fail at runtime with *invalid object name*.

### Step 1 — `01-tranche-A-schema.sql`

Seven `CREATE TABLE`, seven `ALTER TABLE ... ADD`, one `ALTER COLUMN`, one `CREATE INDEX`. Every
statement is guarded by an existence check, so re-running is harmless. Nothing is dropped and no
existing data is rewritten.

Verify before continuing:

```sql
SELECT name FROM sys.tables
WHERE name IN ('CrmDeviceDescription','CustomerPortalRequest','CustomerPortalRequestItem',
               'MeasurmentPointsToCalibrationCycles','OrderApprovalRequest','OrderNote',
               'UserSensorTablePreferences');
-- expect 7 rows

SELECT t.name AS TableName, c.name AS ColumnName
FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
WHERE (t.name = 'MeasurementDevices' AND c.name IN ('WorkRangeMin2','WorkRangeMax2','WorkRangeUnitId2'))
   OR (t.name = 'OrderDetailsItems'  AND c.name IN ('Tolerance','Resolution','SpecificationReferenceIds'))
   OR (t.name = 'Source'             AND c.name  = 'SourceDisplayName');
-- expect 7 rows

-- the bug above
SELECT c.precision, c.scale FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems') AND c.name = 'MasterValue';
-- expect 18, 6      (it was 10, 8)

SELECT name FROM sys.indexes WHERE name = 'IX_MDC_Device_Version_Value';
-- expect 1 row
```

Do not continue until all four return what they should.

### Step 2 — `03-tranche-C-new.sql` — yes, C before B

34 objects that **do not exist on PROD**. Nothing calls them yet, so if one is wrong the blast
radius is zero. Running it before B gets the safe half in and shakes out any missing dependency
from tranche A while nothing is at stake.

Verify:

```sql
SELECT COUNT(*) FROM sys.objects
WHERE type IN ('P','FN','IF','TF','V') AND name IN (
  'GetCalibrationItems','RefreshDeviceDescriptions','fnUnreverseVisualText',
  'fnMasterValueAfterCorrection','fnHumidityAfterCorrection','RefreshPackingDataFromPriority',
  'AddOrderNote','GetOrderNotes','CreateOrderApprovalRequest');
-- expect 9 (a spot check, not the full 34)
```

### Step 3 — `02-tranche-B-changed.sql` — the one that can break something

28 objects that already exist and already serve live screens. **This is the only tranche that can
break what works today.** Everything is `CREATE OR ALTER`, so it is one statement per object and
nothing is dropped.

**Take a copy of the current definitions first. That is the rollback.**

```sql
SELECT o.name, OBJECT_DEFINITION(o.object_id) AS Definition
FROM sys.objects o
WHERE o.type IN ('P','FN','IF','TF','V');
```

Save the result somewhere you can find it. To roll a single object back, run its saved definition
with `CREATE` changed to `CREATE OR ALTER`.

The ones most worth watching, because a live screen depends on each:

| object | what changed, and what it feeds |
|---|---|
| `GetWorkPlanData` | the biggest. Work assignment, both validator screens, calibration history. Placement date is now the earliest of a multi-day job rather than all of them concatenated; the coordinator screen is limited to three months |
| `GetCalibrationValuesForOrderDetailItem` and its `...ForMany` twin | the sensor wizard. `MasterValueAfterCorrection` was the literal string `0_mocked_val` and is now computed |
| `GetDevicesUngroupedByOrder` | packing — hides rows with no delivery note |
| `GetCustomerDashboardData` | the customer portal lobby — Hebrew strings repaired |
| `GetUserNames` | the sign-in dropdown — stops listing 2,099 customer e-mail addresses |
| `AssignProductIdentificationData` | the identification page — three new sensor fields |
| `AssignMeasurmentPointsToOrderDetailsItems` and its V2 | the save path for the reading widened above |
| `stg.MergeOrdersData`, `stg.MergeCustomersContactsData` | the Priority sync |

**One object in this tranche creates permanent tables.** `RefreshCrmTextCache` contains guarded
`CREATE TABLE` statements for `CrmCatalogText`, `CrmDeviceText`, `CrmOrderInstructions` and
`CrmPartInfo`. All four already exist on PROD and hold *more* data than STAGE. The guards mean
deploying the procedure does not touch them.

What you must not do is *run* it as part of this deployment — it repopulates those four caches from
Priority over the linked server and takes around two minutes. Deploy it and leave it on whatever
schedule it already has.

---

## After all three

```sql
-- nothing should come back
SELECT name FROM sys.objects
WHERE type IN ('P','FN','IF','TF','V') AND OBJECT_DEFINITION(object_id) IS NULL;
```

Then open PROD and confirm by eye:

1. **Sign-in page** — the username dropdown lists staff only, roughly 37 entries, not 2,136.
2. **Work assignment** — the table loads and rows appear.
3. **Packing** — the table loads. Expect **fewer rows than before**: items with no delivery note are
   deliberately no longer shown. That is the intended change, not a fault.
4. **Customer portal lobby** — device status reads מחכה לכיול and location reads מעבדה, not `ן¿½`.
5. **Sensor calibration wizard** — the מד אב אחרי קיזוז column shows a number or a dash. If it still
   reads `MOCKED_VAL_0`, tranche B did not apply.
6. **Enter a master reading of 250** and save it. Before this deployment that was impossible.

## What this deployment does not do

* **No SQL Agent job.** See the last section — it needs a one-time grant and is separate.
* **No data migration.** The seven new tables arrive empty, which is correct.
* **No refresh is run.** `RefreshPackingDataFromPriority`, `RefreshDeviceDescriptions` and
  `RefreshCrmTextCache` all land but none is executed. `CrmDeviceDescription` is therefore still
  empty on PROD, which is what the second Agent job is for. Each reads Priority over the linked server
  and writes locally; deciding when to run them on PROD is a separate call.
* ~~Master certificates are not synced.~~ **Done 31/08 in tranche D** — PROD went from 200 to 1,428
  masters carrying a certificate, and from 19,000 orphaned correction rows to none.

## If something fails mid-file

Each object is separated by `GO`, so a failure stops that batch and leaves the earlier ones applied.
Nothing is wrapped in a transaction across objects, on purpose: a half-applied tranche is
recoverable by re-running the file, whereas a long transaction on a live database is not worth the
lock. All three files are safe to re-run from the top.

Read the error before retrying. The one to expect is *invalid object name* in B or C, which means
tranche A did not fully apply — go back to its verification queries.

---

# Step 4 — `04-hotfix-MBA-811-equation.sql`

Added **31/08**, after A, C and B were already on PROD. One object, and it corrects a number the
sensor wizard is showing wrong right now.

`dbo.fnMasterValueAfterCorrection` arrived in tranche C and `GetCalibrationValuesForOrderDetailItem`,
which calls it, arrived in tranche B — so this is live on PROD today.

**What was wrong.** The certificate is a piecewise-linear *fit*: each row of
`MeasurementDevicesCorrections` is a range `[Value1, Value2]` with its own equation. The function
never read `Equation`. It treated `(Value1, Deviation)` as points and interpolated between them,
then held the deviation flat past the last row. `Deviation` is not independent — it is the row's own
equation evaluated at `Value1` — so holding it flat freezes the correction at a range's *left edge*.

Nofar found it on master 31-98 (MBA-811, 31/08). Two faults produced her number:

* ranges were matched `Value1 <= x < Value2`, so the certificate's own top point, 249.96, matched
  no range and was treated as an excursion;
* past the last range the deviation stopped following the fit.

| reading | before | after | |
|---|---|---|---|
| 249.96 | 250.540 | **250.430** | inside the certificate. The old answer was simply wrong |
| 250.00 | 250.580 | **250.470** | 0.04 above the top — the value Nofar measured |
| 251.00 | 251.580 | 251.469 | the old error grew with distance; this one does not |

`OutOfRange` still flags a real excursion. What changed is that the number reported alongside the
warning is the fit continued rather than abandoned.

```powershell
python deploy_prod.py --tranche H
```

**Applied to PROD 31/08.** All four checks green.

Four checks run afterwards. Two of them are the ones that matter:

* it calls the function at every certificate row's `Value1` across the whole database and compares
  the answer with the stored `Deviation`, a column the function does not read. **STAGE 0 of 6,738
  rows disagree, PROD 0 of 1,358.** Anything above 0 is a certificate format the parser does not
  handle — do not accept it. A companion check asserts it looked at more than a hundred rows, because
  a count of 0 is also what an empty database returns;
* it evaluates every certificate at its own highest point and asserts none comes back flagged as an
  excursion. That is the half-open-interval fault stated so any server can answer it. **PROD: 196
  certificates, 0 flagged** — before this hotfix every one of them was.

Nofar's 31-98 numbers are *not* checked here: PROD does not carry that master. They are pinned in
`database/tests/Test-fnMasterValueAfterCorrection.sql`, which runs against STAGE.

Safe to re-run. It is a single `CREATE OR ALTER FUNCTION` and touches no data.

## What this hotfix exposed

PROD carried far less data than STAGE, and the compensation being correct did not help the masters
that had no certificate to compensate against. **Fixed by tranche D below**, 31/08.

---

# Step 5 - `05-tranche-D-data.sql` - the only tranche that loads DATA

**Applied to PROD 31/08. All five checks green.**

```powershell
python deploy_prod.py --tranche D
```

Deliberately excluded from `--all`: A, C, B and H deploy code, this one puts rows in front of
calibrators. Four steps, and the order is not arbitrary.

| | | before | after |
|---|---|---|---|
| 1 | `stg.LoadCustomerContactsFromPriority` - phonebook into staging | 2,506 | 60,370 |
| 2 | `stg.MergeCustomersContactsData` - staging into the live table | 2,571 | **60,375** |
| 3 | `dbo.ImportMissingDevicesFromKyulan` (MBA-902) | 2,070 | **3,491** |
| 4 | the kyulan certificate load (MBA-811) - masters with a certificate | 200 | **1,428** |
| | orphaned correction rows | 19,000 | **0** |

**Step 4 must follow step 3.** PROD held 19,000 orphaned correction rows - 63% of the table, the
same fault the sync repaired on STAGE - but reattaching them without step 3 recovers *seven*
devices: 18,865 of those rows belong to 1,217 MabaIDs PROD did not hold. The certificates had
nowhere to attach until the devices existed.

Master 31-98, the one Nofar tested on, now exists on PROD and reads 250.430 at 249.96 and **250.470
at 250** - the same as STAGE.

## Two things this run found the hard way

**A collation conflict that STAGE cannot reproduce.** `#K` is built by `SELECT INTO` from
`OPENQUERY`, so it carries the *Priority server's* collation (`Hebrew_CI_AS`), not ours
(`Latin1_General_100_CI_AI_SC`). Comparing it to a local `MabaID` fails outright on PROD. Both
databases have the same default collation, so this is a property of the linked-server path, not of
the database - which is why it appeared only in production. Fixed with `COLLATE DATABASE_DEFAULT`
on both sides, which is correct on either server.

**Step 1 does not merge.** `LoadCustomerContactsFromPriority` fills a staging table and stops. The
first run of this tranche omitted step 2, so 60,370 contacts sat in staging, the live table stayed
at 2,571, and the run reported success having changed nothing visible. If contacts look untouched
after this, check `stg.stg_CustomerContacts` before concluding the load failed.

## A difference between the two servers, worth knowing before writing any query

`dbo.Measurements` ids are **not the same on STAGE and PROD**:

| id | PROD | STAGE |
|---|---|---|
| 4 | %RH | degC |
| 5 | degC | degRe |
| 6 | degRe | degF |
| 7 | degF | mV |

So any code, test or ticket that hardcodes a `MeasurementId` is wrong on one of the two servers.
The wizard passes `NULL` and lets `fnMasterValueAfterCorrection` choose, so it is unaffected - but
a deployment check that hardcoded `4` gave a false failure on PROD before this was understood.

---

# The SQL Agent jobs

Separate permission, separate files, and the only part of this deployment `app_prod` cannot do.

```
database/jobs/Grant-SqlAgentJobRights.sql   a sysadmin runs this once
database/jobs/Setup-SqlAgentJobs.sql        creates both jobs; refuses cleanly if it cannot
```

## Why a grant is needed at all

Measured on `CalibratorProd`, 31/08:

```
app_prod    sysadmin 0    serveradmin 0    securityadmin 0    db_owner 1
            SELECT on msdb.dbo.sysjobs: denied
```

`app_prod` reaches `msdb` through guest but cannot read `sysjobs`, cannot create a job, and cannot
see whether the Agent is running. `Grant-SqlAgentJobRights.sql` gives it a user in `msdb` and adds
it to **`SQLAgentUserRole`** - the smallest role that can own and run jobs. A member manages only
the jobs it owns; it cannot see anyone else's, cannot change Agent configuration, cannot create
proxies, and is nowhere near sysadmin. The steps then run as `app_prod` against `CalibratorProd`,
where it is already `db_owner`, so no new rights are needed on the data side.

If policy says application logins own no jobs, skip the grant entirely: connect as a sysadmin and
run `Setup-SqlAgentJobs.sql` with `@OwnerLogin = N'sa'`. Both arrangements work.

## The two jobs

| job | at | runs |
|---|---|---|
| MABA - Refresh packing data from Priority | 02:00 | `dbo.RefreshPackingDataFromPriority` |
| MABA - Refresh device descriptions | 02:30 | `dbo.RefreshDeviceDescriptions` |

The second matters more than it looks: `dbo.CrmDeviceDescription` is **empty on PROD**, and
`dbo.GetCalibrationItems` (MBA-666) returns nothing until it has run at least once.

Both only read from Priority. Nothing is written back to the ERP.

Set `@Database` at the top - it defaults to `CalibratorProd`; use `Calibrator` for STAGE. Safe to
re-run: each job is dropped first.

## It refuses rather than half-succeeding

Run as a login that cannot create jobs, the script reports the reason and writes nothing:

```
Refusing_to_run
This login cannot read msdb.dbo.sysjobs, so it cannot create, see or start a job.
Run database/jobs/Grant-SqlAgentJobRights.sql as a sysadmin, or reconnect as one.

Connected_as | IsSysadmin | CanReadJobs | AgentService                                      | TargetDatabase
app_prod     | False      | False       | unknown - this login cannot read the service list  | CalibratorProd
```

Verified on both servers. Getting that check right took three attempts and each wrong version is
worth knowing, because all three are the obvious thing to write:

* `IS_ROLEMEMBER('SQLAgentUserRole')` answers for the **current** database, not `msdb`;
* `HAS_DBACCESS('msdb')` returns **1** for `app_prod` - guest gets it in - while `SELECT` on
  `sysjobs` is still denied, so the preflight passed and the script died on its first real statement;
* guarding `sys.dm_server_services` on `VIEW SERVER STATE` is the wrong permission. SQL Server 2022
  wants **VIEW SERVER PERFORMANCE STATE**, and `app_prod` holds the first but not the second, so the
  DMV raised anyway.

It now probes the one thing it cannot work without - reading `sysjobs` - and wraps the Agent-state
lookup in `TRY/CATCH` so no permission variant can break the preflight itself.

## Afterwards

Test without waiting for 02:00: SQL Server Agent > Jobs > right-click > **Start Job at Step**.

```sql
-- that they did something
SELECT COUNT(*) FROM dbo.CrmDeviceDescription;   -- expect ~3,000
SELECT COUNT(*) FROM dbo.OrderDetailsItems
WHERE ISNULL(IsDeleted,0)=0 AND CustomerReceivingDate IS NOT NULL;

-- that the Agent ran them
SELECT j.name, h.run_date, h.run_time, h.run_duration,
       outcome = CASE h.run_status WHEN 0 THEN 'failed' WHEN 1 THEN 'succeeded'
                                   WHEN 3 THEN 'cancelled' ELSE 'other' END,
       h.message
FROM msdb.dbo.sysjobs AS j
JOIN msdb.dbo.sysjobhistory AS h ON h.job_id = j.job_id
WHERE j.name LIKE N'MABA - %' AND h.step_id = 0
ORDER BY h.run_date DESC, h.run_time DESC;
```

On STAGE the packing job's first run read 4,414 receipts, dated 3,604 items and flagged 82 order
lines as customer-packed. Expect different numbers on PROD; expect them to be non-zero.
