# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Documentation and UI strings are Hebrew-first (RTL) — preserve Hebrew text verbatim when editing.
`README.md` and `docs/architecture.md` are both in Hebrew and are the primary references for the
VCT server; **read `docs/architecture.md` before changing anything under `Systems/`**.

## What lives here

This repo holds several independently deployed systems that share a domain (MABA calibration), not
one application:

| Area | Stack | Notes |
|------|-------|-------|
| `Systems/VCT/`, `Systems/Hydra-Group/` | C# **.NET 4.8** | The VCT hardware server. `UnifiedSystemV1.sln`. |
| `Systems/CustomerPortalApi/`, `InstructionAssistant/`, `Priority/`, `ReportArchiveSync/` | C# **net10.0** | Separate services, own csproj each. |
| `customer-analysis/` | Node + React + Postgres | QCC Analytics dashboard. Undocumented in README — see below. |
| `app/` | Next.js | **Its own git repo**, not a submodule. Do not merge it into this one. |
| `database/procedures/` | T-SQL | One file per SQL Server object, named `<schema>.<Object>.sql`. |
| `archive/` | — | Dead code. Not built. |

`packages/`, `bin/`, `obj/` are not in git; run `nuget restore` before a first C# build.

## Commands

### VCT server (C#)
```powershell
.\scripts\Start-Calibration-Stack.ps1 -BuildServer   # dev: build + run server + app + browser
.\scripts\build.ps1                                  # ConsoleHost only (Debug, MSBuild)
.\scripts\Run-VCT-Core-Coverage.ps1                  # VCT.Core tests; fails under 95% coverage
.\scripts\Build-Installer.ps1 -Version x.y.z         # app + server + Inno Setup installer
```
MSBuild lives at `C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe`
(.NET 4.8 projects will not build with `dotnet build`). The net10.0 services under `Systems/` do use
`dotnet build` / `dotnet test` normally.

App on `http://localhost:3000`, WebSocket on `ws://localhost:5001/ws/` (must match
`NEXT_PUBLIC_WEBSOCKET_URL` in `app\.env.local`).

`Run-VCT-Core-Coverage.ps1` gates on **line *and* branch** at 95%. Branch coverage sits at ~93% on
`master`, so the script exits non-zero even when every test passes — check the "Passed!" line before
believing the run failed, and don't attribute the gate failure to your own change without first
confirming with `git diff --numstat` that you touched a `VCT.Core` source file at all.

### customer-analysis
```powershell
npm run build      # tsx script/build.ts -> dist/index.cjs + dist/public
npm run check      # tsc
npm start          # production bundle
python scripts/gen-priority-queries.py   # after editing either sync-*.py query
```
**`npm run dev` does not work on Windows.** The script is `NODE_ENV=development tsx server/index.ts`
— Unix env-assignment syntax, and npm shells out to `cmd.exe`, which reports
`'NODE_ENV' is not recognized`. Run the server directly instead, from the project directory:
`NODE_ENV=development PORT=5000 npx tsx server/index.ts` (Bash tool), or set `$env:NODE_ENV` first in
PowerShell. Startup takes ~30s — it builds the Priority model index (~44k models) and the customer
cache (~8.9k) before it listens.

There is **no test runner in this project**. Playwright 1.58 is installed at
`../../../maba2000-web/frontend/node_modules/playwright` and its browsers are in the shared
`~/AppData/Local/ms-playwright` cache — import it by file URL from a scratch `.mjs` to drive the UI.
Use `locale: 'en-US'` in the browser context: that is what reproduces locale-dependent bugs here.

## VCT server architecture

The end-to-end pipeline (full diagram in `docs/architecture.md` §1):

```
device --RS232/TCP/Modbus--> IComLayer --> HardwareDeviceHost --> BaseSession --> IDeviceBL
                                              (parser, SN id)      (request queue)  (state machine)
                                                                                        |
                              WebSocket clients <-- ServerCore.BroadcastToWebSockets <---+
```

Points that are not obvious from any single file:

