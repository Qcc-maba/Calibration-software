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

## 9. The calibration station reads from AWS, not from anything on-prem

**Context.** The starting request was "the station should run locally against a local database, not
against Amazon, to prevent slowness". Taken at face value that means an on-prem copy of the app
database.

**Measured, before building anything further.** One connection plus **one** query to AWS took
692 ms. One connection plus **twenty** queries took 688 ms. Per-query latency is effectively zero;
the whole cost is one connection setup, once, at startup — and the master-correction load is
explicitly a one-time call. There was no slowness to remove.

**Chosen.** The station connects to `CalibratorProd` on AWS. The user's own correction of the
premise settles it: the local server *feeds* Priority data toward AWS, and the calibration stations
read from AWS. AWS is the end of the chain and the only place holding the app schema.

**Rejected — an on-prem `CalibratorLocal` on the PRI instance.** It was built and dropped the same
day. Five incompatibilities surfaced in order:

| # | What | Cost |
|---|------|------|
| 1 | AWS is SQL Server 2022, PRI is 2019 | forced through with `AllowIncompatiblePlatform` |
| 2 | PRI's `model` sits at **compatibility level 110**, so every new database inherits it and `OPENJSON` is a *syntax* error | create the DB explicitly at 150, publish with `CreateNewDatabase=false` |
| 3 | PRI's server collation is `Hebrew_BIN`; the AWS database is `Latin1_General_100_CI_AI_SC` | `CREATE DATABASE ... COLLATE` explicitly |
| 4 | 16 procedures `OPENQUERY` a linked server PRI does not define | a loopback linked server, provider `MSOLEDBSQL` — `SQLNCLI` is not registered there |
| 5 | **tempdb is case sensitive** (it follows the server collation), and temp-table identifier resolution uses it — two procedures reference a temp column with the wrong case and will not even `CREATE` | would require editing the application's own SQL |

Number 5 ended it. It cannot be worked around without changing the app's procedures, and rebuilding
the collation of a production Priority server is not on the table — so the copy would have
permanently diverged from AWS. See also decision 5, which reached the same conclusion from the
internal/external angle.

**Rejected — LocalDB as the station database.** Verified rather than assumed: Prisma's SQL Server
connector speaks TCP only. `sqlserver://host:port` parses and fails to *connect*, while both
`sqlserver://(localdb)\MSSQLLocalDB` and `sqlserver://localhost\MSSQLLocalDB` fail to *parse* —
P1013 against P1001 is what tells the two apart. LocalDB exposes a named pipe and owns no TCP
listener; there were zero listeners on the box. The C# ComServer would have worked, the web app
never could.

**Rejected — `.bacpac` for moving schema plus data.** `sqlpackage /Action:Export` refuses external
references and 16 procedures reference a linked server (SQL71562). `/Action:Extract` with
`ExtractAllTableData=true` produces a `.dacpac` with the same content and no such restriction.

---

## 10. NI-488.2 is not in the installer

**Chosen.** Stations that need GPIB get NI-488.2 installed separately. Setup still *detects* it and
records the outcome in `install.log`, because the symptom of a missing driver is an empty graph:
expensive to diagnose remotely, cheap to read from a log.

**Rejected — bundling it, which is what v1.6.3 through v1.6.6 actually shipped.** NI's ~9 MB online
installer downloads several hundred MB while it runs, turning a **3-minute** station install into
**15 minutes**, on every machine, for hardware most benches do not have. Removed in v1.6.7.

**Rejected — the full offline package (~GB).** Solves the download, makes the installer unshippable
over the network.

**Rejected — a Select-Tasks checkbox to skip it.** Built, then deleted along with the driver. It
made the 15 minutes optional rather than absent, and it put a question to the operator that the
operator cannot answer at install time.

**Worth keeping:** the detection itself was wrong at first and reported the driver missing on a
machine that had it. `gpib-32.dll` is the 32-bit DLL the ComServer loads, so on x64 it lives under
SysWOW64 rather than the `sys` constant, and NI registers under `Wow6432Node`, which a 64-bit
install does not read by default. Both checks were added.

---

## 11. Installer behaviour

**Progress is reported by hand.** The post-install commands are hidden and blocking, so Inno's own
gauge — already full by then — showed nothing for minutes and read as a hang. It is reset and
stepped per task with a caption naming the step. No message pump is added because none exists in
this dialect.

**Autostart is a Startup shortcut, not a service.** *Rejected: running the web app as a second
Windows service.* The existing service restores the ComServer and the WebSocket only; after a
reboot the UI is not running until something starts it, and the launcher script is what does that,
with its logging and its `REMOTE_DATABASE_URL` derivation. A service wrapper would have to
reimplement both.

**The desktop shortcut is created by default.** Leaving it opt-in meant a default or silent install
put no icon anywhere except the Start menu.

