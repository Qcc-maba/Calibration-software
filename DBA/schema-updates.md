# Schema updates

Proposed and in-progress changes to the Calibrator database schema (STAGE `Calibrator`, PROD
`CalibratorProd`): what is being added or reshaped, why, what was measured, and what is still open.
One section per change, newest first. Dates are absolute (YYYY-MM-DD).

This file is the design record. The objects themselves live under `database/` (see the
`changing-a-database` skill for where each kind of file goes), and the reasoning behind decisions
taken in a session lives in `docs/session<n>-decisions.md`.

| # | Change | Ticket | State |
|---|---|---|---|
| 2 | [Device entity: one row per customer device](#2-device-entity-one-row-per-customer-device) | MBA-996 | Proposed |
| 1 | [Priority calibration status, keyed by `Doc`](#1-priority-calibration-status-keyed-by-doc) | MBA-911 | In progress |

---

## 2. Device entity: one row per customer device

*Proposed 2026-11-09, design detailed 2026-11-10. Ticket: MBA-996. Decisions still open are listed
at the end.*

### The problem

There is no device in this schema. What the screens call a "device" is a row of
`dbo.OrderDetailsItems`, and that row is **one device in one order**: one visit to the lab. It carries
two different kinds of data in the same row:

- **the device's identity:** serial number, manufacturer number, model, additional number, Priority's
  `SERN`;
- **the visit:** `Doc` (Priority's calibration document), `MbaReportNumber`, statuses, calibrators,
  calibration and return dates, results, measurement settings.

So the identity is copied on every visit. A device that comes back every year exists once per year,
and nothing ties the copies together except matching values. Anything that is about the device
itself, across visits, has nowhere to live:

- the customer's device list in the portal (today: order lines grouped by customer + raw serial,
  with the newest `OrderDetailsItemId` as the id, so the id changes on every new order);
- recall, next calibration date and calibration interval;
- the device's history over the years;
- the portal's "add a device" form (MBA-996).

### What exists today

| Object | What it is | Rows (PROD copy 2026-10-21) |
|---|---|---|
| `dbo.OrderDetailsItems` | device-in-an-order (a visit) | 8,668 lines, 8,247 distinct `SERN` |
| `dbo.CustomerDevices` | a device table with the right kind of columns (customer, site, contact, categories, model, serial, interval, next calibration date, report language, specification) | **0**, and no `SERN` column. Only `dbo.CreateCustomerPortalRequest` mentions it |
| `dbo.MeasurementDevices` | MABA's **own** reference standards (masters), not customer devices | 3,491 |
| maba2000-web `mba_records` (PostgreSQL, see `DB-MAPPING-AND-USAGE.md`) | one row per calibration report, unique on `(mba_num, update_num)`, with serial / model / manufacturer copied in | 1,106,156 |

The DBA documents in this folder never propose a device entity. The sync plans use the existing
shape as is: `OrderDetails` = "device group", `OrderDetailsItems` = "item".

### Measured facts that decide the design

- **Priority's `SERN` is the real device key.** `OrderDetailsItems.SERN` = `SERNUMBERS.SERN`, filled
  on every row except manually added ones (8,657 of 8,668 in the 2026-10-21 copy).
- `SERNUMBERS.SERNUM` = customer code (`CUSTOMERS.CUSTNAME`) + `-` + the customer's own serial (100%
  of the latest 20k), and `dbo.Customers.CustomerCode` is that prefix. The own serial can itself be
  compound (`2025-MPL-244(70135180)`, session1 decision 2). The `SERIAL` column is unused.
- Anomalies (PROD, 2026-10-22): 15 `SERN` carry several serial strings, 15 customer+serial pairs map
  to several `SERN`, 3 `SERN` appear under several customers. In Priority itself, 11
  (`CUST`, `SERNUM`) groups have several `SERN`.
- Priority holds 660,776 `SERNUMBERS` rows over 6,496 customers; the app has seen about 9.4k devices.
  On 2026-11-09: 661,855 rows, 28,633 cancelled (`CANCELDATE` > 0), 121 customers with over 1,000
  live devices, the largest 13,060.
- **What Priority keeps per device** (fill rates over the latest 20k devices, 2026-11-09):
  - `SERNUMBERS`: `SERN`, `SERNUM`, `CUST`, `PART` (100%), `CANCELDATE`, `UDATE`. `NEXTMAINTDATE`,
    `LASTMAINTDATE` and `SERIAL` are never filled.
  - `MBA_SERNUMBERS`, MABA's 1:1 extension on `SERN`: `MODEL` 67%, `MNF` (→ `MNFCTR.MNFNAME`) 92%,
    `CALIBMONTH` 100%, `SERNDES` 98%, `MBA_DESCSERNCUST` almost never. **It has no `UDATE`.**
  - `SERNUMBERSTEXT`: free-text notes, already cached per `SERN` in `dbo.CrmDeviceText` by
    `dbo.RefreshCrmTextCache` (one row per `SERN` we hold).
  - The calibration history is not on the device; it sits in the orders and documents that point at it.
- **Change rate:** `SERNUMBERS.UDATE` moved on 949 devices in the last day, 4,472 in a week, 12,282 in
  30 days (2026-11-09). An hourly incremental refresh is small.
- The app's data is young: only 177 devices appear on more than one visit (2026-10-21). That number
  grows every year, since devices come back roughly yearly.
- **One calibration can sit on several rows.** 134 `Doc`s appear on 500 `OrderDetailsItems` rows,
  always the same device but on a different order line (e.g. `Doc` 2505269, report `2608146/14`, on
  rows created 2026-08-04 and 2026-08-17). Item rows are insert-only (the update block of
  `stg.MergeOrdersData` is commented out) and nothing reconciles them.
- Order lines are an incomplete copy of Priority: the order view only looks back 16.7 days, and
  about 5,200 calibrations never arrived (`SYNC-IMPROVEMENT-PLAN.md` §0א). A device register built
  from order lines inherits those gaps.
- No foreign key references `OrderDetailsItems`, but 16 tables and 44 modules use
  `OrderDetailsItemId`.

### Proposed shape

Three levels, each keyed by what the source system uses:

```
Priority SERNUMBERS + MBA_SERNUMBERS (+ MNFCTR, PART)
        │  dbo.RefreshCustomerDevicesFromPriority   (hourly incremental, nightly full)
        ▼
Customers ──< CustomerDevices (one per physical device; PK CustomerDeviceID, unique SERN)
                    │
                    │  joined by SERN at read time - dbo.vwCustomerDevices, nothing stored
                    ▼
              OrderDetailsItems (one per device per order line = a visit; unchanged)
                    │
                    │  joined by Doc
                    ▼
              PriorityCalibrationStatusLog (one per step of a calibration, key: Doc + Kline)   ← MBA-911
```

Not touched: the SSIS pipeline, `stg.MergeOrdersData`, `OrderDetailsItems`' columns, and the 44
staff-side modules that use `OrderDetailsItemId`.

The design rule that keeps this maintainable: **every column has exactly one writer, and there is
exactly one way to read a device.**

#### 1. Table changes on `dbo.CustomerDevices`

The table is empty and nothing reads it, so these cost nothing now and would be painful later.

| Change | Why |
|---|---|
| PK on `CustomerDeviceID` alone (today `(CustomerId, CustomerDeviceID)`) | a single-column id that other tables can reference and the portal can route on |
| `SERN INT NULL`, unique index `WHERE SERN IS NOT NULL` | Priority's device id. NULL = typed by a customer, not registered in Priority yet |
| `SerialKey AS UPPER(LTRIM(RTRIM(SerialNumber))) PERSISTED` | one comparison form, so no procedure re-implements the trimming |
| unique `(CustomerId, SerialKey) WHERE SERN IS NULL AND IsDeleted = 0` | the duplicate rule for customer-typed devices. Not for Priority rows: Priority itself has double registrations (11 groups) that we cannot fix |
| `DeviceDescription NVARCHAR(200)` | Priority's device description (`MBA_SERNUMBERS.SERNDES`), un-reversed for display |
| `IsInactiveInSource BIT NOT NULL DEFAULT 0` | `CANCELDATE` > 0. Separate from `IsDeleted` (session1 decision 17) |
| `SourceUpdatedAt`, `RefreshedAt`, `NeedsReview BIT NOT NULL DEFAULT 0` | freshness, and a flag for rows staff should look at |
| FKs to `CustomerSites` and `CustomerContacts`, `NO ACTION` | ownership enforced by the database, not only by the procedure. `NO ACTION`, never cascade: maba2000's cascading FKs let one delete wipe a whole history (`DB-SCHEMA-REFERENCE.md` §4) |
| index `OrderDetailsItems(SERN)` including `NextCalibrationDate`, `ActualCalibrationDate`, `Doc` | the history join. The only change on the visit table |

#### 2. Who owns which column

The refresh and the portal never write the same column.

| Owner | Columns | Rule |
|---|---|---|
| **Priority** - written only by the refresh | `SERN`, `CustomerId` (from `CUST`), `SerialNumber` (the full `SERNUM`), `OrdersProductTypeId` (from `PART`, matched by name as `stg.MergeOrdersData` does), `Model`, `OrdersDeviceManufacturer` (`MNFCTR.MNFNAME`), `DeviceDescription`, `CalibrationIntervalMonths` (`CALIBMONTH`), `IsInactiveInSource`, `SourceUpdatedAt` | Once a row has a `SERN`, the portal cannot change these. A correction is made in Priority by MABA and arrives with the next refresh |
| **The portal** - written only by `dbo.AssignCustomerDevicesData` | `CustomerSiteId`, `CustomerContactId`, `DeviceLocation`, `ReportLanguage`, categories, specification and units, `IsDeleted` (the customer hides the device) | The refresh never touches these |
| **The portal, until registered** | the Priority-owned columns, on rows with `SERN IS NULL` | handed over to the refresh when the row is claimed (point 4) |

#### 3. The refresh: `dbo.RefreshCustomerDevicesFromPriority`

A copy of the `dbo.RefreshPriorityCalibrationStatus` pattern (change 1), so there is one pattern to
learn:

- `@Apply = 0` (default) is a dry run that reports and writes nothing; `@FullRefresh = 0` is
  incremental, from a watermark on `SERNUMBERS.UDATE`.
- A **nightly full refresh** as well, because `MBA_SERNUMBERS` (model, manufacturer, interval) has no
  `UDATE`, so an edit there may never show in an incremental run.
- Everything inside one `OPENQUERY` (session1 decision 19); text columns `COLLATE DATABASE_DEFAULT`;
  display text through `dbo.fnUnreverseVisualText`, identifiers (`SERNUM`) never.
- `MERGE` that writes only rows that differ, so a second run reports zero. Never deletes: a device that
  disappears upstream is reported.
- SQL Agent: hourly beside the MBA-911 job, plus the nightly full run (`database/jobs/Setup-SqlAgentJobs.sql`).

**What it loads:** every device of every customer we hold, cancelled ones flagged (about 662k rows).
That turns "which devices go in" from a schema decision into a display filter in the view (point 5),
so changing the answer later is one `WHERE`, not a reload. To measure before committing: how long the
full pull takes over the linked server. If it is too slow, the fallback is devices of customers that
have portal contacts.

#### 4. A device typed in the portal joins Priority

1. The customer saves the device: a row with `SERN = NULL`. The duplicate check runs against both
   kinds of row.
2. MABA registers it in Priority, which creates `SERNUM = <CustomerCode>-<serial>`.
3. The refresh finds a Priority device it does not hold yet and looks for a typed row of the same
   customer whose serial matches **by the component rule** (session1 decision 2).
4. Exactly one match: it sets `SERN` on that row. The customer's id is kept, and so are the site and
   contact.
5. More than one: it creates the Priority row and sets `NeedsReview = 1` on the typed one. It never
   guesses.

This is the only string match in the design. It runs once per device, in one procedure.

#### 5. One read path: `dbo.vwCustomerDevices`

One row per device: its own fields, plus its latest visit by `SERN` (last calibration, next
calibration date, latest report, current Priority status from change 1) and its visit count.
`GetCustomerDeviceList` and `GetCustomerDeviceDetail` become thin selects from it, filtered by
`dbo.GetPortalCustomerIds`, and later screens (recall, dashboards) read the same view. The display
rules live only here:

- hidden: `IsInactiveInSource = 1` or `IsDeleted = 1`;
- shown for now: devices with at least one visit, or typed in the portal. That keeps today's list
  until the whole register is wanted;
- visits are limited to the caller's own customers, which settles the devices that moved between
  customers.

#### 6. Ids and the portal

- `/customer/devices/[id]` becomes `CustomerDeviceID`, the same across visits. Report and calibration
  links keep `OrderDetailsItemId`, because they are about a visit.
- `CustomerPortalRequestItem` gains a nullable `CustomerDeviceID`, so a request can name a device that
  was never calibrated.
- `dbo.GetPortalCustomerIds` keeps counting devices through order lines: no change to sign-in in this
  work.

#### 7. Order of work

| Phase | Content | Visible to customers |
|---|---|---|
| 1 | table changes, refresh, view, SQL Agent job, a `database/tests` file; STAGE, then PROD | no |
| 2 | list and detail procedures read the view; the app switches its route (portal developer) | same list, stable ids |
| 3 | `AssignCustomerDevicesData` follows the ownership rules and the duplicate check; the add-device form is wired | the form works |
| 4 | requests reference a device | requests for new devices |

Each phase ships on its own and leaves the system working.

### How it relates to MBA-911

MBA-911 does not need this entity and does not wait for it. Priority records calibration status per
**calibration document** (`Doc`), not per device, so the status table is keyed by `Doc`
(change 1 below). The two fit together: devices join their visits by `SERN`, and visits join their
status by `Doc`.

### Open questions (for MBA-996)

1. **Load everything, filter in the view** (point 3): accepted, subject to measuring the full pull?
2. **Portal edits to Priority-owned fields** of a registered device are refused (point 2): accepted?
3. **The 134 calibrations on two order lines:** a sync defect to fix, or a real business case (the same
   device on two order lines)? The view must show one visit per `Doc` until this is settled.
4. **Whether this is one ticket or two:** phases 1-2 could be split out of MBA-996's add-device form.

Settled by this design: a device that moved shows only its visits under the caller's customers
(point 5), and the portal's device id becomes `CustomerDeviceID` (point 6).

---

## 1. Priority calibration status, keyed by `Doc`

*In progress since 2026-11-09. Ticket: MBA-911. Branch `MBA-911-priority-calibration-status`.*

### The problem

Every work plan on PROD shows "waiting for calibration" (3,144 of 3,144 on 2026-10-07), because nothing
carries Priority's calibration progress into this database:

- the order view does bring a "current status" into `stg_Orders.CurrentCalibrationStatus`, but
  `stg.MergeOrdersData` drops it (its joins are commented out, because they match on
  `dbo.Statuses.Code`, which is empty);
- that view picks the latest step by `CDATE`. A `CD` row is dated at midnight of the calibration day,
  so for 1,799 of 33,958 recent `Doc`s (5.3%) its "current" status is not the latest step. It also
  only covers documents opened in the last 25 days.

Until the Calibrator app rolls out (February 2027), every device is calibrated in MABA 2000, so
Priority's log is the only real progress there is.

### What is added

| Object | File | Purpose |
|---|---|---|
| `dbo.PriorityCalibrationStatusCodes` | `database/procedures/dbo.PriorityCalibrationStatusCodes.table.sql` | the 22 Priority codes plus our meaning: English text, who writes it, stage, matching order status **by name** |
| seed | `database/data/Seed-PriorityCalibrationStatusCodes.sql` | the English half of the codes table |
| `dbo.PriorityCalibrationStatusLog` | `database/procedures/dbo.PriorityCalibrationStatusLog.table.sql` | mirror of `MBA_CALIBSTATSLOG` for the `Doc`s we hold, key `(Doc, Kline)` |
| `dbo.PriorityCalibrationStatusFetch` | `database/procedures/dbo.PriorityCalibrationStatusFetch.table.sql` | per-`Doc` marker of a whole-log fetch, so a `Doc` with an empty Priority log is not refetched every hour |
| `dbo.RefreshPriorityCalibrationStatus` | `database/procedures/dbo.RefreshPriorityCalibrationStatus.sql` | fills both, read-only against Priority, incremental by `UDATE`; writes serialised (application lock + `HOLDLOCK`); reports `UnseededCodes` |
| `dbo.vwOrderDetailsItemsPriorityStatus` | `database/procedures/dbo.vwOrderDetailsItemsPriorityStatus.sql` | per device row: current Priority status and the dates of the main steps |
| SQL Agent job | `database/jobs/Setup-SqlAgentJobs.sql` | hourly at :20 |

### Design decisions

- **Keyed by `Doc` + `Kline`, not by our row.** `(DOC, KLINE)` is unique in Priority (746,015 rows,
  746,015 distinct over `DOC` > 2,400,000), and `KLINE` always follows insertion order. 134 `Doc`s sit on
  several of our rows, so a per-row status could disagree with itself.
- **Separate from the app's own statuses.** `OrderDetailsItems.CalibrationStatusId` /
  `CalibrationReportStatusId` belong to the app's workflow (`dbo.AssignOrderItemsStatus`: InCalibration,
  AwaitingSignature, ...). Priority's status gets its own table, so neither overwrites the other, and
  Priority's codes do not map one-to-one to the app's statuses anyway.