- **`BaseSession` runs one request at a time.** A timer dequeues a single `BaseRequest` per tick;
  a device reply is matched to whichever session is waiting. Adding a request does not send it.
- **`HardwareDeviceHost` owns one physical device** and routes parsed packets to its sessions.
  Device identity comes from the `*IDN?` reply, not from configuration.
- **Three settings files, three classes** — `VCT.json` (`VCTSettings`: tunnels, device timeouts,
  WebSocket prefix), `ComServerSettings.json` (`ComServerSettings`: which `IBLCore` modules to load
  by reflection, IP→master mapping), `HydraBL_Settings.json` (`HardwareBL_Settings`: per-device
  channels, rate, sensor, `Masters[]`).
- **Masters** are reference standards loaded from SQL via `CalibrationRepository.InitMasters`; they
  apply a correction curve to readings.
- Adding a device is a fixed recipe — follow `docs/architecture.md` §4 rather than improvising.

## customer-analysis architecture

An Express + React dashboard over PostgreSQL (`qcc_analytics`), with Drizzle for schema. It is not
covered by the repo README. Two things dominate how it behaves:

**Data comes from two places, and which one matters.** The operational query, financial query and
departments screens read **live from the Priority ERP** (SQL Server) on every request via
`server/priority.ts`; everything else (customers, calibration alerts, return documents) reads
PostgreSQL tables filled by separate Python sync scripts. `DATA_SOURCE=live|local` selects the
source and defaults to live whenever `SQL_SERVER_ADDR` is set.

`server/priority-queries.ts` is **generated** from `sync-operational-query.py` /
`sync-financial-query.py` by `scripts/gen-priority-queries.py`, so the live SQL and the sync SQL
cannot drift. Edit the Python query, then regenerate — never hand-edit the generated file.

**Priority holds ~24 years of history** (1.7M rows on the operational query). Any request that
reaches it without a date range is a full-history scan. The meta call short-circuits and the
departments endpoints clamp an unbounded range to the last three years; keep that property when
touching `server/priority.ts`.

The sync endpoints append without de-duplication, so re-running a sync without `--clear` stacks a
whole duplicate generation and silently inflates every total. When a figure looks too large, check
`select sync_id, count(*) ... group by 1` before believing it.

**Remote access guard** (`server/index.ts`): the app has no login of its own and exposes ~28 write
endpoints. Requests from `127.0.0.1` pass untouched; anything else needs Basic auth
(`DASHBOARD_USER`/`DASHBOARD_PASSWORD`) and is read-only unless `ALLOW_REMOTE_WRITES=true`. With no
password set, remote requests are refused rather than allowed. Keep that fail-safe direction. The one
carve-out is `REMOTE_WRITABLE_PATHS` — the pricing endpoints an authenticated remote user needs in
order to use that screen at all (it is POST-driven even to read an answer). Do not widen it casually.

**Product pricing** (`server/pricing/`, screen at `/pricing`) was a standalone Express app on port
4000 (`Documents/תמחור מוצרים/`, left in place but no longer the thing that runs). Its services were
merged in unchanged; only the wiring differs — the router mounts under **`/api/pricing`**, and the
prefix is mandatory because both it and the dashboard define `/api/customers`. Two things to know:

- The **matcher is not a lookup**. Fuse.js scoring, the learned-overrides store, a Priority model
  index (`MBA_SERNUMBERS`) and optional Claude web-search enrichment all feed one answer, and the
  thresholds were tuned against this exact price list — hence `fuse.js` is **pinned** to 7.3.0 and
  `FUZZY_THRESHOLD` defaults to 0.4.
- `data/pricing/` is **written at runtime** (`customer-overrides.json` is every correction a user
  ever confirmed). It is not a build artifact: a deployment that recreates it empty silently throws
  away the learning. `PRICING_DATA_DIR` overrides the location, which is otherwise resolved from the
  process working directory.

Server deps are bundled into `dist/index.cjs` per the allowlist in `script/build.ts`; the deploy
swaps `dist` without running `npm install`, so a new server dependency that is not on that list
takes the whole service down at startup.

## The calibration station installer

