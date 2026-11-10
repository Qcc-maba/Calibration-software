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
  - `MBA_SERNUMBERS`, MABA's 1:1 extension on `SERN`: `MODEL` 67%, `MNF` (→ `MNFCTR.MNFDES`; `MNFNAME` is a code such as `AUTO7422`) 92%,
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
| `DeviceDescription NVARCHAR(200)` | Priority's device description (`MBA_SERNUMBERS.SERNDES`), in logical order through `tabula_hebconvert` |
| `DevicePart INT`, `DeviceTypeName NVARCHAR(100)` | the device's own Priority part (`SERNUMBERS.PART`) and its `PARTDES`. Not `OrdersProductTypeId`: that is a calibration **service** (`OrdersProductTypes` holds 680 service parts, "... - accredited calibration at your site"), and a device's part never equals its order line's (0 of 5,617 on STAGE, 2026-11-10) |
| `IsInactiveInSource BIT NOT NULL DEFAULT 0` | `CANCELDATE` > 0. Separate from `IsDeleted` (session1 decision 17) |
| `SourceUpdatedAt`, `RefreshedAt`, `NeedsReview BIT NOT NULL DEFAULT 0` | freshness, and a flag for rows staff should look at |
| FKs to `CustomerSites` and `CustomerContacts`, on `(CustomerId, …)` because their keys are composite, `NO ACTION` | ownership enforced by the database, not only by the procedure: a device's site and contact belong to the device's own customer. `NO ACTION`, never cascade: maba2000's cascading FKs let one delete wipe a whole history (`DB-SCHEMA-REFERENCE.md` §4) |
| index `OrderDetailsItems(SERN)` including `NextCalibrationDate`, `ActualCalibrationDate`, `Doc` | the history join. The only change on the visit table |

#### 2. Who owns which column

The refresh and the portal never write the same column.

| Owner | Columns | Rule |
|---|---|---|
| **Priority** - written only by the refresh | `SERN`, `CustomerId` (from `CUST`), `SerialNumber` (the full `SERNUM`), `Model`, `OrdersDeviceManufacturer` (`MNFCTR.MNFDES`), `DevicePart` and `DeviceTypeName` (`PART`, `PARTDES`), `DeviceDescription`, `CalibrationIntervalMonths` (`CALIBMONTH`), `IsInactiveInSource`, `SourceUpdatedAt` | Once a row has a `SERN`, the portal cannot change these. A correction is made in Priority by MABA and arrives with the next refresh. `OrdersProductTypeId` and `NextCalibrationDate` are never written for a registered row: the first is a service, the second comes from the latest visit |
| **The portal** - written only by `dbo.AssignCustomerDevicesData` | `CustomerSiteId`, `CustomerContactId`, `DeviceLocation`, `ReportLanguage`, categories, specification and units, `IsDeleted` (the customer hides the device) | The refresh never touches these |
| **The portal, until registered** | the Priority-owned columns, on rows with `SERN IS NULL` | handed over to the refresh when the row is claimed (point 4) |

**Decided 2026-11-10: a registered device's Priority-owned fields change only in Priority.** The
portal form can send six of them - `SerialNumber`, `Model`, `OrdersDeviceManufacturer`,
`OrdersProductTypeId`, `CalibrationIntervalMonths` and, through the chosen site, `CustomerId` - plus
`NextCalibrationDate`, which for a registered device comes from its latest visit, not from the
device. On a row with a `SERN` all seven are refused. If the portal ever needs to change one of them,
the decision is reopened; until then nothing in our code writes them except the refresh.

Two layers enforce it:

1. **`dbo.AssignCustomerDevicesData` refuses with error 54208** ("managed by MABA") when an edit would
   change one of them on a registered device. This is the message the customer sees; the form shows
   these fields read-only.
2. **A trigger on `dbo.CustomerDevices` is the backstop**, for any other procedure, data fix or bug.
   It rejects a change to a Priority-owned column on a row with a `SERN`, unless the session carries
   the flag the refresh sets around its writes and clears right after, on error too:
   `EXEC sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';`. Deliberately not
   `@read_only = 1`: a read-only key can never be cleared, so after one manual run in an SSMS window
   every later edit in that window would pass the trigger. It also refuses every `DELETE`, and an
   `INSERT` or `UPDATE` that sets `SERN` or a Priority copy on any row.