**A previous installation found in another folder is removed.** *Rejected: allowing side-by-side
installs.* There is one AppId, one service name and one set of shortcuts, so a second install is
never a second working station — only an orphan that no longer appears in Add/Remove Programs and
whose ComServer can still take a COM port or port 3000 from the real one. Seven accumulated on the
bench in one day. The removal is deliberately narrow: it skips the folder being installed into and
refuses to touch a folder that no longer contains our launcher or ComServer. `Settings\` is
preserved by `[InstallDelete]` on purpose — a station's tunnel and device configuration lives there.

**`*.bak` is excluded from the ComServer payload.** A config backup left beside the exe carries the
previous connection string, password included.

---

## 12. Wizard and device-list fixes

All four were reported by the user one at a time and fixed directly in the app repo, which is the
exception to the standing rule that front-end work goes to Dako — the user asked for the fixes in
the moment.

**Secondary category belongs to the device, not to the order.** The wizard chose its flow with
`.some()` over every device in the order, OR'd with the device's *saved* category, so one sensor
device anywhere forced the 3-step sensor flow onto all of them and an operator's fresh pick was
overridden by what was stored. `onDeviceClick` / `moveToNextDevice` had always resolved per device;
the flow decision now agrees with them. *Rejected: keeping the order-level flow and adding an
override* — an external-calibration order legitimately carries devices of different categories, so
there is no correct order-level answer to override.

**Units stay as names on the wire.** The WebSocket payload carries `Units:"Celsius"`. *Rejected:
converting in the server* — it would break the unit tests and every consumer that treats the value
as an identifier. The degree-symbol rendering is a client concern.

**Channel auto-fill runs for the whole diagram, not per point.** Each point derives its options from
the same `points` state, so five points auto-filling in one render all saw an empty taken-set and
all claimed channel 1.

**The logger's COM port comes from the calibrator's configuration.** `GetAllCalibrationDevices`
returns a free-text `Connection` ("RS-232", "USB + LAN") that is neither `COM` nor `IP`, so
normalisation fell through to the first option — IP — and the port defaulted to COM1. The configured
values live only on `GetLogersConfiguredByCalibrator` (`CommunicationProtocol` /
`CommunicationDetails`) and were being discarded. `COM` now leads the option list so an unreadable
protocol falls back to COM/COM1 rather than IP.

---

## 13. Transport rediscovery: a separate 30-second timer

**Context.** MBA-962 item 4. Discovery ran once, at startup. Unplugging a logger and plugging it
back in therefore ended the session permanently: the pending device is dropped the moment its link
reports disconnected, and nothing ever looked again. The app's "manual refresh" only redraws the
client.

**Chosen.** A second timer in `ServerCore`, default 30 s, configurable through
`VCTSettings.RediscoverIntervalSeconds` (0 disables). Transports already held are passed in as
claimed; discovery logs its phase so a line reads `[STARTUP]` or `[REDISCOVER]`.

**Rejected — a counter inside the 2-second device tick.** A serial pass physically opens each
candidate port and waits for `*IDN?`. On the tick thread that stalls every live device for the
duration — the same starvation an absent GPIB instrument already causes.

**Rejected — rediscovering at tick frequency.** The probe disturbs instruments that may be
mid-measurement, for no benefit.

**Why claimed transports matter.** For serial it only saves a pointless probe (Windows refuses a
second open even from the same process). For GPIB and VISA it is load-bearing: enumeration opens
nothing, so a pass would otherwise add a second tunnel for an address that is already live.

**Not yet built, and it is the larger half of the ticket.** There are three kinds of disconnect and
this addresses one. See "In flight" below.

---

## 14. Working agreements confirmed this session

- **Front-end work normally goes to Dako** as a Jira US plus a `reference/*` branch; `app/` is its
  own git repository. Direct edits happen only when asked for explicitly, as they were here.
- **Do not report a verification you did not perform.** Two claims had to be retracted: "the web app
  returns HTTP 200" was measuring a `next dev` server that happened to own the same port while the
  installed app had quietly lost the race and died, and a "PASS" on channel uniqueness was vacuous
  because the selector matched nothing. Check what the measurement is actually measuring.
- **One command per message when the user is running things on a station.** A list of steps produced
  "I do not understand what you want me to do"; a single command per message did not.

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

### Station installer and MBA-962 (added later the same day)

**v1.6.9 has not been built, and the rediscovery code has never been compiled.** The `ServerCore`
rediscovery timer and `VCTSettings.RediscoverIntervalSeconds` (decision 13) are written and
committed but no build has run over them. Compile before believing any of it. The last installer
actually built and installed is **1.6.8**, which does *not* contain them.

**MBA-962 is one quarter done.** The user's four answers map to:

1. *Check* — needs the person on the affected station to retest on 1.6.8. Not reproducible here.
2. *The two-loggers-connected indicator is a UI badge* — client-side, unverified, untouched.
3. *Units should render as symbols* — client-side (decision 12), untouched.
4. *Fix the disconnect* — only the **communication** case is addressed.

**Two of the three disconnect kinds are diagnosed and unfixed.** The user named three: power,
communication, channels.

- **Power.** A power-cycled logger comes back with its scan configuration gone. The link reports
  connected again, but `DataRestored` never fires and no session re-sends the setup sequence.
  Rediscovery cannot help: the port is still held, so nothing looks like a new device. This needs
  re-initialisation on reconnect, which does not exist.
- **Channels.** `Hydra2DeviceBL.cs` (~line 491) `continue`s silently when a reading is
  `>= 9000000000`, the sentinel a disconnected channel returns. No alert, no log line, no client
  message — the calibration proceeds with fewer points than the operator asked for and nothing on
  screen says so. This is the most dangerous of the three because it is invisible.
- **Communication** is the case decision 13 covers, and only once it is compiled and shipped.

**The app repo has uncommitted work.** `src/server/api/root.ts` and the paths module are modified to
wire in an `order-approval` feature whose files are entirely untracked. The committed
station-related app changes end at the per-device calibration flow, channel auto-fill, device-logger
and master-device work.

**`correction.log` grows without bound** and reached 53 MB on the bench machine. Nothing rotates it.

**`Installer/drivers/` is gitignored.** Harmless while decision 10 stands, but if a driver entry
ever returns, a fresh clone will fail to build with a missing-file error that does not say why.

**Remote diagnostics for a customer station exist but are ad hoc.** `assets/publish-logs.ps1` ships
logs to a per-machine folder on the share at every launch, and the scratch verification scripts
written for the remote station are scratch — they were pasted one command at a time, not packaged.
If station support becomes routine, that packaging is the missing piece.