`Installer/setup.iss` (Inno Setup 6) packages the ComServer, the built web app and the launcher
scripts into one `CalibrationSoftware-Setup-vX.Y.Z.exe`. Build it with
`scripts/Build-Station-Installer.ps1 -DbPassword <pw>`, which does config → MSBuild → ISCC →
payload check in one pass and restores `App.config` to its committed default afterwards.

**Where the data comes from.** The topology is
`Priority → on-prem (priority_kyul / kyulan on the PRI instance, via SQL Agent jobs) → AWS (which
*pulls* over a linked server) → calibration station`. **The station reads from AWS.** Do not point
it at the on-prem `Calibrator` database: that is a frozen legacy carcass with none of the app's
tables. See `docs/decisions.md`.

**`App.config` in the repo points at STAGE on purpose.** The build script rewrites it to PROD for
the duration of the compile and puts STAGE back. Never commit it pointing at PROD.

Things that cost a day each and will not be obvious:

- **The web app cannot be built inside OneDrive.** Build it in a plain local folder with a hoisted
  `node_modules`, then pass the paths to ISCC as `/DWebAppStandalone=`, `/DWebAppStatic=`,
  `/DWebAppPublic=`. A good payload is **~2,600 files**; ~18 means the web app silently did not
  make it in, which is why the build script fails below 2,000.
- **There is one AppId and one service name for every version.** Installing to a different folder
  therefore does not give you two working stations — it gives you one station and one orphan whose
  ComServer can still wake up and take a COM port or port 3000 from the real one. Seven of those
  accumulated on the bench in a single day. Setup now detects and removes a previous install found
  in another folder; do not defeat that.
- **The station `.env` is generated, not copied.** `scripts/New-StationEnv.ps1` keeps a whitelist of
  the settings a station actually reads, because shipping `app\.env` verbatim put staging DB
  passwords, SMTP credentials and test accounts on every customer machine. **Adding a required env
  var to the app means adding it to that whitelist**, or the station starts and fails every request.
- **`start-all.bat` must launch the web app through `assets\start-webapp.ps1`, never `node
  server.js` directly.** The shipped `.env` carries only `REMOTE_DATABASE_URL_PROD` / `_STAGE`, and
  that script is what derives the plain `REMOTE_DATABASE_URL` the app requires. Bypassing it gives a
  node process that starts cleanly and then answers **every** request with "Invalid environment
  variables" — the service and the WebSocket look perfectly healthy while the site is dead.
- **A silent install does not start the web app.** The `[Run]` entry is `postinstall skipifsilent`,
  so `/VERYSILENT` leaves only the Windows service running. Interactive installs offer a "Launch
  now" checkbox; from v1.6.7 a Startup shortcut also brings the station up after a reboot.
- **NI-488.2 is deliberately not bundled** — see `Installer/DRIVERS.md` and `docs/decisions.md`.

### Verifying a station honestly

The service only brings up the ComServer and the WebSocket. `HTTP 200` on port 3000 proves nothing
on a development machine: **a `next dev` server from the local build folder answers on the same
port**, and an installed web app that loses the race dies quietly. Confirm which process owns 3000
before believing a result — a dev build's HTML references `[turbopack]...hmr-client` chunks and a
production one does not.

Logs are the fastest route to an answer and they ship themselves: `assets/publish-logs.ps1` copies
a station's logs to a per-machine folder on the `maba2000` share at every launch, so a customer
machine can be diagnosed without visiting it. Use the **UNC path**, never a drive letter — drive
mappings are per-user and a station may not have the same one.

## The two SQL Servers — "the local" and "the global"

The user's words, and worth adopting: **the local** is the SQL Server on the Priority LAN
(`maba-priority\PRI`); **the global** is the AWS instance. They are not two copies of one thing.

| | local — PRI | global — AWS |
|---|---|---|
| Version | SQL Server 2019, all DBs at compat 110 | SQL Server 2022, compat 160 |
| Server collation | `Hebrew_BIN` | app DB is `Latin1_General_100_CI_AI_SC` |
| 26 databases | `amaba` (Priority ERP, ~76 GB) · `kyulan` · `priority_kyul` · `Calibrator` · website + tenant DBs | `Calibrator` (STAGE) · `CalibratorProd` (PROD) · `QCCData` · `MBAWebSite` · `SSISDB` |