The flag guards against our own mistakes, not against someone who can already run arbitrary SQL:
such a session could set it too. The tighter variant also requires `ORIGINAL_LOGIN()` to be the
login the SQL Agent job runs under, which no other connection can fake; its cost is that a manual
repair must run under that login as well. **Decided 2026-11-10: the flag alone.** What keeps the
portal from running SQL of its own is its EXECUTE-only login (point 7.1); if that check fails, add the
login check as well.

Column permissions cannot do this job: inside a procedure owned by `dbo`, ownership chaining skips
the column check, so a `DENY UPDATE` on the portal login never takes effect.

#### 3. The refresh: `dbo.RefreshCustomerDevicesFromPriority`

A copy of the `dbo.RefreshPriorityCalibrationStatus` pattern (change 1), so there is one pattern to
learn:

- `@Apply = 0` (default) is a dry run that reports and writes nothing; `@FullRefresh = 0` is
  incremental, from a watermark on `SERNUMBERS.UDATE`.
- A **nightly full refresh** as well, because `MBA_SERNUMBERS` (model, manufacturer, interval) has no
  `UDATE`, so an edit there may never show in an incremental run.
- Everything inside one `OPENQUERY` (session1 decision 19); text columns `COLLATE DATABASE_DEFAULT`,
  and `CAST(... AS NVARCHAR)` on the Priority side first - `VARCHAR` Hebrew pushed through a Latin
  collation turns into `?`. Display text (`MNFDES`, `SERNDES`, `PARTDES`) through Priority's own
  `tabula_hebconvert`, as the order sync does: our `fnUnreverseVisualText` turns "KERN & SOHN" into
  "SOHN & KERN" (5,082 of 5,617 manufacturers match the order lines after the conversion, 388
  without). Identifiers (`SERNUM`) and `MODEL` as stored: 5,475 and 5,452 of 5,617 match unchanged.
- **`system.dbo.tabula_hebconvert` throws on NULL** (`NullReferenceException` in
  `HebrewFilterFull`), and a device with no `MBA_SERNUMBERS` row has a NULL `SERNDES` after the
  `LEFT JOIN`. Wrap it: `tabula_hebconvert(ISNULL(m.SERNDES, ''))`. Without that, one such device
  fails the whole run.
- Writes only rows that differ, so a second run reports zero; inserts go in chunks of 50,000, each
  its own transaction, so the first load (about 590k rows) is not one transaction. Never deletes.
- **Which customer.** `dbo.Customers` holds 747 Priority customers twice (STAGE: 11,286 rows,
  10,539 distinct `CustomerIdFromSource`); the second row is a different company carrying the same
  `CustomerIdFromSource` (CUST 2 is both "מ.ב.א - בדיקות אימות" and "A.M.L"). In all 747 exactly one
  row's `CustomerCode` equals Priority's `CUSTNAME`, so a device goes to that row. The wrong rows
  are a defect of the customer sync, outside this work.
- **A device that moved to another customer in Priority:** `CUST` wins; site and contact belong to
  the old customer, so they are cleared and the row gets `NeedsReview = 1`.
- SQL Agent: hourly beside the MBA-911 job, plus the nightly full run (`database/jobs/Setup-SqlAgentJobs.sql`).

**What it loads:** the devices of active customers that are not cancelled - 592,157 of 662,117
(Priority, 2026-11-10: 633,462 not cancelled; 6,010 of 6,504 customers active by
`CUSTSTATS.INACTIVE`). A device already held that is cancelled later is still updated by the
incremental run and gets `IsInactiveInSource = 1`; nothing is deleted. Cancelled devices and inactive
customers are never shown, so they are not copied.

Limiting the load to customers with portal contacts was considered and rejected: the portal is not
released yet, and most customers are expected to use it once it is, so that rule would grow to nearly
the whole register while adding a membership rule and an onboarding delay. Protection belongs in the
read path (point 7), not in the row count.

Measured 2026-11-10, directly on Priority (AWS was unreachable from the workstation): the full query
(SERNUMBERS + MBA_SERNUMBERS + MNFCTR + `tabula_hebconvert`) takes **9.3 s** on Priority's side and
returns about **50 MB**. Still to measure on STAGE: the same pull across the AWS - Priority link. If
it is too slow, the nightly full run becomes weekly and the hourly incremental carries the rest (about
950 devices change a day).

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
- visits are limited to the device's own customer, which settles the devices that moved between
  customers (simpler than "the caller's customers", and the caller only sees the device when its
  customer is theirs).

