# Decisions, and why

Written 2026-09-09. Each entry says what was chosen, what was rejected, and the measurement that
settled it. Rejected options are here on purpose — several of them look obviously right until you
measure, and re-proposing them wastes a day.

---

## 1. Duplicate customers: prefer the active record, keep the dead code searchable

**Context.** Searching customer code `2025` in the pricing screen returned nothing at all. Priority
holds ווסט פארמה twice — `CUST 1123 / code 2025`, active, 1,220 invoices; and
`CUST 7639 / code 8556`, marked לא פעיל, nothing since ~2020. `loadCustomerNames` collapsed
duplicates on the **name** and kept whichever row SQL Server returned first, which was the dead one.

**Chosen.** Join `CUSTSTATS`, order active-first inside each name, and carry the discarded record's
code in an `altCodes` array that the search and ranking also match on.

**Rejected — filter out every inactive customer.** 1,535 of 10,515 customers are inactive. Some are
still worth quoting for, and hiding them silently is the same class of bug in the other direction.

**Rejected — `COMPSTATUS` / `STATUSFLAG` as the status flag.** `COMPSTATUS` is blank on all 10,515
rows. `CUSTSTATS.INACTIVE = 'Y'` is the only authoritative signal.

---

## 2. Serial matching: index the components, and never split on the hyphen

**Context.** A customer's 116-row device list matched at 60% average confidence. The customer had
1,265 devices registered with us; only 34 rows matched by serial. Priority stores a registered device
as a compound string — `2025-MPL-244(70135180)` is the customer-code prefix, the customer's asset
number, and its SAP number. The customer's spreadsheet sends the last two in *separate columns*, so
neither the whole-string key nor the digits-only key could ever hit.

**Chosen.** A third index over each identifier *component*, splitting on brackets, slash and
whitespace. A component that maps to more than one device is disqualified rather than guessed.

**Rejected — splitting on `-` as well.** The hyphen is inside the identifier: `MPL-244` would become
`MPL` and `244`, and `MPL` alone matches dozens of devices. Every such key would disqualify itself,
which is merely useless, but `244` would collide with real devices, which is worse.

**Rejected — substring / fuzzy matching on serials.** Serial matching is the one signal in this
system that is supposed to be certain. Loosening it trades a wrong answer for a missing one.

**Result.** Average confidence 60.0% → 95.9%; serial matches 34 → 108.

---

## 3. The digits-only fallback must agree on letters

**Context.** While verifying the above against Priority SQL directly, 11 rows that had matched at
100% turned out to point at the **wrong device**. The digits-only fallback exists for the documented
case where one side wrote a letter prefix and the other did not (`GI340040` vs `340040`) — it
discards letters. This customer owns both `EQP-130` and `MPL-130`; `EQP-130` reduced to `130` and
returned `MPL-130`, a different instrument, so a wrong part number and a wrong price with nothing on
screen to suggest a problem.

**Chosen.** When both the query and the candidate carry letters, the letters must match.

**Rejected — removing the digits-only fallback.** It is load-bearing for the case it was written for,
where exactly one side has letters. The guard is written so that case still passes.

**Verification.** Across the 12 largest customers, 682 realistic identifier queries: precision 12% →
89%, and the absolute number of wrong answers *fell*, 73 → 43. All 43 survivors come from the
pre-existing exact-match path, none from the new code.

---

## 4. GUIMonitor gets the same connection string as ConsoleHost

**Context.** `GUIMonitor` hosts the same `VCT.Core.ServerCore` as the station, and
`ResolveDbSectionName` prefers a `KyulanSyncDB` entry over `REMOTE_DATABASE_URL`. Its config defined
one, carrying two faults at once: `providerName="MySql.Data.MyqlClient"` — a MySQL provider, and
misspelled — pointing at `Database=Calibrator` on PRI, the copy frozen since 2025-03.

**Chosen.** Replace the entry with the same `REMOTE_DATABASE_URL` the ConsoleHost ships.

