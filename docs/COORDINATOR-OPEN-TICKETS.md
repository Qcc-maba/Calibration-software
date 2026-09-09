# שלושת הטיקטים החסרים — מסך שיבוץ עבודה

מקור: שרשור "משימות לאריאלה" (לילך שוואט, 22/03/2026 ואילך).
שלוש הבקשות האלה נותרו ללא טיקט במשך כחמישה חודשים. נפתחו ב-30/08/2026 כ-MBA-930, MBA-931, MBA-933.

החלטות שהתקבלו ב-30/08/2026 מגולמות בפנים:

1. נספחים — גם חילוץ הצרופות וגם המרה ל-PDF.
2. רכב / כייל / ציוד נשמרים בנפרד; התאריך נשמר יחד עם הרכב.
3. "באג ROMAN" — לא מזוהה, מתעלמים בינתיים (MBA-882 מכסה את התסמין הגלוי).

---

## MBA-930 — Story

https://calibration-maba.atlassian.net/browse/MBA-930

**Summary:** Work file: show the order's Priority attachments to the calibrator, converted to PDF

### User story

As a calibrator opening a work file, I want to see every document attached to the order in Priority — rendered as PDF — so that I can read the customer's purchase order and instructions on a tablet without Outlook.

Requested by Lilach (22/03/2026 list, item 3, priority 1). Conversion-to-PDF decision taken 30/08/2026.

### Where the data is — verified on PROD via the linked server

```sql
SELECT e.EXTFILENAME, e.EXTFILEDES, e.LINE
FROM   [31.168.173.93].amaba.dbo.EXTFILES e
JOIN   [31.168.173.93].amaba.dbo.ORDERS   o ON o.ORD = e.IV
WHERE  e.TYPE = 'O' AND o.ORDNAME = @orderNumber
```

`EXTFILES.TYPE = 'O'` with `IV = ORDERS.ORD` is the order-to-attachment link. This answers the open question "where are the annexes pulled from" — no further investigation needed.

| Measure | Value |
| --- | --- |
| Orders carrying attachments | 13,175 |
| Total files | 15,251 |
| Files per order | up to 4 (`LINE` 0-3) |
| Location | `\\maba-priority\Priority\Attachments\Documents\YYYY\MM\<timestamp>.<ext>` |

### Why this is not simply "link the file"

| Extension | Count |
| --- | --- |
| **.msg (Outlook messages)** | **15,144 — 99.3%** |
| .pdf | 62 |
| .htm | 5 |
| .xlsx / .xls | 4 |
| .tif / .jpeg | 2 |
| truncated names (.ms / .m / .pd) | 34 |

Linking the raw files hands the calibrator a mailbox, not a work file. Only 62 files in the entire system are already PDF.

### Acceptance criteria

1. New column on the work assignment screen (שיבוץ עבודה) with a file button: **red** when the order has at least one attachment, **grey** when it has none. Reuse the icon pattern from MBA-803.
2. Clicking opens the order's attachment list, each entry labelled with `EXTFILEDES`.
3. Every file is served to the calibrator **as PDF**, whatever its source format.
4. For a `.msg`, the PDF contains the message body **and** each attachment carried inside it, each converted in turn. Neither the mail text nor the enclosed purchase order may be dropped.
5. **Conversion happens on demand and is cached** — not an up-front backfill of 15,251 files. Most orders will never be opened.
6. A file that cannot be reached or converted shows an explicit error entry in the list. It must never be silently omitted — the calibrator has to know a document exists that they cannot see.
7. `EXTFILEDES` is stored reversed on some rows (same trap as `ORDERSTEXT`). Render it correctly rather than showing mirrored Hebrew.

### Known data problems