Checked locally on the STAGE copy with the register loaded: 5,593 of the 5,617 visits with a `SERN`
find their device; the other 24 are devices cancelled in Priority, which today's list already hides.
For the busiest customers the view shows exactly what `GetCustomerDeviceList` shows today.

#### 6. Ids and the portal

- `/customer/devices/[id]` becomes `CustomerDeviceID`, the same across visits. Report and calibration
  links keep `OrderDetailsItemId`, because they are about a visit.
- `CustomerPortalRequestItem` already has a nullable `CustomerDeviceID`, and
  `dbo.CreateCustomerPortalRequest` already accepts `@CustomerDeviceId`, so a request can name a
  device that was never calibrated once the ids are stable.
- `dbo.GetPortalCustomerIds` keeps counting devices through order lines: no change to sign-in in this
  work.

#### 7. Who can read a device

The table will hold the asset list of every active customer, so one portal procedure with a wrong
customer filter would show one customer another's devices. The rules that prevent it:

1. **The portal's SQL login can only `EXECUTE` procedures** - no `SELECT` on tables or on
   `dbo.vwCustomerDevices`. Not verified yet; check it before phase 2. If the login can read tables,
   every filter below can be bypassed.
2. **One filter, in one place.** Every portal procedure that returns devices filters through
   `dbo.GetPortalCustomerIds(@Email)`. No procedure writes its own customer filter.
3. **`@Email` comes from the app's signed-in session, never from the browser.** App side; confirm with
   the portal developer for the device procedures.
4. **A test that fails on a leak.** A `database/tests` file calls each portal device procedure as a
   contact of customer A and asserts that no row of customer B comes back.
5. **Later, if 1-4 prove insufficient:** row-level security on `CustomerDevices`, so SQL Server filters
   rows even when a procedure forgets to.

#### 8. Order of work

| Phase | Content | Visible to customers |
|---|---|---|
| 1 | table changes, refresh, view, SQL Agent job, a `database/tests` file; STAGE, then PROD | no |
| 2 | check the portal login (point 7.1); list and detail procedures read the view, with the leak test (point 7.4); the app switches its route (portal developer) | same list, stable ids |
| 3 | `AssignCustomerDevicesData` follows the ownership rules (error 54208) and the duplicate check; the add-device form is wired, Priority-owned fields read-only on registered devices | the form works |
| 4 | requests reference a device | requests for new devices |

Each phase ships on its own and leaves the system working.

**Phase 1 status (2026-11-10): written and tested locally, not deployed.** Files:
`database/procedures/dbo.CustomerDevices.table.sql`, `dbo.trCustomerDevices_PriorityOwned.sql`,
`dbo.fnSerialAlnum.sql`, `dbo.RefreshCustomerDevicesFromPriority.sql`, `dbo.vwCustomerDevices.sql`;
two jobs in `database/jobs/Setup-SqlAgentJobs.sql`; `database/tests/Test-CustomerDevices.sql`;
rollback `database/_rollback/BOTH.MBA-996.phase1.before.sql`. On the local STAGE copy, with
Priority's device tables copied in: the first load inserts 591,279 devices in 25 s, a second full run
and an hourly run report zero changes, the 16 tests pass and leave the table unchanged, and the
rollback restores the original table exactly. Still to do on STAGE: the pull time across the
AWS - Priority link, and the portal login check (point 7.1). The compound-serial claim (tier 2) is
written but had no live case to test against.

### How it relates to MBA-911

MBA-911 does not need this entity and does not wait for it. Priority records calibration status per
**calibration document** (`Doc`), not per device, so the status table is keyed by `Doc`
(change 1 below). The two fit together: devices join their visits by `SERN`, and visits join their
status by `Doc`.

### Open questions (for MBA-996)

1. **The 134 calibrations on two order lines:** a sync defect to fix, or a real business case (the same
   device on two order lines)? The view must show one visit per `Doc` until this is settled.
2. **Whether this is one ticket or two:** phases 1-2 could be split out of MBA-996's add-device form.

Settled by this design: a device that moved shows only its visits under the caller's customers
(point 5), the portal's device id becomes `CustomerDeviceID` (point 6), and the load covers every
active customer's live devices, protected in the read path (points 3 and 7; decided 2026-11-10), and
a registered device's Priority-owned fields change only in Priority, guarded by the refresh's session
flag (point 2; decided 2026-11-10).

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