- **Statuses by name, never by id.** `dbo.Statuses` ids differ between STAGE and PROD by one
  (WaitingForCalibration is 76 on STAGE, 75 on PROD).
- **Read Priority directly, not through the order sync.** Same precedent as change 2's point 2. This
  also fixes the `CDATE` ordering without touching the view.
- **Never delete.** A step that disappears upstream is reported by a full refresh, not removed.

### Phase 2: the outbox (report-only)

The app reports its own calibration steps through one procedure, which checks them and records them.
Nothing is sent to Priority yet, in any mode.

| Object | File | Purpose |
|---|---|---|
| `dbo.PriorityStatusWriteMode` | `database/procedures/dbo.PriorityStatusWriteMode.table.sql` | one-row switch: `Off` (kill switch) or `ReportOnly`. A CHECK constraint makes `Send` impossible until phase 3 adds the sender |
| `dbo.PriorityStatusOutbox` | `database/procedures/dbo.PriorityStatusOutbox.table.sql` (needs `QUOTED_IDENTIFIER ON`: filtered unique index) | one row per app event, key `(Doc, StatusCode, EventKey)` for accepted rows; refused rows kept with their reason |
| `dbo.RecordPriorityStatusEvent` | `database/procedures/dbo.RecordPriorityStatusEvent.sql` | the app's only entry point; returns `OutboxId, Doc, StatusCode, State, Reason, IsDuplicate` |
| test | `database/tests/Test-RecordPriorityStatusEvent.sql` | 33 checks, all inside rolled-back transactions |