**Rejected — fixing only the provider name.** That was the obvious one-word fix and it makes things
*worse*: the connection would then succeed, `ServerCore` would log "DB connected OK", and the queries
would fail afterwards against a database missing the tables. A silent fault replacing a visible one.

**Rejected — adding `KyulanSyncDB` to the ConsoleHost config** to "complete" what `VCT.json` asks
for. It would redirect the entire station to a database with no `OrderDetails`, no `OrderWorkPlans`
and no `AssignMeasurmentDevicesToCalibrator`. The fallback is deliberate and documented in
`ServerCore.cs`; a comment now says so at the config itself.

---

## 5. The local/global split for internal vs external calibrators: not built

**Context.** The stated intent is that internal calibrators work against the local server and
external ones against the global, with the coordinator writing locally and syncing up.

**Measured.** The internal/external distinction *does* exist — `OrderDetails.IsInHouse`, filtered per
screen — but as a column in one database. The database-level split exists in no layer: the app has a
single Prisma datasource, the station has one connection string, and there is no sync of calibration
data between the two servers in either direction.

**Chosen.** Write down the gap (`docs/internal-external-calibrator-split.md`) rather than start
building.

**Rejected — pointing the station or the app at `kyulan`.** It is live and current, but it is the
MABA2000 data model: `tblInstr`, `tblInstrCorrections`, and **zero** table names in common with the
AWS app schema. Every table the app reads is absent. It would break on the first query.

**Rejected — reviving `Calibrator` on PRI.** Frozen since 2025-03-17, 59 tables against 95, an older
flat schema with no `Customers` and no `OrderWorkPlans`.

**Still open, and it is a real decision, not a technical one.** `MeasurementDevicesCorrections` holds
43,585 rows locally against 30,981 on the global — each side has data the other lacks, so this is a
merge, not a copy, and the direction determines which side wins a conflict.

**Feasibility, since it was over-stated once already.** The blocking list is smaller than first
reported: zero procedures need rewriting for SQL 2019 (the "13" was a regex artifact), and 14 of 212
procedures — not all 212 — create a temp table with a text column and no `COLLATE DATABASE_DEFAULT`,
which is what the `Hebrew_BIN` server collation would break. What is genuinely absent is a local
database holding the app schema.

---

## 6. Priority's inactive flag: read it directly, not through staging

**Context.** 1,535 of 10,505 MABA customers are marked dead in Priority and every one of them reads
as alive in the app, because nothing carried the flag across. Both West Pharma records arrive with
`IsDeleted = 0`, and 226 name groups covering 465 rows are duplicated the same way.

**Chosen.** A new `dbo.Customers.IsInactiveInSource` column, filled by
`dbo.RefreshCustomerStatusFromPriority`, which reads Priority over the linked server with `OPENQUERY`.

**Rejected — extending the staging pipeline.** `stg.stg_Customers` has no status column at all, so
the flag is already gone before `stg.MergeCustomersData` runs, and the package that fills staging is
SSIS — outside the database entirely. Reading Priority directly keeps the fix in one place and leaves
the pipeline untouched. `RefreshCustomerRemarksFromPriority` set that precedent.

**Rejected — reusing `IsDeleted`.** It means something else: this system's own soft delete, set by our
users. Overloading it would make a Priority status change indistinguishable from a deliberate delete.

**Detail worth keeping.** The column is `NOT NULL DEFAULT 0` so an unknown status reads as *active* —
nothing may vanish from a screen between the column landing and the first refresh. Scope is
`SourceId = 1` (MABA); SEPHARM customers do not come from `amaba` and are left alone rather than being
marked active by a source that knows nothing about them.

---

## 7. Merging the contacts off a dead customer: six move, eight retire

**Context.** 14 contacts sit on the dead West Pharma record against 86 on the live one.

**Chosen.** Move the 6 with no counterpart; retire the other 8 in place with `IsDeleted = 1`. Nothing
is deleted; the rows and their Priority keys stay.