Which local database is which — this trips people up:

- **`amaba`** — the Priority ERP. The only local schema the global has any relationship with.
- **`kyulan`** — the *live* legacy calibration database (MABA2000 lineage: `tblInstr`,
  `tblInstrCorrections`, ~117 procs). Written to daily. **Nothing in the new system connects to it**,
  and it shares **zero** table names with the AWS app schema. It is a different data model, not an
  older copy.
- **`priority_kyul`** — Priority's own load/staging tables (`MBA_CALIBLOAD`, `MBA_DOCLOAD`, …).
- **`Calibrator` on PRI** — an abandoned on-prem copy of the app DB, frozen since 2025-03-17, with an
  older *flat* schema (an `Orders` table carrying customer name and device description in one row).
  It has no `Customers` and no `OrderWorkPlans`. Do not mistake it for the app database.

### How they actually talk

Three mechanisms; only one carries live traffic.

1. **global → local, live, read-only.** A linked server on both STAGE and PROD; ~16 procedures read
   `amaba` only (`PART`, `PARTTEXT`, `SERNUMBERSTEXT`, `FAMILY`, `ORDERSTEXT`, `INVOICES`, `CPROF`).
   No procedure writes back into PRI.
2. **local → global, dormant.** Seven procedures in `amaba` / `WebSite` / `WebSiteTest` write to
   **`QCCData`** — the QCC *website* database, not the calibration app. **No SQL Agent job calls any
   of them**, and their targets stopped updating (`OrdersFULL` in late 2024).
3. **Priority ↔ `priority_kyul`, every 5 minutes.** Jobs `to_maba_from_priority_ALL` and
   `to_priority_MBA_CALIBLOAD`. Both are entirely local — neither mentions the AWS host. The other
   ~15 jobs on PRI are DBA/monitoring (`msys_monitor`), not sync.

**So: no calibration data syncs between local and global in either direction.** If a task assumes it
does, verify before building on it.

### The schema linkage that does exist

`amaba` → the AWS app, through `*FromSource` keys, plus twelve `stg_*` landing tables
(`stg_Customers`, `stg_Orders`, …) merged by procedures in the **`stg` schema**.

| AWS column | Priority | verified |
|---|---|---|
| `Customers.CustomerIdFromSource` | `amaba.CUSTOMERS.CUST` | 11,327 / 11,327 |
| `CustomerRemarks.CustomerIdFromSource` | `amaba.CUSTOMERS.CUST` | 1,534 / 1,534 |
| `stg_Orders.SERN` / `.ORDNAME` | `SERNUMBERS.SERN` / `ORDERS.ORDNAME` | |

Internal vs external **calibrator** (כייל — a *person*, not a calibration) is `OrderDetails.IsInHouse`
(1 = מעבדה, 0 = לקוח) inside the single AWS database, filtered per screen by `@Page` in
`GetDevicesGroupsByOrder`. There is no local/global split behind it, in any layer.

## Database work

`database/procedures/` mirrors SQL Server objects one file per object, named `<schema>.<Object>.sql`.
Sibling folders follow the same idea: `schema/dbo.<Table>.<Column>.sql` for a column add,
`constraints/`, `data/` for one-off data fixes, `jobs/`, `diagnostics/`. `database/Compare-Schema.ps1`
diffs the STAGE and PROD schemas — schema changes are expected to land in both, and STAGE-only
procedures are a known source of "works here, missing there" bugs.

House style for anything that writes: a header comment saying **why** (with the measured numbers that
justify it), an `@Apply BIT = 0` dry-run parameter that reports what would change and touches nothing,
idempotency so a second run is a no-op, and `OPENQUERY` when the work belongs on the Priority side.
`dbo.RefreshCustomerRemarksFromPriority` is the reference implementation. Deploy to STAGE, verify,
then PROD.