The rules the procedure enforces:
- **Idempotency** by the app's `EventKey`.
- **Only the app's codes:** those marked `AppMayWrite` in the codes table. Priority's own codes (`AA`, `TX`, `PI`, `CO`, `KM`) are refused, and so is everything if the seed never ran.
- **Ownership:** a calibration belongs to the program it was opened in. `AC` is refused when MABA 2000
  already worked on the `Doc`, and every other code needs the app's `AC`. This is the "one device, one
  program" rule. It fails closed: a step whose code is not known to be Priority's own counts as MABA 2000's.
- **One `AC` and one `CD` per `Doc`.**
- **Nothing but update-report codes after `TX`,** plus the signatures (`H1`, `H2`, `HR`) of an update report.
- **The signature chain:** `H1` needs a report, `H2` and `HR` need `H1`, and after `HR` a new report.
- **Holds:** no hold twice in a row, and resume only after a hold.

A refusal is returned, not thrown, so a user's action never fails because of Priority reporting. Calls are
serialised per `Doc`; if the lock cannot be had, the call throws instead of carrying on unlocked.

### Not in this change

- The roll-up of device statuses into `OrderWorkPlans.OrderOverallStatusId` (needs a decision on the
  rule, and on the `CO` meaning, asked on MBA-911).
- Sending to Priority (phase 3): the sender, the `Send` mode and the sending states. It waits for STAGE
  to move to Priority's test company `s190225`. Before sending, phase 3 must also re-check ownership:
  the log mirror is refreshed hourly, so a MABA 2000 start in the last hour is not visible to the
  outbox.
- Reopening a calibration after it was completed (MABA 2000 sometimes records a second `AC`). The
  outbox allows one `AC` per `Doc` until the lab says how reopening should work.
