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

*Proposed 2026-11-09. Ticket: MBA-996. Design to be settled there.*

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
- `SERNUMBERS.SERNUM` = customer name + `-` + the customer's own serial (100% of the latest 20k),
  and `dbo.Customers.CustomerCode` is that prefix. The `SERIAL` column is unused.
- Anomalies (PROD, 2026-10-22): 15 `SERN` carry several serial strings, 15 customer+serial pairs map
  to several `SERN`, 3 `SERN` appear under several customers. In Priority itself, 11
  (`CUST`, `SERNUM`) groups have several `SERN`.
- Priority holds 660,776 `SERNUMBERS` rows over 6,496 customers; the app has seen about 9.4k devices.
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
Customers ──< CustomerDevices (one per device, key: Priority SERN)
                    │
                    │  joined by SERN at read time
                    ▼
              OrderDetailsItems (one per device per order line = a visit)
                    │
                    │  joined by Doc
                    ▼
              PriorityCalibrationStatusLog (one per step of a calibration, key: Doc + Kline)   ← MBA-911
```

1. **`dbo.CustomerDevices`, keyed by Priority `SERN`.** Add a unique `SERN` column (the existing
   table has none). The device's identity (serial, manufacturer number, model, customer, site)
   lives here once.
2. **Fill it from Priority's device register (`SERNUMBERS`), not from order lines,** through its own
   `OPENQUERY` refresh procedure, the same way `dbo.RefreshCustomerStatusFromPriority` reads Priority
   directly instead of going through the sync (session1 decision 6, session3 decision 67). That
   avoids inheriting the order view's window and its missing calibrations.
3. **Priority retiring a device is a flag, not a delete:** `SERNUMBERS.CANCELDATE` maps to
   `IsInactiveInSource` (session1 decision 17; `IsDeleted` stays this system's own soft delete).
4. **History by join, not by copying.** A device's visits are the `OrderDetailsItems` rows with its
   `SERN` (index `OrderDetailsItems.SERN`). The visit rows keep their own copy of the identity fields
   for now, so the 44 modules that read them keep working; removing the copies is a later step, if
   ever.
5. **A customer typing a serial** (portal "add a device") is matched with the component rule from
   session1 decision 2: customer prefix + own serial, and an ambiguous match is refused rather than
   guessed.

### How it relates to MBA-911

MBA-911 does not need this entity and does not wait for it. Priority records calibration status per
**calibration document** (`Doc`), not per device, so the status table is keyed by `Doc`
(change 1 below). The two fit together: devices join their visits by `SERN`, and visits join their
status by `Doc`.

### Open questions (for MBA-996)

1. **Which devices go in:** Priority's whole register (660k rows, every device any customer ever had)
   or only devices seen in our orders (about 9.4k)? The portal list and recall need different answers.
2. **A device that moved** between customers (3 `SERN`s today): whose history does it show?
3. **The portal's device id** is today the newest `OrderDetailsItemId`. Moving to `CustomerDeviceID`
   changes an id the app already uses.
4. **The 134 calibrations on two order lines:** a sync defect to fix, or a real business case (the same
   device on two order lines)? Decide before the visit level is relied on for history.
5. **Whether this is one ticket or two:** the device layer could be split out of MBA-996's
   add-device form.

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
| `dbo.RefreshPriorityCalibrationStatus` | `database/procedures/dbo.RefreshPriorityCalibrationStatus.sql` | fills both, read-only against Priority, incremental by `UDATE` |
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
| `dbo.PriorityStatusOutbox` | `database/procedures/dbo.PriorityStatusOutbox.table.sql` | one row per app event, key `(Doc, StatusCode, EventKey)` for accepted rows; refused rows kept with their reason |
| `dbo.RecordPriorityStatusEvent` | `database/procedures/dbo.RecordPriorityStatusEvent.sql` | the app's only entry point; returns `OutboxId, Doc, StatusCode, State, Reason, IsDuplicate` |
| test | `database/tests/Test-RecordPriorityStatusEvent.sql` | 28 checks, all inside a rolled-back transaction |

The rules the procedure enforces:
- **Idempotency** by the app's `EventKey`.
- **Only the app's codes:** Priority's own codes (`AA`, `TX`, `PI`, `CO`, `KM`) are refused.
- **Ownership:** a calibration belongs to the program it was opened in. `AC` is refused when MABA 2000
  already worked on the `Doc`, and every other code needs the app's `AC`. This is the "one device, one
  program" rule.
- **One `AC` and one `CD` per `Doc`.**
- **Nothing but update-report codes after `TX`.**
- **The signature chain:** `H1` needs a report, `H2` and `HR` need `H1`, and after `HR` a new report.
- **Holds:** no hold twice in a row, and resume only after a hold.

A refusal is returned, not thrown, so a user's action never fails because of Priority reporting.

### Not in this change

- The roll-up of device statuses into `OrderWorkPlans.OrderOverallStatusId` (needs a decision on the
  rule, and on the `CO` meaning, asked on MBA-911).
- Sending to Priority (phase 3): the sender, the `Send` mode and the sending states. It waits for STAGE
  to move to Priority's test company `s190225`. Before sending, phase 3 must also re-check ownership:
  the log mirror is refreshed hourly, so a MABA 2000 start in the last hour is not visible to the
  outbox.
- Reopening a calibration after it was completed (MABA 2000 sometimes records a second `AC`). The
  outbox allows one `AC` per `Doc` until the lab says how reopening should work.