**Rejected — reassigning all 14.** Seven of them are the same person as a contact already on the live
record, matched on e-mail, and one more matches by name. A blind move would put duplicates on the
live customer — worse than the problem being fixed.

**Rejected — leaving them where they are** now that the record is flagged inactive. That hides six
real employees behind a customer nobody will open again.

**Rejected — a hardcoded list of contact ids.** The dry run proved why: the same fourteen people are
`44080, 19708, …` on PROD and `48691, 15512, …` on STAGE. The script keys on Priority `CUST`.

---

## 8. Left alone on purpose

- **`archive/DeviationCalculation`** — dead code, not in the solution, not built.
- **`Libraries/DAL/Rational/BaseDAL_UnitTest`** connection strings still name a decommissioned host.
  They were *documented*, not repointed: these are live-DB integration tests expecting a purpose-built
  fixture with ten "Monkey" records, and `BaseUnitTest_DbConnector` has `ClearRecords()` and
  `AddRecords()` commented out in its constructor. Aiming them at `kyulan`, at PRI's `Calibrator`, or
  at the AWS server would not fix them, and un-commenting those calls against a real database would
  delete rows in it.
- **`customer-analysis/data/pricing/`** was deliberately not committed. It is written at runtime;
  `customer-overrides.json` is every correction a user has ever confirmed, and a deployment that
  recreates it empty throws the learning away.

---

## In flight — nothing here is finished

**Deployed to STAGE only; PROD has none of it.** `IsInactiveInSource` and
`RefreshCustomerStatusFromPriority` were applied and verified on STAGE (1,535 rows flagged, West
Pharma `2025` active and `8556` inactive, a re-run reporting zero changes). PROD has neither the
column nor the procedure. **STAGE therefore currently leads PROD** — `Compare-Schema.ps1` will show
it. Deploy order: the column, the procedure, then the procedure with `@Apply = 1`.

**`database/data/Merge-DuplicateCustomerContacts.sql` has never been applied**, on either server. It
is dry-run validated on both and reports the same 6/7/1 split on each. Run it with `@Apply = 0` first
and read the plan before flipping it.

**Only West Pharma has been looked at.** 225 other duplicate-name groups are untouched. The merge
script takes the two Priority `CUST` values at the top and is reusable for them.

**`GetWorkPlanData` still filters by name.** Line ~551 builds
`AND c.CustomerName LIKE N'%' + @ClientName + '%'`, so filtering by a duplicated company name returns
rows from both records. Once `IsInactiveInSource` exists on PROD the natural fix is to add
`AND c.IsInactiveInSource = 0` there. Not done — it changes a production screen's behaviour, and the
column does not exist there yet. `GetDevicesUngroupedByOrder` and `V2` mention `CustomerName` only
inside a `@GlobalSearch` CONCAT, which is free-text search and arguably correct as it is;
`GetCustomerDashboardData` uses it for output only, and the hit in `GetCustomerCalibrationReports`
was inside a comment.

**The VCT.Core branch-coverage gate fails on `master`** at ~93% against its 95% threshold, while all
671 tests pass. Pre-existing. 52 branches are uncovered, 18 of them in `HardwareDeviceHost`. Either
cover them or decide the branch threshold was never intended to equal the line threshold.

**`customer-analysis/data/pricing/` is not in `.gitignore`.** Nothing stops the next person adding
the directory and committing a user's learned corrections and the AI cache.

**A full extract of the global schema** (95 tables, 76 PK/UQ, 158 FKs, 212 modules) was generated to
a scratch directory outside the repo during the feasibility work. It is disposable and regenerable;
note that the copy carries an **incorrect** "2019-INCOMPATIBLE" banner on 13 modules — that finding
was a regex artifact and was retracted, see decision 5.

**A probe script that would create a local database on PRI** exists under
`customer-analysis/local-scripts/` and has never been run — the tool-permission prompt blocked it and
it was not worked around. Nothing was created on PRI. Two other scratch scripts sit beside it from the
STAGE deployment; they print a full verification and are safe to re-read before reuse, but they are
scratch, not part of the build.
