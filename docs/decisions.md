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

# The customer portal — screens, identity, and reading Priority

The customer-facing half of the web app: who a login is, where the deployment actually runs,
and how it reads data that lives in Priority. Written 2026-09-09.

---

## 15. A calibration may use fewer channels than the sensor has — pick them, don't redefine the sensor

The wizard assigned a logger and a sensor and implicitly used *every* channel the sensor declares.
Real jobs use a subset.

**Chosen:** a `ChannelPicker` popover on the logger-config screen, one checkbox per channel, with the
invariant that the selection can never become empty — unchecking the last one is a no-op rather than
an error, because an empty selection has no meaning downstream.

**Rejected — a numeric "how many channels" field.** Channels are identified, not counted; 2 of 4 is
not the same job as channels 3 and 4.

**Rejected — editing the sensor definition per order.** The sensor is a shared master record; a
per-order need must not mutate it.

---

## 16. A portal login is an e-mail, and an e-mail is not one customer

Signing in with a real address landed the user on the wrong company, with an empty portal. The
address was a contact on two Priority customers — one live, one long dead.

**Chosen:** `GetPortalCustomerIds` returns every customer the address is a contact of, and the
customer **that actually has devices** wins. It answers the real question ("whose portal is this
person supposed to see?") with data rather than with an id ordering.

**Rejected — take the first / lowest / newest `CustomerId`.** Identity columns differ between STAGE
and PROD, so this is unstable by construction, and the dead record is as likely to sort first.

**Rejected — delete the stale contact row.** Priority owns it. See 17.

---

## 17. When Priority retires something, carry a flag — never delete a row

Two contact records had to stop signing the user into the wrong company.

**Chosen:** `PHONEBOOK.INACTIVE` is carried into `CustomerContacts.IsActive` through
`stg.LoadCustomerContactsFromPriority` → `stg.MergeCustomersContactsData`, and the portal procedures
filter on it. The user's rule, verbatim: *"שיביא אותם במצב INACTIVE זה בסדר. אסור להמחק
מהפריוריטי."*

**Rejected — deleting contacts that disappear from Priority.** A sync that deletes is a sync that
loses data the first time the source query is wrong, and it destroys the record of who used to be a
contact.

**Rejected — filtering in the app instead of in the sync.** Every screen would have to remember, and
the ones that forgot would be the ones customers see.

---

## 18. Invoice PDFs: resolve the path on the server, pick the file by size

Priority keeps printed invoices as attachments recorded in `EXTFILES`. The customer clicks a row and
expects the PDF.

**Chosen:** the procedure returns the attachment's **directory** (ASCII) plus the recorded file size;
an authenticated API route re-runs the same invoice query for the session, refuses an invoice that is
not in that customer's list, resolves the directory under the attachments root, refuses anything that
climbs out of it, picks the PDF by size and streams it inline.

**Rejected — returning the stored file name.** Priority stores names in visual (reversed) order.
Running `fnUnreverseVisualText` over the value reverses the ASCII path with it and nothing opens;
leaving it reversed does not match the file on disk either. The directory is ASCII, and each
attachment sits in its own hash directory, so size is enough to choose between candidates.

**Rejected — handing the browser a share path.** That is a file-read primitive with the customer
holding the parameter.

Related finding, not a decision: rows whose number starts with **`K`** are receipts (קבלה) and
correctly have no document. The screen now shows the Priority document type (`IVTYPES.IVDES`) so the
absence explains itself. Only 156 of 1,361 invoices had an attachment at all.

---

## 19. Push the whole Priority statement into `OPENQUERY`

The invoice→attachment join written with four-part names took **65 seconds** for 1,361 rows: SQL
Server issued one remote call per row.

**Chosen:** the entire statement, joins included, runs inside a single `OPENQUERY` and returns a
finished result set — **0.7–0.8s**.

**Rejected — caching the result locally.** It would have hidden a query that was simply written on
the wrong side of the link, and invoice data has to be current.

**Rejected — narrowing the row set until it felt fast.** That is tuning the symptom.

Cross-server joins also need an explicit `COLLATE Hebrew_BIN`, or they fail with
`Cannot resolve the collation conflict between Latin1_General_100_CI_AI_SC and Hebrew_BIN`.

---

## 20. `/api/health/db` — a public endpoint that says *how* the database is unreachable

Every screen on `cal` and `stg` went blank at once while the same query ran in 0.4s from the office.
From outside, all anyone could see was a tRPC 500 with the stack stripped in production.

**Chosen:** a small public route that runs `SELECT 1` and reports `{database, ms, name, code}` —
**never the driver message and never the connection string**, because a driver error carries the host
and the login name. The *shape* of the failure is the diagnosis: ~10.0s of silence is Prisma's
connect timeout, i.e. dropped packets; an instant refusal is a dead service; a fast rejection is
credentials.

**Rejected — enriching the tRPC error instead.** That leaks the same detail to every customer.

**Rejected — the Vercel runtime logs as the primary route.** They were the confirmation, not the
diagnosis, and nobody without a Vercel login can run the check. The health URL is what IT could be
handed to verify the fix themselves.

---

## 21. The SQL firewall: ask for one `/32`, not for Vercel's address space

The Security Group was tightened for the customer portal on 2026-09-08 and took the application's own
path to SQL with it. The application does not run in the office: `X-Vercel-Id: fra1::iad1::…` says the
functions execute in **AWS us-east-1**, so the connection to 1433 leaves from Virginia.

**Chosen:** ask IT to keep the tightening and add exactly one defined path, and enable Vercel
**Secure Compute** so that path is a single static egress IP — a `/32` rule like the office's, which
survives the next SG change. Written up in `docs/IT-REQUEST-sql-firewall.md`, with the measurements
that prove it is the network and not the code, and with the health URL as the acceptance test.

**Rejected — allow-listing "the Vercel ranges".** us-east-1 is hundreds of CIDR blocks against a
default Security-Group quota of 60 rules. It cannot be done, and proposing it wastes IT's day.

**Rejected — opening 1433 to the internet.** Customer data, and an exposed 1433 is scanned within
hours. Named as a temporary option only, with conditions attached and a closing date.

**The long-term direction, not built:** the app talks HTTPS to a service inside the VPC that talks to
SQL privately — the pattern `CustomerPortalApi` already uses — or the database moves to RDS with VPC
peering. Either removes the question entirely.

---

## 22. Copying one customer's orders PROD → STAGE: translate every lookup by name

STAGE knew the customer and even held 8 of its work plans, but not one `OrderDetailsItems` row, so
every portal screen was empty for the identity being tested.

**Chosen:** copy the work plans, details and items with every lookup reference **translated by name**
(`Statuses`, `OrdersProductTypes`, `MainCategories`, `SecondaryCategories`), user columns blanked, and
an undo script written listing every inserted id. Nothing existing is touched and nothing is deleted;
the script rolls back unless `--apply` is passed. Result: 8 plans / 67 lines / 22 items → 22 devices.

**Rejected — an id-preserving copy.** 69 of 158 `Statuses` and 608 of 610 `OrdersProductTypes` carry
the same id with a *different* name on the two servers. A straight copy would have silently
mislabelled almost every row.

**Rejected — pointing local development at PROD to demonstrate the screens.** It works, and it means
the next write goes to production data.

---

## 23. `npm run verify` — one command, run after every task, that walks the UI

Screens were repeatedly reported as fixed and were not, and a dead dev server was repeatedly
misdiagnosed as a broken screen. The ask: *"סט בדיקות מקיפות שבכל פעם שאתה מסיים משימה אתה מריץ
אותם… גם ל UI וגם לקוד"*, then *"אתה צריך לבדוק את כל הטאבים והפופאפים"*.

**Chosen:** a single script with four sections — code (`tsc`, `eslint`, `vitest`), sources (no mock
module imported by a customer screen, no hardcoded clock), http (every route answers, `/api/trpc`
compiles), browser (sign in, walk every screen, **every tab and every dialog**, fail on placeholder
text or a console error). It reports "the dev server stopped answering" separately from "this screen
is broken", and a step that cannot run reports instead of throwing, so one flaky interaction does not
hide the other 36 checks.

**Rejected — unit tests only.** Every defect in this session was a wiring or data defect that a unit
test would not have seen.

**Rejected — keeping the mock modules behind a flag.** Four were deleted outright. A mock that can be
imported eventually is, and a screen full of plausible fake data reads as working.

---

## 24. Retired devices and empty tabs: decide in the procedure, show the truth in the UI

*"כשתאריך הביטול לא ריק אתה לא מציג את המכשיר."*

**Chosen:** the cancelled-serial set is built with **one** remote query into a temp table and
anti-joined, wrapped in TRY/CATCH that **degrades open** — if Priority is unreachable the customer
sees their devices rather than an empty screen. Tabs with no wired data source render an explicit
empty state instead of leftover sample values, and the reports tab is filtered to the device's serial
so it is that device's history, not the customer's.

**Rejected — filtering cancelled devices in the app.** Every screen would need the same list, fetched
again.

**Rejected — a per-row remote existence check.** The same one-call-per-row mistake as 19.

---

## 25. The development sign-in code must not suppress the real mail

A development-only code was added so the portal could be signed into locally. It also stopped the
OTP mail being sent — and the only symptom, for a day, was *"המייל לא מגיע אלי"*.

**Chosen:** mail is attempted whenever a relay is configured, in every environment. Development
tolerates a send *failure* (so a machine with no relay can still sign in with the dev code); it never
skips the send. The dev code itself stays gated on the Development environment **and** a loopback
caller.

**Rejected — a "quiet mode" flag.** The same trap with a name on it; the next person turns it on to
stop the noise and the outage is invisible again.

---

## 26. The "local primary, global secondary" topology: measured, not built

The stated target is a **local** primary database with a **global** AWS secondary — WorkPlan synced
outward, external calibrators and the driver connecting to the global copy.

**Not implemented, and this is a finding rather than a decision.** What was measured: the on-prem
`Calibrator` is a frozen legacy schema (58 tables; WorkPlan 4 rows, last written 2024-07-28; Orders
newest 2025-03-03) sharing only **15 table names** with the AWS schema (96/95 tables). All live data
is on AWS (`OrderWorkPlans` 2,913 PROD / 1,328 STAGE, newest row dated 2026-09-08). Nothing syncs
between them in either direction today.

The blockers are structural, not effort: engine 2019 vs 2022, compat 110 vs 160, `Hebrew_BIN` vs
`Latin1_General_100_CI_AI_SC`, plus the previously abandoned on-prem copy recorded in decision 5.
Any plan that starts "we already have a local copy" is starting from something that is not true.

---

# VCT instrument bring-up

Nine electronics instruments were added to a server that had only ever handled temperature and
humidity loggers. These entries cover that work.

---

## 32. Transports are discovered, not configured

**Chosen:** at startup the server enumerates VISA/USB, the GPIB bus and the serial ports, sends an
identification packet, and creates a tunnel only for links that answered. `VCT.json` went from eight
static tunnels to one.

**Rejected:** a configured tunnel per instrument. It failed three ways at once - two instruments
configured on the same COM port collided; a tunnel for an unplugged instrument wedged the whole
device tick on its bus error; and every new instrument meant editing JSON on every station.

**Why:** the requirement was explicit - settings must not be per-device, and should follow from what
is attached and what the identification reply says. Discovery also absorbed a port renumbering (a
logger moved COM10 to COM11 between sessions) with no change anywhere.

**Consequence to know:** an instrument with no identification command cannot be discovered. Optidew
speaks Modbus and has no `*IDN?`, so it still needs a static tunnel.

---

## 33. Identification lives in the device host, not in the BL

**Chosen:** the chain of model matches sits in `HardwareDeviceHost.handlePacket`, with `internal
static` helpers beside it for the awkward cases, and the BL cores match on the resulting SN.

**Rejected:** putting the match next to the BL that uses it. It reads more cohesively and it is
wrong: the BL assembly is not referenced by the core, so the check would have to be duplicated, and
two copies of "which instrument is this" is exactly the bug you cannot afford.

**Ordering matters and is not obvious.** Vendor-level branches are legacy: `FLUKE` takes the first 11
characters (for the Hydra loggers) and `HEWLETT` the first 15. Any model-specific branch - 5522A,
5322A, 53181A - **must** come before them, or the counter is claimed by the multimeter's BL and
driven with multimeter commands.

Two model tokens are not literal strings:

- The scope answers `EDU-X 1002A` while its datasheet, our SN and the settings all say `EDUX1002A`.
  Matched with spaces, hyphens and underscores stripped.
- The 5322A answers **either** `FLUKE,5322A` or `FLUKE,5320A` depending on an emulation menu.
  Both are matched and normalised to one SN, so flipping a front-panel option cannot silently take
  the instrument out of the server.

---

## 34. Default units follow the instrument, and `VDC` does not mean volts

**The bug:** an oscilloscope broadcast its readings labelled `Celsius`, because a flat Celsius
default predated any instrument that measured electricity.

**The trap:** the obvious fix - map the existing `MeasureTypes.VDC` to Volt - is wrong. Reading
`ProcessResults` shows `VDC` in this codebase means *a resistance measured in volts and converted to
temperature*, i.e. a PRT. Remapping it would have relabelled every existing temperature device.

**Chosen:** add `VoltageDC` for genuine volts and leave `VDC` alone; resolve defaults per family from
the identification SN; keep the sensor-type rule (RTD / FRTD / thermocouple gives Celsius) on top,
since an instrument wired to a PRT reports temperature whatever it is. The TTI was marked `FRTD` for
that reason, on the correction that it measures temperature too.

**Result:** no pre-existing device changed behaviour. That was the acceptance test.

---

## 35. A parse failure returns false, never zero

Every reading helper returns `bool` with an `out` value rather than a default.

**Why:** on a calibrator, `0 V` is a legitimate setpoint. A parser that returns 0 on failure produces
a number indistinguishable from a real reading the moment it is broadcast. This turned out to matter
more than expected: when a GPIB line corrupts digits into letters, the parse fails and the reading is
*discarded* - the instrument goes quiet instead of publishing plausible wrong numbers.

---

## 36. The byte-wise GPIB read: built, measured, removed

**Problem:** an instrument's replies came back with bit 6 set on bytes that should have had it clear.

**Tried:** reading one byte per call, so the millisecond gap between calls lets the line settle. Via
VISA this worked - 0/60 correct became 57/60.

**Rejected and removed.** It cannot be done on the path the server actually uses: NI's device-level
`ibrd` re-addresses the instrument on every call, so the rest of the message is discarded. The server
received exactly one byte. It was implemented, tested against hardware, and deleted rather than left
as dead code with a caveat. 95% would not have been good enough for measurements anyway.

**Kept from that work:** `TransportDiscovery.FindGpibListeners`, a driver-level bus scan used when
VISA's GPIB enumeration returns nothing - which it did while an instrument was answering normally.

---

## 37. The corruption is one instrument, not the adapter

**What was concluded, and then retracted twice.** The corruption was first blamed on the Fluke 5522A,
then on the shared GPIB adapter (two instruments, two cables, a 100% failure rate on the first
high-to-low transition of one data line - real measurements, and a recommendation to replace the
adapter). Then NI-488.2 was reinstalled and its driver properly bound, and two other instruments read
perfectly on that same adapter and cable.

**Settled by isolation:** three instruments, one adapter, one cable, one driver, one session - two at
0% failure, the Meatest M-142 at 86-100%. It is the M-142.

**It is not a setting.** The M-142 exposes three interface options and standard GPIB functions; GPIB
is eight parallel lines with no format or parity, so no menu item can set a bit on every byte.

**Lesson recorded in `CLAUDE.md`:** two variables changed together and the stronger-sounding
conclusion was presented instead of the isolation step. The workaround is the M-142's RS-232 port.

---

## 38. Output-enable is built, marked, and never called

Six of the nine instruments source rather than measure - up to 1000 V / 20 A, hipot levels, and with
one option 1000 A through a coil.

**Chosen:** build the energise command, document it with a warning at every layer, and issue it only
from an explicit commanded target. Init sequences drive the *other* way and end de-energised as a
stated intention rather than as a side effect of `*RST`. Tests assert all of this per instrument.

**Deliberately not built:** any wiring from an app command to an output enable. That is a product
decision - who authorises energising an output, and how it is confirmed - not a coding gap.

---

## 39. The Transmille 3200A was not written

Researched alongside the M-142 and the 5322A and deliberately left out: no `*IDN?`, a proprietary
`F1/S12.32<CR>` dialect, and no documented baud rate. Everything written from that manual would have
been a guess presented as a driver. It needs the hardware in hand first.

---

## 40. The 5322A read loop is gated on the instrument's current function

Hardware showed that `SAF:<function>?` **selects** that function rather than merely reading it -
`SAF:LOOP?` moved the instrument from Ground Bond to Loop and `SAF:GBR?` moved it back, error queue
empty throughout. The read loop therefore asks the mode first and requests a setpoint only for the
mode the instrument is already in; in any other function it logs and broadcasts nothing.

Without the gate the polling loop would have overridden the operator's front-panel selection every
two seconds. Nothing in the manual hints at it; only connecting the instrument found it.

---

---

---

# Taking `portal.qcc.co.il` live

Getting the customer portal in front of real customers. The API half reached production; the domain
had not been connected when this was written.

---

## 27. The portal API runs on the production SQL host, behind IIS

**Chosen:** `MabaCustomerPortalApi` as a Windows service on `MbaCustWeb` — the production SQL box —
listening on 5312, with IIS terminating TLS on 443 and reverse-proxying to it. Only 443 is open
externally; 5312 is not.

**Why:** the service needs the production database and the M365 mailbox, and it is the one component
that cannot live on Vercel because it owns the one-time-code flow. Adding a role to the production
SQL server was raised explicitly and approved on 2026-08-31 rather than assumed.

**Rejected — building on the server.** The installer originally ran `dotnet publish`, which requires
the source tree and the .NET SDK on that machine. Neither belongs there. It now takes
`-SkipPublish -PublishDir`, and the package is published `--self-contained` so the server needs no
.NET runtime either.

**Rejected — exposing 5312.** `request-otp` answers differently for a registered and an unregistered
address, so a reachable service without the shared key lets anyone walk a list of e-mails and learn
which belong to MABA customers. `Auth/ExposureGuard.cs` refuses to start on a public binding with no
`ProxyApiKey`, which makes "go live without the key" not an option rather than a bad idea.

## 28. One SAN certificate on the IP:port binding — not a certificate per hostname

**Chosen:** reissue the existing DigiCert certificate with `portal-api` added to its SAN, and bind
that one certificate to the address's `IP:port`.

**Why, and this was measured rather than reasoned:** an SNI binding for the new hostname was created
correctly and `netsh http show sslcert` listed it — and it was never once served. Every request,
whatever `-servername` was sent, got the certificate on the `IP:port` binding, confirmed by
fingerprint. http.sys resolves an exact IP:port binding before it consults a hostname binding, so
while one exists on that address it answers for every name on it.

**Rejected — a separate certificate for the portal host.** It would have been bought, installed, and
never presented. This is the reason the finding is written down.

**Rejected — converting the existing site to SNI so each host carries its own certificate.** It is
the better long-term shape and it stays available, but it means changing a live binding on the
company's public site during a launch, and the SAN reissue achieved the same result with no exposure.

**Consequence to keep in mind:** any certificate bound to that address must cover *every* hostname on
it. Binding one that covers only the portal API would take the main site down.

## 29. Launching the portal meant releasing four months of the internal system

**Chosen:** merged `stg` → `main` on 2026-09-07 — 205 commits, 639 files — and said so plainly as a
full release rather than describing it as a portal deploy.

**Why:** Vercel's Production branch is `main`, and `main` had not moved since 10/08. There is no path
that ships a portal fix to production without shipping everything else on `stg` with it.

**Rejected — pointing the customer domain at a `stg` branch deployment.** A branch build is
`VERCEL_ENV=preview`, which `env.js` resolves to `REMOTE_DATABASE_URL_STAGE`. The portal would have
served customers staging data. This is the trap most worth remembering, because it looks like a clean
way to decouple the two releases and is not.

**Rejected — cherry-picking the portal commits onto `main`.** The portal work sits on shared
`src/server` and `src/lib` changes; the subset does not stand alone.

The four merge conflicts all resolved to `stg`. `src/env.js` was whitespace only — the database-URL
resolution was byte-identical on both sides, which was worth confirming before trusting it.

## 30. Security fixes by `pnpm.overrides`, pinned inside the existing major

**Chosen:** targeted `pnpm.overrides` entries, each a caret range with a version selector, closing 30
of 60 runtime critical/high Dependabot alerts including the only runtime critical.

**Rejected — `pnpm update`.** It also rewrote 166 lines of ranges in `package.json` (the AWS SDK from
`^3.937.0` to `^3.1127.0`, every Radix package). That is a mass upgrade wearing a security-fix label.

**Rejected — a bare `>=` in the override.** It resolved `minimatch` to 10, `brace-expansion` to 5,
`nanoid` to 6 and `js-yaml` to 5 — across breaking API changes for the packages that depend on them.
Every entry is `^` with a range selector so each package stays in the major its parents already use.
Checked against the previous lockfile that `minimatch@10`, `brace-expansion@5` and `picomatch@4` were
already in the tree and were not introduced by the change.

**Deliberately left open:** `next` 16.0.10 → 16.2.11 (26 high, five of them App Router middleware
bypasses) needs its own regression pass; `xlsx` 0.18.5 has **no patched release on npm** at all —
SheetJS moved distribution off npm at 0.20.x, so Dependabot will never close it and it needs a
decision, not a bump.

**Consequence worth carrying:** until `next` is bumped, the `portal.qcc.co.il` host restriction is
App Router middleware on a version with five published bypasses. Treat it as defence in depth, which
is how its own ticket framed it — not as the access control.

## 31. Two go-live gates were dropped after re-reading what they actually protected

**Dropped — the "no dead end" redirect work.** Its launch-critical criterion was *a junk session
cookie must not cause a redirect loop*, and that is already satisfied by the host-restriction change:
the root redirects on cookie presence, then the session provider verifies the HMAC server-side and
sends an invalid cookie to sign-in, where it stops. What remained was the difference between a
well-built translated 404 page and a redirect to the lobby — a product preference, not a blocker.

**Closed by a different mechanism — the multi-company branch picker.** The ticket designed a picker
driven by `MatchCount` and `@SelectedCustomerId`. What shipped instead was the **union**: the
procedures return every company the caller belongs to, and rows carry `customerName`. The reported
problem no longer occurs, so the bug was closed — but the picker was never built, and the
`@SelectedCustomerId` parameter still exists on twelve procedures and still validates against the
caller's own contacts. If a picker is ever wanted it is front-end work only.

**Closed as already-done.** Several tickets were sitting in `To Do` or `In Testing` with the work
merged — one for over a week. The lesson is in the working-style notes: read the branch, not the
status field.

## In flight — the portal go-live

**The portal is not live.** `portal.qcc.co.il` does not resolve; the domain was never attached in
Vercel. Everything below is the state as of 2026-09-09.

**Done and verified from outside the network:** `portal-api.qcc.co.il` resolves, answers `/health`
with `200` over a trusted certificate, returns `401` on `request-otp` without the shared key, and
5312 is closed externally. The main site was unaffected. `Verify-PortalApi-Deploy.ps1` printed
STAGE A PASSED. All portal procedures are on PROD and identical to STAGE (`Compare-Schema.ps1`:
0 STAGE-only, 0 differing).

**The one code blocker left.** The WebSocket client is mounted in `AppProviders` at the root layout
and connects unconditionally, so a customer on any portal screen gets a red `destructive` toast —
*"cannot reconnect to logger"* — about 15 seconds in, after three failed reconnects. No customer
screen consumes the socket; all five consumers are internal screens. The fix is to gate the
*connection* (not the provider, or context consumers break) on the route or the host. Not started;
`socket-provider.tsx` is unchanged on `stg`.

**Unverified, and it is a security question, not a formality.** Whether the EC2 Security Group
restricts 1433 and 3389 to the office or leaves them open to the internet. Scans from inside the
office cannot tell the two apart — both answer. It needs the inbound rules themselves or a scan from
a foreign network. IT were asked; the reply ("the ports were opened") did not answer the question
that was asked, which was to *restrict* them.

**Possibly not applied on the server** — both were handed over as commands and not confirmed back:
`CustomerPortal__TrustedProxies__0 = 127.0.0.1` plus a service restart (without it the rate limiter
counts every customer as one), and the cleanup of the temporary self-signed certificate and its now
redundant SNI binding.

**Not committed.** `docs/PORTAL-DEPLOY-HANDOFF.md` and `scripts/Verify-PortalApi-Deploy.ps1` are
still untracked, and they are the only record of what was done on the server.

**Dependency work half done.** The lockfile overrides are merged; `next` → 16.2.11 and the `xlsx`
decision are not. Re-run the Dependabot count against `stg` to confirm the drop rather than assuming
it.

**Left behind:** three temporary git worktrees of the app repo under the local scratch folder. One
holds a directory junction to the real `node_modules` — deleting that worktree recursively would
follow the junction and destroy the working checkout's dependencies. Remove the junction with
`rmdir` first, then `git worktree remove`.

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

### The customer portal, as of 2026-09-09

**STAGE leads PROD on four procedures.** All verified on STAGE, none deployed to PROD:

| Procedure | What the PROD deploy changes |
|---|---|
| `GetCustomerDeviceDetail` | adds the calibration-tab fields (date, specification, method, reference document, tolerance, resolution, required probability, visual check, report language, comment, long unit) |
| `GetCustomerDeviceList` | filters devices Priority has cancelled |
| `GetCustomerInvoicesFromPriority` | the `OPENQUERY` rewrite, plus document directory / size / type and the receipt flag |
| `GetCustomerDashboardData` | `LEFT JOIN` → `JOIN` on `OrderDetailsItems` — this **changes the counts ~957 customers see**, so it wants a deliberate before/after check, not a quiet deploy |

The contact `IsActive` chain (column, loader, merge, the three portal identity procedures) **is** on
both servers.

**Two diagnostic scripts written and not run on PROD.** `database/diagnostics/` holds
`Deactivate-Duplicate-Users-PROD.sql` (34 duplicate portal accounts) and
`Fix-Portal-Identity-Philips.sql`. Both are dry-run first by construction. Nobody has decided when.

**The Priority side of the identity fix is not done.** Two `PHONEBOOK` rows still need
`INACTIVE = 'Y'` set *in Priority*, after which `stg.LoadCustomerContactsFromPriority` +
`stg.MergeCustomersContactsData` carry it through. Until then the STAGE identity is forced by
`database/diagnostics/Simulate-Priority-Inactive-STAGE.sql`, **which the next contact sync reverts** —
if the local portal suddenly signs in as the wrong company again, that is why.

**STAGE carries copied data.** One customer's orders were copied from PROD into STAGE (decision 22).
The undo script is `database/diagnostics/undo_philips_copy.sql`. It is test data, not history.

**Fields with no source yet.** The reports table's `performedBy`, five device-detail fields and three
reports columns currently resolve to `''` because no schema column holds them. They are empty
deliberately — do not wire them to something plausible. The device screen's **"פעולות"** tab is
disabled pending a product decision on what belongs in it, and the profile screen's sub-sites are
local state with no persistence behind them.

**Priority service-call history is half-built.** `SERVCALLS` ↔ `SERNUMBERS` was proven to join
(22 of 22 serials matched for the test customer), but the field that carries the MABA number
("מספר מ.ב.א") has not been located, so the history cannot be tied to a report. Blocked on that, not
on code.

**Infrastructure left open after the outage.** Vercel **Secure Compute** is not enabled, so the
egress address is still not static; and the exact Security-Group rule IT applied has not been read
back — it should be confirmed and tightened to a `/32` once the static IP exists (decision 21).
`/api/health/db` is live on `stg` but **not on `cal`**, which deploys from a different branch.

**SSIS `OnPremCalibrator` still points at AWS**, not at the local server. Unchanged this session; the
SSIS Sensitive-password work was explicitly deferred by the user, as were the malformed customer
e-mail addresses.


### VCT instruments - in flight

**Two of nine BLs have never measured a real signal, for different reasons.**

- **Meatest M-142 - blocked on hardware.** Written from the manual, never verified end to end. Its
  own GPIB circuit is faulty (decision 37) so it must move to RS-232: instrument menu
  `8. Interface = RS232`, `10. baud = 9600`, `11. Handshake = OFF`, and a **straight 1:1** cable
  (2-2, 3-3, 5-5; the instrument is wired as DCE) - *not* the null-modem the 5522A needs. The first
  serial adapter tried was a counterfeit CH340 that fails every open; use the Prolific adapter that
  drives the Hydra logger, or an FTDI one.
- **HP 53181A - the quickest remaining win.** Identified long ago, its no-signal guard works, but it
  has never been fed an input. The Siglent SDG6052X is proven as a source - the same pairing that
  verified the CNT-90 at 1000.000743 Hz against a 1 kHz setpoint. Feed the counter from it.

**Three instruments have only ever run against a resting state.** The 5322A (command set verified,
error queue clean), the 5522A (0 V in standby) and the PRODIGIT 3111 (empty input) have never seen a
real calibration target. That needs a target, not just a cable.

**The 5322A reads only the ground-bond setpoint.** The other ~20 functions are recognised and logged
but have no setpoint query. Adding them is not a matter of writing more builders - see decision 40
for why each one has to be gated on the current mode.

**Remote output enable is unwired for all six source instruments** (decision 38). Product decision,
not a coding gap.

**Two devices are effectively dormant.** TTI is identified but its state machine is commented out and
it broadcasts nothing. Optidew cannot be auto-discovered at all (Modbus, no `*IDN?`) and needs a
static tunnel.

**Transmille 3200A is not written** and should not be attempted without the hardware (decision 39).

### Known bugs found this session and deliberately not fixed

- **`Libraries/Connectors/JSON/FileReadWrite.cs` writes with `FileMode.OpenOrCreate`**, which does
  not truncate - a shorter save over a longer file leaves valid JSON plus a garbage tail. The three
  VCT settings classes were fixed; this shared helper was not, so anything using it inherits the bug.
- **The WebSocket message parser does not strip the closing brace.** It splits JSON by hand, so the
  **last** field of a message parses with `}` attached - a status message ending in `"Value":"Start"`
  yields `Start}` and is ignored. One of the parsers already works around it by stripping `{`; the
  others do not. Sending a throwaway field last is the current workaround.
- **A stale Windows service keeps taking the WebSocket port.** `MabaCalibrationServer` runs an old
  build from a temporary verification directory, restarts within seconds of being stopped, and holds
  port 5001 so a dev server cannot open its listener. It has no recovery actions configured, so
  something else is starting it. Setting it to Manual start was proposed and **not** done - it
  changes how the machine boots and needs the owner's decision.
- **An absent GPIB tunnel can still wedge the device tick.** Auto-discovery avoids creating one, so
  this is mostly latent now, but a statically configured tunnel for a disconnected instrument will
  still block every other device.