**Address rows by their Priority key, never by an identity column.** `CustomerId`, `CustomerContactId`
and friends are identities and differ between STAGE and PROD — the same fourteen contacts are
`44080, 19708, …` on PROD and `48691, 15512, …` on STAGE. `CustomerIdFromSource` (= Priority `CUST`)
is stable everywhere. A hardcoded id list written against one environment will hit unrelated rows in
the other.

**STAGE and PROD are not interchangeable, and the differences are silent:**

- **User ids differ between them.** The web app stores the signed-in user in `localStorage` as a
  bare numeric id with nothing recording which database it came from, so switching
  `REMOTE_DATABASE_URL` without signing out re-points you at *a different person* with no error.
  Calibrator 1 signs the report. **Sign out and back in after switching environments.**
- **Role ids differ too.** Never hard-code a `UserRoleId`; match on `UserRoleName`.
- A `LIKE` comparison in a case-insensitive database **cannot tell `CalibratorID` from
  `CalibratorId`**. When you need to prove a casing fix landed, force it:
  `... COLLATE Latin1_General_100_BIN2 LIKE ...`.

## Priority data traps

These are properties of the **data**, not of any one codebase, so they resurface anywhere that reads
Priority.

- **`CUSTDES` is not unique.** Priority keeps a company's retired record beside its live one, under
  the same name and a different customer code. Any dedupe keyed on the name alone keeps whichever row
  SQL Server happened to return first — which is as likely to be the dead one. 226 name groups
  covering 465 rows are duplicated this way. The authoritative flag is **`CUSTSTATS.INACTIVE = 'Y'`**
  (join `CUSTSTATS.CUSTSTAT = CUSTOMERS.CUSTSTAT`; -5 לא פעיל, -4 מוגבל, -3 אזהרת חסימה, -2 פעיל,
  -1 זמני). `COMPSTATUS` and `STATUSFLAG` are useless — `COMPSTATUS` is blank on every row. When
  collapsing customers by name, order active-first and keep the discarded record's code searchable,
  or a user typing the code they see in Priority gets an empty screen.
- **`SERNUMBERS.SERNUM` is compound.** A registered device is stored as customer-code prefix + the
  customer's own asset number + its SAP number, e.g. `2025-MPL-244(70135180)`, or with a
  manufacturer serial and a slash. The customer's own spreadsheet sends those parts in *separate
  columns*, so an exact match on the whole string never hits. Match on components — split on
  brackets, slash and whitespace, but **not on `-`**, which lives inside the identifier itself.
- **A digits-only key throws away the letters that disambiguate.** The same customer holds both
  `EQP-130` and `MPL-130`; reducing a query to `130` returns the wrong instrument, with a confident
  100% score and therefore a wrong part number and price. If both sides carry letters they must agree.
- Priority dates are minutes since 1988 in some tables; `3000-12-31` is a "never" sentinel, not a
  write timestamp. Don't read either as freshness.

## Windows / PowerShell gotchas that will bite

- **`.ps1` files containing Hebrew must be saved UTF-8 *with BOM*** or the PS 5.1 parser garbles
  them. Validate with `[Parser]::ParseFile(...)` before shipping a script.
- **Console output should be ASCII.** Windows Server consoles render Hebrew as mojibake, so scripts
  handed to other people print English even though their docs are Hebrew.
- **Do not redirect a native executable's stderr with `2>&1` under `$ErrorActionPreference='Stop'`** —
  PS 5.1 turns it into a terminating error, so your own error handling never runs.
- `psql` on Windows does not permute arguments: all options must come **before** the connection URL.
- **`sqlcmd -i` on a UTF-8 `.sql` file silently mangles Hebrew.** It reads the file in the console
  codepage, so `N'לקוח'` is stored in the procedure as `N'׳׳§׳•׳—'` — the deploy *succeeds*, and the
  damage only shows when a screen renders the literal. Always pass **`-f 65001`**, and verify after
  deploying: `SELECT CASE WHEN OBJECT_DEFINITION(OBJECT_ID('dbo.X')) LIKE N'%לקוח%' THEN 'OK' ELSE
  'CORRUPTED' END`. Hebrew inside a *comment* is corrupted just as quietly.
