# Deploying STG → PROD — runbook

Handover for whoever runs this, human or agent. Everything needed is in this folder.

**Before anything: this needs a way to execute T-SQL against the server.** A browser on its own
cannot do it. If you are Claude in Chrome, you need a web-based SQL console open and logged in —
driving SSMS is not something a browser extension can do. If there is no such console, this is a
runbook for a person with SSMS, and that is fine; every step below is written to be followed by
hand.

---

## What this is

`Calibrator` (STAGE) has drifted ahead of `CalibratorProd`. This deploys the difference.

| | |
|---|---|
| New tables | **6** |
| New columns | **6** — 3 on `dbo.MeasurementDevices`, 3 on `dbo.OrderDetailsItems` |
| Procedures that exist on PROD with a different body | **24** |
| Procedures missing from PROD entirely | **28** |

Generated from the live STAGE definitions, not from the repository, so what lands on PROD is
exactly what is running on STAGE today.

## Connection

```
Server    51.17.121.203
Database  CalibratorProd
Login     app_prod
```

The password is in `app/.env` under `REMOTE_DATABASE_URL_PROD`. It is not written here.

`app_prod` can create and alter objects. It **cannot** create SQL Agent jobs — that needs
`sysadmin`, and it is not part of this deployment.

---

## Do not touch these

PROD carries four objects and one table that do **not** exist on STAGE. They are the sync
monitoring, and they are live:

```
dbo.usp_SyncHealthCheck
etl.usp_SyncRunEnd
etl.usp_SyncRunReport
etl.usp_SyncRunStart
etl.SyncRunLog          (table)
```

Nothing in these scripts references them. If any step appears to want to drop one, stop — the
script has been edited or you are running the wrong file.

---

## Order

The order matters. Tranche B and C contain procedures that read the tables and columns created in
A. Running B or C first will leave procedures that compile but fail at runtime with "invalid
object name".

### 1 — `01-tranche-A-schema.sql`

Six `CREATE TABLE` and three `ALTER TABLE ... ADD`. Purely additive: nothing is dropped, nothing
existing is altered, no data is touched. Every statement is guarded by an existence check, so
re-running is harmless.

Check afterwards:

```sql
SELECT name FROM sys.tables
WHERE name IN ('CustomerPortalRequest','CustomerPortalRequestItem',
               'MeasurmentPointsToCalibrationCycles','OrderApprovalRequest',
               'OrderNote','UserSensorTablePreferences');
-- expect 6 rows

SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.MeasurementDevices')
  AND name IN ('WorkRangeMin2','WorkRangeMax2','WorkRangeUnitId2');
-- expect 3 rows

SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.OrderDetailsItems')
  AND name IN ('Tolerance','Resolution','SpecificationReferenceIds');
-- expect 3 rows  (MBA-577)
```

Do not continue until all three return the full count.

### 2 — `03-tranche-C-new.sql` — yes, C before B

C is 28 procedures that **do not exist on PROD**. Nothing calls them yet, so if one is wrong the
blast radius is zero. Running it before B gets the safe half in and shakes out any missing
dependency from tranche A while nothing is at stake.

Check afterwards:

```sql
SELECT COUNT(*) FROM sys.objects WHERE type = 'P' AND name IN (
  'AddOrderNote','GetOrderNotes','DeleteOrderNote','CreateCustomerPortalRequest',
  'GetCustomerPortalRequestList','ResolveCustomerPortalRequest','DuplicateCustomerDevice',
  'CreateOrderApprovalRequest','GetOrderApprovalDetails','GetOrderApprovalRequestByToken',
  'ResolveOrderApprovalRequest','SetOrderApprovalPriorityResult','RefreshPackingDataFromPriority',
  'RefreshCustomerRemarksFromPriority');
-- expect 14 (a spot check, not the full 28)
```

### 3 — `02-tranche-B-changed.sql` — the one that actually changes behaviour

24 procedures that already exist and already serve live screens. **This is the only tranche that
can break something that works today.** Everything is `CREATE OR ALTER`, so it is one statement per
object and no drops.

Among them, the ones most worth watching because a live screen depends on them:

| procedure | what changed and what it feeds |
|---|---|
| `GetWorkPlanData` | the biggest one. Work assignment, both validator screens, calibration history |
| `GetDevicesUngroupedByOrder` | packing — now hides rows with no delivery note, 5,000 → 2,391 on STAGE |
| `GetCustomerDashboardData` | the customer portal lobby — Hebrew strings repaired |
| `GetUserNames` | the sign-in dropdown — stops listing 2,099 customer e-mail addresses |
| `GetAllCalibrationDevices` | the logger popup. **Needs the three new columns from tranche A** |
| `stg.MergeOrdersData`, `stg.MergeCustomersContactsData` | the Priority sync |

**One procedure in this tranche creates permanent tables.** `RefreshCrmTextCache` contains guarded
`CREATE TABLE` statements for `CrmCatalogText`, `CrmDeviceText`, `CrmOrderInstructions` and
`CrmPartInfo`. All four already exist on PROD and hold **more data than STAGE** — 7,695 device texts
against 3,668, 2,763 order instructions against 1,189. The guards mean deploying the procedure does
not touch them.

What you must not do is *run* it as part of this deployment. It repopulates those four caches from
Priority over the linked server and takes around two minutes. Deploy it, leave it alone, and let it
run on whatever schedule it already runs on.

**Take a copy of the current definitions before you run it.** That is the rollback:

```sql
SELECT o.name, OBJECT_DEFINITION(o.object_id) AS Definition
FROM sys.objects o
WHERE o.type IN ('P','FN','IF','TF','V');
```

Save the result. To roll a single procedure back, run its saved definition with `CREATE` changed to
`CREATE OR ALTER`.

---

## After all three

```sql
-- nothing should come back
SELECT name, OBJECT_DEFINITION(object_id) AS d
FROM sys.objects
WHERE type = 'P' AND OBJECT_DEFINITION(object_id) IS NULL;
```

Then open PROD and confirm by eye:

1. **Sign-in page** — the username dropdown lists staff only, roughly 37 entries, not 2,136.
2. **Work assignment** — the table loads and rows appear.
3. **Packing** — the table loads. Expect **fewer rows than before**: items with no delivery note
   are deliberately no longer shown. That is the intended change, not a fault.
4. **Customer portal lobby** — device status reads מחכה לכיול and location reads מעבדה, not `ן¿½ן¿½ן¿½ן¿½`.

---

## What this deployment does not do

* **No SQL Agent job.** `RefreshPackingDataFromPriority` lands but nothing schedules it. That is
  `database/jobs/Job.RefreshPackingDataFromPriority.sql`, it needs `sysadmin`, and it is separate.
* **No data migration.** The six new tables arrive empty, which is correct — they are all new
  features with nothing to carry over.
* **`RefreshPackingDataFromPriority` is not run.** On STAGE it filled 3,604 receiving dates and
  flagged 82 order lines as customer-packed. Deciding whether to run it on PROD is a separate call;
  it reads Priority over the linked server and writes to `OrderDetailsItems` and `OrderDetails`.
  It has a `@ReportOnly = 1` mode — use that first.

## If something fails mid-file

Each object is separated by `GO`, so a failure stops that batch and leaves the earlier ones
applied. Nothing is wrapped in a transaction across objects, on purpose: a half-applied tranche is
recoverable by re-running the file, whereas a giant transaction on a live database is not worth the
lock. All three files are safe to re-run from the top.

Read the error before retrying. The one to expect is *invalid object name* in B or C, which means
tranche A did not fully apply — go back and check its two verification queries.
