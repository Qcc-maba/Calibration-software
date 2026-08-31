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

`app_prod` can create and alter objects. It **cannot** create SQL Agent jobs — that needs
`sysadmin`, and it is a separate task at the end of this document.

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

* **No SQL Agent job.** See the section below — it needs `sysadmin` and is separate.
* **No data migration.** The seven new tables arrive empty, which is correct.
* **No refresh is run.** `RefreshPackingDataFromPriority`, `RefreshDeviceDescriptions` and
  `RefreshCrmTextCache` all land but none is executed. Each reads Priority over the linked server
  and writes locally; deciding when to run them on PROD is a separate call.
* **Master certificates are not synced.** `database/sync/Load-MeasurementDevicesCorrections-FromKyulan.sql`
  took STAGE from 189 to 1,433 masters carrying a certificate. It has not been run against PROD and
  should be reviewed there on its own.

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

## What this hotfix exposed, and did not fix

PROD carries far less certificate data than STAGE:

| | PROD | STAGE |
|---|---|---|
| masters | 2,070 | 3,418 |
| masters with a certificate | **200** | **1,434** |

The compensation is now correct on PROD for the 200 masters that have a certificate. The other 1,870
still show a dash, and 31-98 — the master Nofar tested with — is not on PROD at all.

**Running the certificate sync on PROD would not fix this, and the order matters.** PROD carries
19,000 orphaned correction rows, 63% of its table, the same fault the sync repaired on STAGE. But
reattaching them recovers only **7 devices**: 18,865 of those rows belong to 1,217 MabaIDs that PROD
does not hold. Its device registry is a strict subset of STAGE's — 1,994 shared, **0 that PROD has
and STAGE does not**, 1,424 that exist on STAGE alone.

Those 1,424 are MBA-902. `dbo.ImportMissingDevicesFromKyulan` was run on STAGE and never on PROD.
Both it and the certificate sync are already deployed to PROD (tranche C); neither has been executed
there. The dry run against PROD reports the same figures as STAGE did:

```
WouldCreate  StillInCalibrationDate  Sensors  DataLoggers  WithWorkRange  UnitCouldNotBeMapped
       1421                     848     1216          102           1344                     0
```

So the order is **devices first, certificates second** — the reverse recovers almost nothing:

```sql
EXEC dbo.ImportMissingDevicesFromKyulan @Apply = 0;   -- reports, writes nothing
EXEC dbo.ImportMissingDevicesFromKyulan @Apply = 1;
```
then `database/sync/Load-MeasurementDevicesCorrections-FromKyulan.sql`.

Both are insert-only and safe to re-run, but this creates 1,421 rows visible to calibrators in
production. It is a decision, not a deployment step, and it has not been taken.

---

# The SQL Agent job

Separate task, separate permission. `app_prod` cannot do this; you need an account with
`SQLAgentUserRole` in `msdb`, or `sysadmin`.

The script is `../jobs/Job.RefreshPackingDataFromPriority.sql`.

## What the job does

Runs `dbo.RefreshPackingDataFromPriority` nightly at 02:00. That procedure follows
`OrderDetailsItems.DOC_N` to the Priority goods-receipt document (`TYPE = 'N'`) and brings back two
fields the sync never carried: whether the device arrived in the customer's own packaging
(`MBA_CUSTPACK`) and the date we booked it in. Without a schedule both fields freeze at whatever the
last manual run produced.

It only reads from Priority. Nothing is written back to the ERP.

## How to run it

1. Open SSMS and connect to `51.17.121.203` with an account that has `SQLAgentUserRole` in `msdb`,
   or `sysadmin`.
2. **Check SQL Server Agent is running** — Object Explorer, bottom node. If it shows a red stop
   icon, right-click and Start. A job on a stopped Agent never fires and says nothing.
3. Open the script. **Change `@Database` from `Calibrator` to `CalibratorProd`** — it is declared at
   the top and defaults to STAGE.
4. Execute. It targets `msdb`; do not switch the database dropdown.
5. Test it: SQL Server Agent → Jobs → *MABA - Refresh packing data from Priority* → right-click →
   Start Job at Step. It should finish in under a minute and report success.

The script drops the job first if it already exists, so it is safe to re-run.

**Do not create this job on PROD until `RefreshPackingDataFromPriority` has been deployed there** —
it arrives in tranche C. A job pointing at a procedure that does not exist fails every night.

## Checking it afterwards

```sql
SELECT j.name, h.run_date, h.run_time, h.run_duration,
       outcome = CASE h.run_status WHEN 0 THEN 'failed'
                                   WHEN 1 THEN 'succeeded'
                                   WHEN 3 THEN 'cancelled' ELSE 'other' END,
       h.message
FROM msdb.dbo.sysjobs AS j
JOIN msdb.dbo.sysjobhistory AS h ON h.job_id = j.job_id
WHERE j.name = N'MABA - Refresh packing data from Priority' AND h.step_id = 0
ORDER BY h.run_date DESC, h.run_time DESC;
```

And that the data actually moved:

```sql
SELECT COUNT(*) AS ItemsWithReceivingDate
FROM dbo.OrderDetailsItems
WHERE ISNULL(IsDeleted,0) = 0 AND CustomerReceivingDate IS NOT NULL;

SELECT CustomerPackingExists, COUNT(*) AS Details
FROM dbo.OrderDetails WHERE ISNULL(IsDeleted,0) = 0
GROUP BY CustomerPackingExists;
```

On STAGE the first run read 4,414 receipts, dated 3,604 items and flagged 82 order lines as
customer-packed. Expect different numbers on PROD; expect them to be non-zero.

## A second job worth scheduling, once someone owns it

`dbo.RefreshDeviceDescriptions` rebuilds the calibration-item list from Priority
(`MBA_DOCLOAD.SERNDES` — 3,000 device descriptions). It is pure T-SQL with no external dependency,
so it can be scheduled the same way. It is not in the job script; add a second job for it when the
list is confirmed in use.