- **34 files are unreachable by design.** `EXTFILES.EXTFILENAME` is `varchar(80)` and Priority truncates longer paths — those rows end in `.ms`, `.m`, `.pd`. They surface under AC #6. The truncation is on the Priority side; do not try to repair it here.
- **Share access.** The application pool identity must be able to read `\\maba-priority\Priority\Attachments\`. Confirm before development starts — the Instruction Assistant service already lost time to exactly this, running as LocalSystem and unable to reach `\\maba-dc`.

### Open decision — needed before development starts

**Which conversion engine:** LibreOffice headless (no licence cost, must be installed and managed on the server) versus a commercial library such as Aspose (licence cost, simpler deployment). This drives both the estimate and the running cost.

### Estimate

6-8 working days once the engine is chosen.

---

## MBA-931 — Story

https://calibration-maba.atlassian.net/browse/MBA-931

**Summary:** Work assignment screen: assign several orders in one action, each with its own time window

### User story

As a coordinator on the work assignment screen (שיבוץ עבודה, `/coordinator-orders`), I want to select several orders and assign them together in one action, each order carrying its own time window, so that I can dispatch a whole day's route without reopening the dialog per order.

Confirmed with Lilach (02/06/2026): orders selected together receive **the same time, calibrator and equipment**. Priority between them is expressed by which of the 4 time windows each order is assigned to. Ordering *inside* the customer site is the calibrator's own decision — **out of scope**.

### The 4 time windows already exist — do not build a new mechanism

| What | Where | State |
| --- | --- | --- |
| The 4 windows | `dbo.CarsToOrder.AssignQuater0..3` (bit x4, note the existing typo "Quater") | Live, 196 active rows |
| Write path | `dbo.AssignCarToOrder` / `dbo.EditCarAssigmentToOrder`, `@QuartersOfDay` CSV `'0,1,2,3'` | Working |
| FE selector | `availabilityQuartersCount = 4`, `CarAssignmentTable.tsx` | Working — reuse it |

Real usage on PROD: of 196 active rows, Q0=165, Q1=159, Q2=128, Q3=118, all four=102. The windows are in genuine use, not a dormant field.

### No schema change is required

Each assignable value already has its own table, anchored only to itself and the order. This matches the rule confirmed on 30/08/2026 — an order may carry a car, or a calibrator, or equipment, independently; the **date is saved together with the car**.

| Value | Table | NOT NULL | Nullable |
| --- | --- | --- | --- |
| Car + date + windows | `CarsToOrder` | `CarId`, `AssignDate`, `OrderWorkPlanId` | quarters |
| Calibrator | `CalibratorsToWorkPlan` | `CalibratorId`, `OrderWorkPlanId` | `CarId`, `AssigmentDate` |
| Equipment | `MeasurementDevicesToOrderHeaders` | `MeasurementDeviceId`, `OrderWorkPlanId` | `CarId`, `AssigmentDate` |

The gap is only that `dbo.AssignCalibratorsToOrder` takes a single `@OrderNumber NCHAR(12)`.

### Acceptance criteria

1. Checkbox column on the work assignment table allows selecting 2 or more orders. A header checkbox selects/clears all rows currently filtered.
2. With at least one order selected, a "שבץ נבחרים" action opens the batch assignment dialog. With none selected the action is disabled.
3. The dialog sets **calibrator, car+date and equipment once** for the whole batch — one control each, not per order.
4. Any of the three may be left empty. A partial assignment is valid and saves.
5. The dialog lists each selected order on its own row (order number, customer, catalog description) with its **own 4-window selector**, reusing the existing quarters component. Default: all four selected, matching today's single-order behaviour.
6. The window selector is enabled only when a car and date are being assigned, because the windows live on `CarsToOrder`. Without a car there is nothing to attach a window to.
7. Saving writes, in **one transaction**, per order: a `CarsToOrder` row carrying that order's `AssignQuater0..3`, a `CalibratorsToWorkPlan` row, and a `MeasurementDevicesToOrderHeaders` row — each only for the values actually filled in. Partial success is not acceptable: if any order fails, none are written and the coordinator is told which one failed and why.
8. Orders already assigned for that date are **updated, not duplicated** — follow the existing `@exists` upsert logic in `AssignCarToOrder`.
9. An order that is cancelled or inactive blocks the save with a named error.
10. Orders that received a car and a date appear on `external-schedule`. Orders with only a calibrator or only equipment stay visible on the coordinator screen and do not appear there.
11. After saving, the table refreshes and each assigned order shows its new values and windows.
12. Single-order assignment (MBA-791) keeps working unchanged.
13. Unit tests cover: mixed windows across a batch, a batch containing an already-assigned order, a partial assignment, and the rollback path in AC #7.

### Out of scope

- Ordering the work *inside* the customer site — the calibrator decides.
- Grouping of catalog numbers within an order (MBA-805). That rule operates on catalog numbers inside a single order, a different axis from selecting several orders; the two do not interact.

### Files and procedures involved

| Item | Change |
| --- | --- |
| `dbo.AssignCalibratorsToOrder` | batch variant taking a CSV of order numbers, or a TVP |
| `dbo.AssignCarToOrder` | reuse per order inside the batch transaction |
| `src/components/coordinator-orders-table/` | selection column + "שבץ נבחרים" action |
| `src/components/calibrator-assignment-dialog/` | batch mode, per-order window rows |
| `src/server/api/routers/orders/` | batch mutation |
| `he.json` / `en.json` | new strings |

### Bug to fix while in here

`AssignCarToOrder` validates the windows with `SUM(QuarterId) > 6`, which accepts duplicates (`'3,3'` sums to 6) and out-of-range ids (`'6'` sums to 6), while a legitimate `'0,1,2,3'` also sums to exactly 6. Validate instead that every value is distinct and in the range 0-3.

### Estimate

3-4 working days.

---

## MBA-933 — Story

https://calibration-maba.atlassian.net/browse/MBA-933

**Summary:** Pull Priority data into the coordinator screen every 5-7 minutes

### User story

As a coordinator, I want the work assignment screen to reflect Priority within 5-7 minutes of a change, so that I am not scheduling against stale orders.

Requested by Lilach (22/03/2026 list, item 11, priority 2).

### Current state

There is no scheduled refresh on this path. `database/jobs/Job.RefreshPackingDataFromPriority.sql` is the only committed SQL Agent job and it runs **nightly**, for packing data only. The CRM text caches (`CrmCatalogText`, `CrmDeviceText`, `CrmOrderInstructions`, `CrmPartInfo`) are filled by `dbo.RefreshCrmTextCache`, which as far as the repository shows is invoked manually.

### Acceptance criteria

1. A SQL Agent job refreshes the coordinator-screen data from Priority on a **5-7 minute** schedule, following the structure of `Job.RefreshPackingDataFromPriority.sql` (drops and recreates itself, targets msdb, safe to re-run).
2. The job is **idempotent**. Re-running it must not stack a duplicate generation of rows — the QCC Analytics sync already has this failure mode and silently inflates every total.
3. A run that overlaps the previous one is skipped rather than queued, so a slow Priority call cannot pile up runs.
4. Each run records its start, end and row counts somewhere queryable, so "the screen is stale" can be answered with evidence instead of a guess.
5. Failures are visible — a failed run must not leave the screen quietly serving old data.
6. The job is deployed to **both STAGE and PROD**, and the deployment script is committed under `database/jobs/`.

### Notes

- `app_stage` and `app_prod` cannot create SQL Agent jobs — this needs an account with `SQLAgentUserRole` in msdb, or sysadmin, on `51.17.121.203`.
- SQL Server Agent must actually be running on that instance. A job on a stopped Agent never fires and reports nothing.
- Scope which tables genuinely need a 5-7 minute cadence before building. Pulling everything at that frequency against a Priority instance holding ~24 years of history is how full-history scans start.

### Estimate

1-2 working days, plus the DBA account.
