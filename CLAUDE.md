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

### customer-analysis
```powershell
npm run dev        # tsx server/index.ts, serves API + Vite client
npm run build      # tsx script/build.ts -> dist/index.cjs + dist/public
npm run check      # tsc
npm start          # production bundle
python scripts/gen-priority-queries.py   # after editing either sync-*.py query
```
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
password set, remote requests are refused rather than allowed. Keep that fail-safe direction.

## Database work

`database/procedures/` mirrors SQL Server objects one file per object. `database/Compare-Schema.ps1`
diffs the STAGE and PROD schemas — schema changes are expected to land in both, and STAGE-only
procedures are a known source of "works here, missing there" bugs.

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
