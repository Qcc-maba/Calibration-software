# Decisions, and why — session 3

Written 2026-09-09. Numbering continues from session 2 (which ends at 63), so a decision number means
one thing across the whole handoff.

This session had two halves. The first produced decisions **1–8**, which are already filed in
`session1-decisions.md` and are not repeated here — the pricing matcher, the GUIMonitor connection
string, the inactive flag and the contact merge. The second half is what this file covers: the user
asked what the local server actually holds and how it syncs to the global one, and the answer turned
out to be different from what everyone assumed.

---

## 64. The local and global servers were mapped by measurement, not by reading code

**Context.** Work kept being proposed on the assumption that the on-prem server and the cloud one hold
the same calibration data and sync between them. Nobody had checked.

**Chosen.** Query both servers directly — `sys.databases`, `sys.servers`, `msdb..sysjobs`, and the
module definitions on each side — and write down what is actually there.

**What that produced.** 26 databases on the local box, four of which matter: `amaba` (the Priority ERP,
~76 GB), `kyulan` (the live legacy calibration database, MABA2000 lineage), `priority_kyul` (Priority's
own load tables), and a `Calibrator` that is an abandoned copy, frozen since 2025-03-17, with an older
flat schema and no `Customers` or `OrderWorkPlans` at all.

**The finding that matters: no calibration data moves between the two servers, in either direction.**
Three mechanisms exist and only one carries live traffic:

| Direction | State | What it actually does |
|---|---|---|
| global → local | live, read-only | ~16 procedures read `amaba` only — `PART`, `PARTTEXT`, `SERNUMBERSTEXT`, `FAMILY`, `ORDERSTEXT`, `INVOICES`, `CPROF`. None writes back |
| local → global | **dormant** | Seven procedures write to `QCCData`, the *website* database, not the app. No SQL Agent job calls any of them; `OrdersFULL` last moved 2024-10-06 |
| Priority ↔ `priority_kyul` | live, every 5 min | The only two calibration-ish jobs. Both entirely local — neither mentions the cloud host |

**Rejected — inferring the topology from the connection strings and procedure names.** They suggest a
local↔global calibration sync that does not exist. The `KyulanSyncDB` name in `VCT.json`, the linked
server defined on both sides, and seven procedures with "Sync" in the name all point at a pipeline
that has not run since 2024.

**Supersedes nothing, but sharpens** decisions 26 and 48 in session 1, which said the lab has no local
database. It has one; it is just not the application's, and nothing connects to it.

---

## 65. `kyulan` is a different data model, not an older copy

**Context.** `kyulan` is live — `tblInstr` was edited the same morning, 84 rows in 30 days — so it is
the obvious candidate whenever "the local calibration database" comes up.

**Chosen.** Compare it to the cloud app schema table by table before proposing anything that reads it.

**Measured.** `kyulan` shares **zero** table names with the cloud application database. Not "an older
version of" — a different model, MABA2000 lineage (`tblInstr`, `tblInstrCorrections`, ~117
procedures). The abandoned `Calibrator` on the same box shares 15 of 59 table names, and of those only
four have matching row counts.

**Rejected — pointing the station or the app at `kyulan`.** Every table the application reads is
absent from it. It would fail on the first query, not degrade gracefully.

**Rejected — treating the 15 shared names in the abandoned copy as a migration path.** Same names,
different contents: `MeasurementDevices` 2,320 against 3,491, `Users` 79 against 2,146, `Translate`
914 against 0.

---

## 66. The only schema relationship is `amaba` → the cloud app, through `*FromSource` keys

**Context.** "Which schema on the local server relates to a schema on the global one" is a question
with a precise answer, and guessing it wrong sends any sync design in the wrong direction.

**Chosen.** Resolve the candidate join keys against live data instead of trusting column names.

**Measured.** `Customers.CustomerIdFromSource` → `amaba.CUSTOMERS.CUST`: **11,327 of 11,327**.
`CustomerRemarks.CustomerIdFromSource`: **1,534 of 1,534**. Zero orphans on either. Twelve `stg_*`
landing tables sit under the `stg` schema, merged by `stg.MergeCustomersData` and its siblings;
`stg_Orders` additionally carries `SERN` and `ORDNAME`, the Priority device and order keys.

**Consequence for any future sync work.** The existing bridge carries **ERP data into the application**.
It is not a calibration-data channel and cannot be extended into one by configuration — a local
calibration store would have to be built, and `MeasurementDevicesCorrections` holds 43,585 rows locally
against 30,981 in the cloud, so that is a merge with a conflict policy, not a copy.

---

## 67. Priority's customer status was never carried across — and the fix reads Priority directly

**Context.** This extends decision 6 in session 1 with what the cloud side turned out to look like.
Both West Pharma records — the live one and the one Priority retired around 2020 — are present in the
cloud database, and **both are active there**. The retirement flag had no path across at all.

**Measured.** 1,535 of 10,505 customers are `CUSTSTAT = -5` in Priority and every one of them read as
alive. 226 duplicate name groups covering 465 rows are in the same position.