- **A script that logs must be able to log before it can fail.** `start-webapp.ps1` ran under
  `$ErrorActionPreference='Stop'` and created its log folder *before* defining its logger, so on a
  station where `Program Files\...\logs` was not writable it died having written nothing anywhere —
  indistinguishable from never having been started. Set up logging first, with a fallback, and wrap
  the writer so logging can never be the thing that stops the job.
- When handing someone a command to paste, remember **the console prompt is not part of it**.
  Copying `PS C:\...> powershell -File ...` runs `PS`, which is an alias for `Get-Process`, and the
  error message names `Get-Process` rather than anything you recognise.

## Inno Setup gotchas (`Installer/setup.iss`)

The Pascal Script dialect is small and its failures are compile-time but cryptic. All three of
these were hit in one session:

- **A brace-delimited constant inside a `{ ... }` comment ends the comment.** Writing `{sys}` in a
  Pascal comment closes it at that point and the rest becomes code. Spell the constant out in words.
- **`AppProcessMessages` does not exist**, and neither does `WizardForm.Refresh`. You do not need
  them: `Exec` runs its own message loop, so a `WizardForm.StatusLabel.Caption` set just before a
  step is painted when that step starts.
- **`SetupSetting("AppId")` returns the brace-escaped `[Setup]` value** (`{{8F3A…`). Emitting it
  into a Pascal string literal produces a registry path with a doubled brace that matches nothing
  and fails silently. Write the GUID out.

`ISCC` error text is truncated when it comes back through PowerShell's `NativeCommandError`. Run
`ISCC.exe` directly and read its stderr when a compile fails; the real message is one line and
usually names the exact identifier.

## Working style the user has corrected me on

- **Check a capability before claiming you lack it.** I twice justified not doing something with a
  limit I had not verified. The `kyulan` login is **`sysadmin` on PRI** with `dbcreator` and
  `CREATE ANY DATABASE`, on a volume with hundreds of GB free — the actual constraint on infra work
  is the tool-permission prompt and the risk of touching a production ERP box, which is a different
  argument and has to be made honestly as such.
- **Measure, don't recite.** Numbers from a previous session are stale by definition. Re-query before
  presenting a figure; the user checks these against the servers.
- **A regex is not a parser.** Counting arguments in SQL by splitting on commas produced a confident
  and completely wrong "13 procedures must be rewritten for SQL 2019" — every hit was a comma inside
  `ISNULL(...)` or an escaped quote in dynamic SQL. The real count was zero. Count top-level
  delimiters, then read the surrounding lines before reporting.
- **Verify a claimed fix against the source of truth, not against your own new code.** Cross-checking
  the pricing matcher against Priority SQL directly is what showed that 11 "regressions" were in fact
  corrections of previously wrong matches.
- Correct yourself plainly and in one line when a measurement overturns something you said. Several
  findings this session reversed earlier ones.
- Terminology: **"calibrator" means כייל, a person.** Internal/external calibrator, not
  internal/external calibration.

## Small mechanical traps

- Node scratch scripts that `import sql from 'mssql'` must live **inside `customer-analysis/`** —
  module resolution is by script location, so a script in a temp directory cannot find the package.
  Clean them up afterwards; they are easy to leave behind.
- **`OBJECT_DEFINITION(OBJECT_ID('dbo.X'))` returns empty for objects in the `stg` schema.** `stg` is
  a real schema, not a name prefix: `stg.stg_Customers`, `stg.MergeCustomersData`. Look objects up
  through `sys.objects` joined to `sys.schemas` rather than assuming `dbo`.
- **Git Bash mangles Hebrew in `curl --data-urlencode`.** A Hebrew search that returns nothing from
  the shell may work perfectly — re-test with `fetch` and `encodeURIComponent` from a Node script
  before believing the server is at fault.
- A heredoc in the Bash tool eats backslash escapes; write files containing `'\'` with the Write
  tool instead.
- Several `.config` files in this repo carry plaintext database passwords. Don't add more, don't echo
  them into terminal output, and don't paste them into commit messages or docs.