**Chosen.** A `dbo.Customers.IsInactiveInSource` column filled by
`dbo.RefreshCustomerStatusFromPriority`, reading Priority over the linked server with `OPENQUERY`.

**Rejected — extending the staging pipeline.** `stg.stg_Customers` has no status column, so the flag
is already lost before the merge procedure runs, and the package that fills staging is SSIS — outside
the database entirely. Reading Priority directly keeps the fix in one file and leaves the pipeline
untouched.

**Rejected — reusing `IsDeleted`.** It is this system's own soft delete, set by our users. Overloading
it makes a Priority status change indistinguishable from a deliberate one.

**Applied on STAGE and verified:** 1,535 rows flagged, the live West Pharma record active and the dead
one inactive, and a re-run reporting zero changes. **PROD has neither the column nor the procedure.**

---

## 68. Stop at the permission guard rather than route around it

**Context.** The tool refused the write to the production database, and separately refused creating a
database on the Priority host. Both refusals were the harness, not SQL — the login carries `sysadmin`
on that host.

**Chosen.** Stop, deploy as far as was permitted, and hand over the exact command with the state of
each environment written down.

**Rejected — finding another route to the same write.** The guard exists because the target is a
production ERP box and a live customer database. Working around it would have made the deployment
state harder to reconstruct than the write was worth, and the resulting drift is now recorded instead
of hidden.

**Rejected — claiming the work was impossible.** It is not: the earlier justification ("cannot
provision infrastructure") was wrong and was corrected in the same session. The honest statement is
that it is permitted but gated, which is a different argument and has to be made as one.

---

## 69. A regex is not a parser, and a confident wrong number is worse than no number

**Context.** Assessing whether the cloud schema could run on the older on-prem SQL Server, a pattern
match reported **13 procedures using SQL-2022-only syntax**, including the one the station calls. That
was presented as a blocker.

**Measured, on re-checking with a paren-aware scan.** The real count is **zero**. Every hit was a comma
inside `ISNULL(...)` or an escaped quote in dynamic SQL — strings that expand at runtime to an
ordinary two-argument call.

**The second over-statement, same investigation.** "All 212 procedures need a collation review" became
**14** once the question was narrowed to procedures that create a temp table with a text column and no
`COLLATE DATABASE_DEFAULT`. The codebase already uses that pattern in nine places.

**Chosen.** Count top-level delimiters, then read the surrounding lines before reporting. Retract in
one line and move on.

**Left behind deliberately:** the scratch schema extract still carries the incorrect banner. It is
disposable and regenerable, and the retraction is recorded here so nobody rediscovers the wrong
number from it.

---

## 70. Do not sweep another session's uncommitted work into your commit

**Context.** While committing the handoff, `CLAUDE.md` was found to have gained ~150 uncommitted lines
of customer-portal documentation written outside this session.

**Chosen.** Commit only what this session wrote, name the rest in the commit body, and ask before
touching it.

**Rejected — `git add CLAUDE.md` and letting it ride.** A handoff commit that silently carries someone
else's half-finished documentation makes both harder to review, and the commit message would have been
wrong about its own contents.

**Related:** when the same handoff request arrived a second time, the existing commit was verified
before acting rather than redone. A duplicate commit is noise, and re-running the work would have
overwritten a file that had legitimately moved on.

---

## In flight — session 3

**PROD is missing the customer-status work entirely.** `dbo.Customers.IsInactiveInSource` and
`dbo.RefreshCustomerStatusFromPriority` are applied and verified on STAGE only. **STAGE leads PROD**;
`database/Compare-Schema.ps1` will show it. Deploy order: the column, then the procedure, then the
procedure with `@Apply = 1`. Both files are committed.

**`database/data/Merge-DuplicateCustomerContacts.sql` has never been applied on either server.** It is
dry-run validated on both and reports the same split each time — 6 contacts to move, 7 to retire on a
matching e-mail, 1 on a matching name. Run it with `@Apply = 0` and read the plan before flipping it.

**225 duplicate-name groups are untouched.** Only West Pharma was examined. The merge script takes the
two Priority `CUST` values at the top and is reusable for the rest.

**`GetWorkPlanData` still filters by customer name** (`LIKE N'%' + @ClientName + '%'`), so filtering by
a duplicated company returns rows from both records. The fix is `AND c.IsInactiveInSource = 0`, and it
needs the column on PROD first. The two `GetDevicesUngroupedByOrder` procedures mention the name only
inside a free-text `@GlobalSearch`, which is arguably correct as it stands.

**The VCT.Core branch-coverage gate still fails on `master`** — ~93% against a 95% threshold, while all
671 tests pass. 52 branches uncovered, 18 of them in `HardwareDeviceHost`. Either cover them or decide
the branch threshold was never meant to equal the line threshold.

**`customer-analysis/data/pricing/` is still not in `.gitignore`.** Nothing prevents the next person
committing a user's learned pricing corrections and the AI cache.

**Scratch scripts left in `customer-analysis/local-scripts/`** from the STAGE deployment, including one
that would create a database on the Priority host and **has never been run** — nothing was created
there. They print full verification and are safe to re-read, but they are scratch, not part of any
build.
