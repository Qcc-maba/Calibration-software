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
| `Systems/CustomerPortalApi/`, `InstructionAssistant/`, `OrderAttachments/`, `Priority/`, `ReportArchiveSync/` | C# **net10.0** | Separate services, own csproj each. Several run as Windows Services **on the same box** — see "Windows services on the MABA machines". |
| `customer-analysis/` | Node + React + Postgres | QCC Analytics dashboard. Undocumented in README — see below. |
| `app/` | Next.js | The web app **and** the customer portal. **Its own git repo**, not a submodule — do not merge it into this one, and do not run it from inside OneDrive. |
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

### The order-attachments service (net10)
```powershell
dotnet test  Systems/OrderAttachments.Tests      # unit + a live .msg pipeline suite
dotnet run --project Systems/OrderAttachments    # console mode, listens on 5313
.\scripts\Install-OrderAttachments-Service.ps1   # installs it as MabaOrderAttachments
```
`Systems/OrderAttachments.Tests/LiveMsgPipelineTests.cs` reads real `.msg` files off the Priority
share; it is skipped where the share is unreachable rather than failing, so a green run does **not**
prove the conversion path works. Prove that with `/health` and one real PDF.

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

### The customer portal web app (`app/`)

`app/` is a **separate git repo** (Qcc-maba): Next.js App Router + tRPC + Prisma over SQL Server.
It will not run from inside OneDrive — Turbopack cannot resolve the pnpm symlinks there — so the
working copy lives in a plain local folder outside OneDrive, and every command below is run there.
The working branch is `stg`; **`main`** is Vercel's Production branch and what `cal` deploys.
(`origin/HEAD` points at `main` — there is no `master` in that repo.)

**`main` lags `stg` by months, and that makes every release an all-or-nothing one.** On 2026-09-07
`main` was 205 commits and 639 files behind `stg` — its previous commit was from 10/08. There is no
way to ship one portal fix to production without shipping everything else on `stg` with it: four
months of calibration-wizard, coordinator-orders and packing work land the same minute the portal
does. Merging `stg` → `main` is therefore a **release of the whole internal system**, not a portal
deploy, and it should be announced as one. Attaching a customer domain to a *branch* deployment is
not an escape hatch: a branch build is `VERCEL_ENV=preview`, which `env.js` resolves to
`REMOTE_DATABASE_URL_STAGE`, so the portal would serve customers STAGE data.

That merge conflicts in a handful of files. Take `stg` in each — it is newer and a superset — but
read `src/env.js` before you do: the database-URL resolution is identical on both sides and the
conflict there is whitespace only.

```powershell
npm run dev            # Next dev server on http://localhost:3000
npm run verify         # the regression suite - run this after every task
npm run build          # production build
```

`npm run verify` (`scripts/verify.mjs`) is the "did I break anything" gate. Four sections, ~37
checks:

| Section | What it proves |
|---|---|
| code | `tsc`, `eslint`, `vitest` |
| sources | no mock module is imported by a customer screen, no hardcoded clock |
| http | every route answers and `/api/trpc` compiles |
| browser | signs in, then walks every screen, **every tab and every dialog**; fails on placeholder text or a console error |

It deliberately distinguishes "the dev server stopped answering" from "this screen is broken" —
believe that distinction, it exists because a dead dev server was repeatedly misread as a regression.

The portal's own API (`Systems/CustomerPortalApi`, net10) is what sends the sign-in code:

```powershell
dotnet run --project Systems/CustomerPortalApi --urls http://localhost:5314
```

**Port 5312 is already taken** by the installed MabaInstructionAssistant service, hence 5314. Keep
`CUSTOMER_PORTAL_API_URL` in the app's env in step with whatever port you pick, and keep
`CUSTOMER_SESSION_SECRET` identical on both sides or the session cookie the API mints is rejected by
the app without any error that says so.

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

### Instrument bring-up (`docs/devices/`)

`docs/devices/` is split by what an instrument does, and the code folders mirror it:
`electronics/` (volts, current, frequency, power) and `temperature/`. The folder split is
**organisational only** — namespaces stayed `...HydraDevices.BLCore` / `...HydraDevices.Device` with
no extra level, so a `TypeName` in `ComServerSettings.Modules` does not change when a file moves.
`ComServer.BL.csproj` lists every file explicitly, so **a move that does not update the csproj
silently drops the file from the build.**

Nine electronics instruments have BLs. Each has a `protocol.md` whose status header states plainly
whether it was verified against hardware or written from a manual — trust that header, and do not
promote a device to "verified" without a capture.

**The one rule every source instrument enforces:** the command that energises an output is built,
marked, and **never issued from an init sequence or a read loop** — only from an explicit commanded
target. Tests assert this per device (no init step is the energise command; the init *ends*
de-energised; a setpoint command carries no output-enable). Keep that shape when adding a source.

### Instrument gotchas that cost real time

- **`?` is not always the last character of a query.** `:MEASure:VPP? CHANnel1` is a query with an
  argument. Detecting queries with `EndsWith("?")` means the reply is never read and the session
  stalls after one measurement. `VisaCom.IsQuery` / `GpibCom.IsQuery` scan for `?` anywhere.
- **A frequency counter with no input signal blocks forever.** It waits for edges and never returns a
  terminator, wedging the session. Both counters guard by measuring *voltage* first (a query that
  always answers) and skipping the frequency query when the input is dead.
- **A SCPI query can have side effects.** On the Fluke 5322A, `SAF:<function>?` *selects* that
  function. A polling loop that reads a setpoint unconditionally drags the calibrator out of whatever
  the operator chose, every tick. Read the mode first, then ask only for the mode you are already in.
- **`*IDN?` can report a different model depending on a front-panel menu** (5322A vs 5320A
  emulation). Identification matches both spellings and normalises to one SN.
- **Only one interface is active at a time** on most of these instruments (5522A `HOST`, 5322A
  `Setup > Interface > Active interface`, M-142 `8. Interface`). Selecting GPIB makes the serial and
  USB ports *silently dead* — total silence, never an error.
- **Two kinds of instrument USB.** A virtual COM port (CDC) needs no NI software at all; **USBTMC**
  needs NI-VISA both for its kernel driver and for `visa32.dll`. The scope and the Siglent generator
  are USBTMC; the 5322A's USB is a plain COM port.
- **Reply terminators vary and are not documented consistently.** The Pendulum CNT-90 ends replies
  with `
` only. Code that expects CRLF reports a corruption that is not there.
- **Settings files must be written with `FileMode.Create`.** `OpenOrCreate` does not truncate, so
  saving a shorter file over a longer one leaves valid JSON followed by a garbage tail. Fixed in the
  three VCT settings classes; **`Libraries/Connectors/JSON/FileReadWrite.cs` still has it**, so
  anything using that helper inherits the bug.

### NI-488.2 / NI-VISA on a station

- **The VCT server is x86** (`gpib-32.dll` ships 32-bit only), so it needs the **32-bit** VISA
  runtime in `SysWOW64`. A 64-bit-only VISA install leaves the server unable to open any USBTMC
  instrument while every GUI tool still works.
- **NI-488.2 and NI-VISA share components.** Uninstalling NI-488.2 also removes 32-bit `visa32.dll`,
  which kills USBTMC for instruments that have nothing to do with GPIB.
- **A GPIB adapter can enumerate perfectly with no driver bound.** Device Manager shows `Status OK`
  and error code 0, NI MAX lists it by its raw `USB\VID_...` path and says "Windows does not have a
  driver associated with your device", the `ni488k` driver stays `Stopped`, no board is registered,
  and VISA answers `0xBFFF00A5` ("interface number not configured") on `GPIB0::INTFC`. This happens
  when NI-488.2 is installed while the adapter is already plugged in. Fix from an **elevated** prompt
  with `pnputil /add-driver` on the staged `ni488.inf` followed by `pnputil /scan-devices`. The tell
  that it worked: the device renames itself from `GPIB-USB-HS+` to **`NI GPIB-USB-HS+`**.
- `viFindRsrc("GPIB?*INSTR")` is not a reliable bus scan — it depends on what is registered in NI
  MAX. `TransportDiscovery.FindGpibListeners` asks the driver directly (`FindLstn`) as a fallback,
  which finds instruments VISA misses.

### Reading a failed serial port

The error from `SerialPort.Open()` distinguishes four very different faults, and guessing wastes
hours:

| Error | Meaning |
|---|---|
| `A device which does not exist was specified` | stale registry entry, no device behind it |
| `A device attached to the system is not functioning` | device present, driver refuses it — the counterfeit-chip signature |
| `Access denied` | another process holds the port |
| opens fine, then silence | cable, baud rate, or the instrument's interface setting |

Counterfeit PL2303 and CH340 adapters enumerate cleanly, show no warning icon, use the genuine
VID/PID, and fail **every** open at **every** baud rate. Two of them have appeared on this bench.

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

## The customer portal — where it runs, who the user is, and how it reads Priority

The portal is the customer-facing half of `app/`. Two Vercel deployments: **`cal.qcc.co.il`** (prod,
reads `CalibratorProd`) and **`stg.qcc.co.il`** (staging, reads `Calibrator`). Everything below was
measured; don't re-derive it from assumptions about where a Vercel site lives.

**The functions do not run on our servers, and not in Israel.** The response header
`X-Vercel-Id: fra1::iad1::…` reads *PoP that received the request* :: *region that executed it*, and
`iad1` is **AWS us-east-1**. So the connection to SQL on 1433 leaves from Virginia, not from the
office. Any firewall or Security-Group rule that allow-lists "our" addresses kills both sites while
everything still looks healthy from inside the office — which is exactly what happened on 2026-09-08.
`docs/IT-REQUEST-sql-firewall.md` holds the diagnosis and the request that fixed it. The durable fix
is Vercel **Secure Compute** (a static egress IP, so one `/32` rule like the office's); it is not yet
enabled.

**Telling a network problem from a code problem in ten seconds:**

```
curl https://stg.qcc.co.il/api/health/db
```

`/api/health/db` runs `SELECT 1` and returns `{database, ms, name, code}` — never the driver message
and never the connection string, because the endpoint is public. Read the *shape* of the failure:

| Symptom | Meaning |
|---|---|
| `{"database":"ok"}` in under a second | the path is open — look at the code |
| timeout at **almost exactly 10.0s** | Prisma's connect timeout: packets are being dropped, i.e. a Security Group / firewall |
| immediate refusal | the service is down, or the port is closed at the OS |
| fast rejection | credentials |

Ten seconds of silence is never a wrong password — a wrong password is refused instantly.

### The identity chain

A portal login is an **e-mail address, and an e-mail address is not one customer.** Three procedures,
in order:

1. `dbo.GetPortalCustomerIds` — every customer the address is a contact of. When it is attached to
   several, **the customer that actually has devices wins**. That rule exists because a contact left
   behind on a dead customer record was signing a real person into an empty portal under the wrong
   company name.
2. `dbo.CreateCustomerPortalOtp` — issues the code. Rate limit **5 per 900s**; a repeated test loop
   trips it and the screen then says "שליחת הקוד נכשלה" for reasons that have nothing to do with mail.
3. `dbo.GetCustomerPortalContactByEmail` — the session's contact, and the name the mail is addressed to.

`CustomerAuthService` has a development sign-in code, gated on the Development environment **and** a
loopback caller. It must **not** suppress sending the real mail — it did for one session, and the
only visible symptom was "the mail never arrives". Development tolerates a send *failure*; it never
skips the send.

### Priority is the source of truth, and nothing is ever deleted from it

A contact that disappears from Priority is marked **inactive**, never removed.
`CustomerContacts.IsActive` carries `PHONEBOOK.INACTIVE` through
`stg.LoadCustomerContactsFromPriority` → `stg.MergeCustomersContactsData`, and the portal procedures
filter on it. Deleting rows to make a screen behave is not an option, in either direction.

### Reading Priority through the linked server — traps that cost a day each

- **Put the whole statement inside `OPENQUERY`.** The invoice→attachment join written with
  four-part names issued one remote call per row: **65 seconds** for 1,361 invoices. The identical
  join pushed entirely into `OPENQUERY` runs in **0.7–0.8s**.
- **`dbo.fnUnreverseVisualText` is for display text, not for identifiers.** Priority stores Hebrew in
  visual (reversed) order, so contact and product names must be un-reversed — but running it over an
  attachment *path* reverses the ASCII path too and nothing opens. `GetCustomerInvoicesFromPriority`
  therefore returns only the ASCII **directory** from `EXTFILES`, and the API picks the PDF inside it
  by file size.
- Cross-server joins fail with `Cannot resolve the collation conflict between
  Latin1_General_100_CI_AI_SC and Hebrew_BIN`. Add an explicit `COLLATE Hebrew_BIN` on the compared
  column.
- Invoice numbers beginning with **`K`** are receipts (קבלה), not invoices, and correctly have no
  document. The document type comes from `IVTYPES.IVDES`; `OTYPE = 'C'` filters to the customer side.
- Only a minority of invoices have a stored attachment at all — 156 of 1,361 for the customer this
  was built against. "No document" is usually the truth, not a bug.

### Next.js / tRPC behaviour that looks like a bug and is not

- **A new route file 404s until the dev server is restarted.** `/customer` and `/api/health/db` each
  "did not work" for this reason alone.
- **`loggerLink` logs only in dev, or when the result is an `Error`.** In production a tRPC failure
  reaches the browser as a bare 500 with the stack stripped — which is the whole reason
  `/api/health/db` exists.
- **A screen's `innerText` says nothing about a form.** Inputs carry their content in `.value`; a
  profile screen that read as empty was fully populated. Check `input.value` before reporting missing
  data.
- **A Playwright page in a fresh context has no session cookie**, and a dialog left open makes the
  body inert — both produced "sign-out is broken" reports that were the harness, not the app.
  Playwright itself is borrowed from the sibling `maba2000-web/frontend` checkout, and the
  machine-level `PLAYWRIGHT_BROWSERS_PATH` points at a *different* build: point it at the per-user
  `ms-playwright` cache or you get "Executable doesn't exist".
- The pre-commit hook type-checks `.next/types/validator.ts`, which goes stale and references routes
  that no longer exist — delete the file rather than the route. `scripts/*.mjs` sits outside
  `tsconfig`, so the type-aware eslint rules cannot parse it; it is ignored in `eslint.config.js` on
  purpose.
- When the dev server dies mid-run, delete `.next` and start it **detached** — a server started from
  a tool call dies with the call.
- **A `not-found.tsx` inside a route segment does not catch unmatched addresses.** It catches only a
  `notFound()` thrown by a page in that segment. A URL matching *no route at all* reaches the **root**
  `app/not-found.tsx` and nothing else. A segment-level file therefore looks like it works — it
  renders for every case you test by calling `notFound()` — and does nothing for the case you wrote it
  for. Verified by request, not by reading: the segment file was in place and
  `/customer/does-not-exist` still returned Next's built-in *"404: This page could not be found."*
- Because the root boundary answers for **both audiences**, anything rendered there has to read the
  `host` to know whether it is talking to a customer or to a coordinator. `cal.qcc.co.il` showing
  "back to portal" walks an internal user out of the system they were using.

## Windows services on the MABA machines

Three of these services are installed **on the same host**, and that fact is the source of the worst
class of bug in this repo: a service that works perfectly until another one is installed, then breaks
the *other* one, silently, at a distance.

| Service | Port | Reads its URL from |
|---|---|---|
| `MabaInstructionAssistant` | **5312** | its own key |
| `MabaOrderAttachments` | **5313** | `OrderAttachments__Urls` |
| `Maba.VCT.CustomerPortalApi` | 5314 in dev | its own key; not installed on the dev workstation |

Verify with `Get-NetTCPConnection -State Listen -OwningProcess <pid>` rather than trusting a comment —
the header comment in `Systems/OrderAttachments/Program.cs` names CustomerPortalApi as the service it
collided with on 5312, and the port is actually the Instruction Assistant's.

**Never configure one of these through a variable another process also reads.** Two concrete failures,
both mine, both the same shape:

- **`ASPNETCORE_URLS` is machine-wide and every ASP.NET service on the box reads it.** Each installer
  set it, so whichever ran last silently repointed the other service. On 2026-09-07 two of them ended
  up on 5312: one won the port and answered `/health` for requests meant for the other, which was in a
  crash loop with `Failed to bind to address http://127.0.0.1:5312: address already in use`. A health
  check that passes because the *wrong service* answered it is the worst part of this failure. The fix
  is a key only that service knows about (`OrderAttachments__Urls`), read in `Program.cs` via
  `builder.WebHost.UseUrls(...)`.
- **`PLAYWRIGHT_BROWSERS_PATH` is read by every Playwright on the box.** Setting it machine-wide so a
  service account could find Chromium also redirected the *frontend's* Playwright, which pins
  chromium-**1208**, into a directory holding only **1234** — "Executable doesn't exist", in a project
  nobody had touched. The fix is `Environment.SetEnvironmentVariable` inside `Program.cs`, which
  affects that process and the driver it spawns and nothing else.

The general rule: **a setting that configures one service must not be reachable by another.** If the
only way to set it is a machine-wide variable, set it in-process instead.

Installing them, the parts that are not obvious:

- **A service secret must be `Machine` scope**, not `User`. A `LocalSystem` service does not read a
  user-scope variable, and the failure is a null connection string at startup.
- **Use `New-Service -Credential`, not `sc.exe`.** `sc.exe create ... password= ...` puts the password
  on the command line and fails with **exit 1639** (invalid command line) on anything with special
  characters in it.
- **A domain account needs "Log on as a service" granted first**, or the service fails to start with
  **error 1069** and no other clue. Grant `SeServiceLogonRight` with `secedit` as part of the install.
- **Validate a typed password before using it** (`PrincipalContext.ValidateCredentials`). An
  installer that reads a password blind and hands it to `New-Service` reports "the password is wrong"
  when what actually happened is that it was mistyped into a masked prompt.
- **`\\tsclient\...` exists only inside an RDP session.** Commands handed to someone to run "on the
  server" must not use it, and a `\\tsclient` failure usually means they ran it on their own machine.

## The order-attachments service (MBA-930)

Serves the documents Priority hangs off an order — quotes, mail threads, drawings — to the calibrator,
converted to PDF. `Systems/OrderAttachments/`, listening on 5313, plus five SQL objects and a proxy
route in `app/`.

```
Priority EXTFILES --(OPENQUERY, cached)--> dbo.CrmOrderAttachments
                                                   |
  browser --> app /api/order-attachments/... --> :5313 --> convert --> PDF cache on disk
```

**The cache table is refreshed, not queried live.** `dbo.RefreshOrderAttachmentsCache` does the whole
`TYPE='O'` set in **one** `OPENQUERY` round-trip and MERGEs it; `@IncrementalOnly BIT = 0` follows the
house dry-run convention. The read side is `dbo.GetOrderAttachmentsByOrder` (one row per file) and
`dbo.GetOrderAttachmentCounts` (batched by CSV of order ids, because the work-assignment grid renders
a page of orders and must not issue one call per row).

Four things about the Priority data that will mislead you:

- **The key is `(order, EXTFILENUM)`, not `(order, LINE)`.** `LINE` has three distinct values in the
  whole table and repeats within an order — order 106663 has two files, both `LINE = 0`. Measured:
  `distinct (IV, EXTFILENUM)` = 15,326 = the row count; `distinct (IV, LINE)` = 13,239. Keying on
  `LINE` gives a primary-key violation on the first full rebuild, and an order can hold **12** files,
  not 4.
- **`EXTFILES.FILESIZE` is not the file size.** 15,225 of 15,326 rows report `74`, which is the length
  of the path string. A row reporting `74` was a 522,752-byte `.msg`. It is deliberately not cached —
  do not use it to pick "the real document".
- **Paths are truncated at 80 characters.** `LEN(RTRIM(path)) >= 80` flags exactly 35 rows; those
  files cannot be opened and the UI must say so rather than showing a broken button.
- `.msg` files carry **Windows-1255**, and .NET ships only Unicode code pages. Without
  `CodePagesEncodingProvider` every Hebrew mail fails at runtime with *"No data is available for
  encoding 1252"* — while `NU1510` insists the `System.Text.Encoding.CodePages` package is
  unnecessary and the project compiles fine without it. That warning is suppressed on purpose.

**A document that cannot be converted must still be visible.** The list returns such parts with an
`Error` instead of omitting them, and the endpoint answers **422**, not 500 — the request was valid,
this one document just cannot become a PDF. The calibrator needs to know the document exists.

## The portal's own API in production — `MbaCustWeb`, IIS and TLS

The portal is two halves on two machines. The **screens** are the Vercel app. The **one-time-code
login** is `Systems/CustomerPortalApi` (net10), installed as the Windows service
`MabaCustomerPortalApi` on **`MbaCustWeb`** — which is also the production SQL host. Putting a
public-facing role on the production database server was approved deliberately (2026-08-31); it is
not an accident to be tidied away.

**It listens on 5312 there.** That is the port the *Instruction Assistant* occupies on a development
workstation, which is why the dev instructions above say 5314 — different machines, both correct.
The overlap is not harmless: a local dev instance of this API on 5312 answers `/health` with a JSON
body identical to production's, so a health check run in the wrong window looks like proof that the
server is fine. Confirm `hostname` first.

`scripts/Install-CustomerPortalApi-Service.ps1 -SkipPublish -PublishDir <dir>` installs from bits
published elsewhere — the default path runs `dotnet publish`, which would need source and the SDK on
a production SQL box. Publish `--self-contained` so the server needs no .NET runtime either.
`scripts/Verify-PortalApi-Deploy.ps1` is the gate: it must print **STAGE A PASSED**, and a `SKIP` is
not a pass. `docs/PORTAL-DEPLOY-RUNBOOK.md` is the procedure; the rest of this section is what the
runbook did not say and what cost the most time.

**The service must be built as a Windows service host, not a console web app.** Registered with
`sc.exe` and started, a plain `WebApplication` listens but never signals the SCM, so it dies with
**error 1053** after 30s and the logs show nothing wrong. It needs
`builder.Host.UseWindowsService(...)` plus `Microsoft.Extensions.Hosting.WindowsServices`, mirroring
`Systems/InstructionAssistant`.

### IIS reverse proxy — three traps, in the order you will hit them

1. **IIS cannot reverse-proxy out of the box.** URL Rewrite and Application Request Routing are
   **separate downloads**, not Windows features — `Install-WindowsFeature Web-Scripting-Tools` does
   not bring them and reports `NoChangeNeeded`. Install URL Rewrite **first**, then ARR. Then enable
   the proxy at server level (`system.webServer/proxy` → `enabled`). Miss that last step and every
   rewritten request returns a bare 404 that looks like a broken rule.
2. **`allowedServerVariables` can only be set at server scope.** Adding `HTTP_X_FORWARDED_PROTO` at
   site scope fails with *"This configuration section cannot be used at this path… locked at a parent
   level"*. Use `appcmd … /commit:apphost`. Until it is there, a `web.config` that sets that variable
   answers **500**, not 404 — the two error codes tell you which of these two traps you are in.
   ARR sends `X-Forwarded-For` by itself; `X-Forwarded-Proto` is the one you must add.
3. **`CustomerPortal:TrustedProxies` must be set once a proxy is in front.** The service only calls
   `UseForwardedHeaders` when the array is non-empty, so while it is `[]` every caller looks like
   `127.0.0.1` and the rate limiter counts all customers as one — one active customer locks out the
   rest. As a machine-scope variable: `CustomerPortal__TrustedProxies__0`.

### An IP:port SSL binding beats SNI, and that decides which certificate to buy

Measured, after an SNI binding that was correctly created was never once presented:

```
netsh http show sslcert
  IP:port        <private-ip>:443            -> cert A   (the site's existing certificate)
  Hostname:port  portal-api.<domain>:443     -> cert B   (added for the new host)

openssl s_client -servername portal-api.<domain>   ->  cert A
openssl s_client -servername <domain>              ->  cert A
```

http.sys resolves an exact **IP:port** binding before it ever consults a hostname (SNI) binding, so
while one exists on that address every name on it gets that one certificate. A per-host certificate
bound by SNI is money spent on something that will never be served.

**So: one certificate whose SAN covers every hostname on the address, bound to the IP:port.** Ours is
a DigiCert DV reissue — adding a subdomain of an already-validated domain needs no new validation and
usually costs nothing, which makes it same-day. Generate the CSR **on the server** (`certreq -new`)
so the private key never travels; a CSR is public and safe to e-mail. Come back with the signed
`.crt`, `certreq -accept` it, and check `HasPrivateKey` is `True` before going near the binding.

**The rebind is the only moment the existing site is down**, because `netsh http delete sslcert`
succeeds on its own:

```
netsh http delete sslcert ipport=<ip>:443
netsh http add    sslcert ipport=<ip>:443 certhash=<hash> appid='{<guid>}' certstorename=MY
```

Have the rollback (`add` with the *old* hash and its store) written out before you start, and do not
delete the old certificate from the store until the new one is verified from outside.

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
- **Priority stores text in VISUAL order.** Hebrew therefore reads correctly only after
  `dbo.fnUnreverseVisualText`, but every Latin/digit run inside it comes back reversed. The function
  peels **trailing `:;!?` only**, and only when the run does not also *start* with one of them — so
  `RE:` survives instead of becoming `:RE`. Deliberately excluded: `.` and `,` (decimal separators —
  a wider set turned the device description `'5000.` into `0005'.` in 24 rows) and brackets (mirrored
  pairs must travel with the reversal). **Before changing this function, measure how many existing
  rows its output changes** — it is used by display code all over the portal.

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
- **`hostname` before anything else, every time you believe you are on a server.** Two full rounds of
  IIS commands were run on the workstation instead of `MbaCustWeb` and failed with
  `Get-WebBinding is not recognized` — the correct answer for a machine with no IIS. What hid it: a
  local development instance of the portal API was listening on the **same port**, so
  `Invoke-WebRequest http://localhost:5312/health` returned the identical `{"status":"ok",…}` the
  production service returns and read as proof the server was healthy. Same family as the
  `\\tsclient\` trap already in the runbook.
- **Never leave a placeholder inside a block that contains a destructive command.** A block whose
  first line was `$new = '<THUMBPRINT>'` was pasted verbatim; the `netsh … delete sslcert` that
  followed succeeded and the `add` then failed with `The parameter is incorrect`, leaving the site
  with no certificate. Derive the value in the block instead — `$new = (Get-ChildItem Cert:… ).Thumbprint`
  — so there is nothing left to substitute by hand.
- **The IIS PowerShell provider caches configuration per process.** After `web.config` is written by
  anything other than the provider, `Add-WebConfiguration` fails with *"Cannot commit configuration
  changes because the file has changed on disk"*. Use `appcmd.exe`, or a fresh PowerShell session.
- **`appcmd` needs the stop-parsing token.** `& appcmd --% set config … /+"[name='X']"` — without
  `--%`, PowerShell parses `/+` and the brackets as operators and mangles the argument.
- **`appcmd`'s "duplicate collection entry" error means it is already there.** It reads as a failure
  and is a success from a previous run.

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
- **Nothing is ever deleted from Priority, or because of Priority.** "שיביא אותם במצב INACTIVE זה
  בסדר. אסור להמחק מהפריוריטי." When a record should stop appearing, carry a flag; do not remove a
  row on either side.
- **Never echo a password, and never write one into a document.** Connection secrets live in env
  files only — not in runbooks, not in tickets, not in terminal output, not in a commit message.
- **`app/` is front-end work that normally belongs to Dako** — a Jira US plus a `reference/*` branch,
  not a direct edit. The user does override this and ask for direct fixes; treat the override as
  covering that request, not as a standing licence. **Dako owns the customer portal only**: "Dako
  אחראית רק על פורטל הלקוחות. אם זה לא קשור לפורטל תעביר לאולקסנדר." Anything that is not portal work
  is routed to Oleksandr. Tickets are written in English for both of them, unlike this Hebrew-first
  repo.
- **A `reference/*` branch is a deliverable, not a sketch.** It must at minimum typecheck and lint
  cleanly, and the behaviour it claims should be exercised against a running app. A branch that was
  handed over without a typecheck is a defect handed to someone else.
- **Measure the blast radius of a shared function before deploying it.** The first
  `fnUnreverseVisualText` fix was correct for the case in the ticket and silently corrupted 24 device
  descriptions. Counting the rows whose output would change is what caught it — *before* the deploy,
  not after.
- **Do not raise an alarm from a naming convention.** Two "missing procedure" reports this session
  were wrong: `GetPortalCustomerIds` is an inline table-valued function, so it is not `type = 'P'`;
  and a `modify_date` gap between STAGE and PROD meant nothing because the two definitions were
  identical. Compare the definitions before reporting drift.
- **A slow single request is not an N+1.** A screen throwing hundreds of console errors looked like
  queueing; one call from outside took 10.5s and returned 500 while the same query ran in 0ms
  locally, which is the network shape, not the code shape. The N+1 was real and was still not the
  cause. Say which evidence supports which claim.
- **Deploy a procedure to STAGE *and* PROD, or say plainly that you did not.** Half of the SQL from a
  session ending up on STAGE only is the single most common way this repo ends up with
  "works here, missing there" bugs. `Compare-Schema.ps1` will show it; `docs/decisions.md` lists what
  is currently one-sided.
- **Change one variable at a time before attributing a hardware fault.** A bit-level corruption was
  measured on two GPIB instruments and blamed on the shared adapter, with a table of numbers behind
  it. The numbers were right; the attribution was wrong, because a broken driver had changed at the
  same time. Only reading the suspect instrument back on a *proven* adapter settled it, and by then
  the user had been told to replace a working adapter. When two things changed, say so and isolate,
  rather than presenting the stronger-sounding conclusion.
- **Settings should follow the instrument, not the other way round.** "אני רוצה שההגדרות יהיו
  נקיות ולא תלויות במכשיר." Config is not the place to name ports, baud rates and addresses per
  device; discover what is attached and key everything off the identification reply.
- **A default that is wrong for a whole class is a bug, not a detail.** Every instrument broadcast
  `Celsius` because that was the historic default — "בגדול מכשיר שמודד אלקטרוניקה ערך ברירת
  המחדל צריך להיות וולט." Fixing it required reading what the existing enum members actually meant
  rather than what they were named — see decision 34.
- **Explain the mechanism, not just the conclusion.** "לא הבנתי מה אתה רוצה שאני אעשה" and
  "איך זה קשור ל-USB?" both followed answers that were technically complete and practically useless.
  When asking for a physical action, name the instrument, the panel, and the button.

- **Finish the walk before reporting.** "אתה צריך לבדוק את כל הטאבים והפופאפים" — a screen that loads
  is not a screen that works; open every tab and every dialog on it.
- **Run the control before blaming your own change.** A dependency bump appeared to break
  `next build` at "Finalizing page optimization". Running the identical build on unmodified `main`
  with the original lockfile, in a clean worktree, failed at exactly the same line — it was a missing
  local `.env`. Without that control the change would have been reverted for no reason.
- **A ticket's status is a claim, not evidence.** Several tickets in this repo's project sat in
  `To Do` while the work was merged, and one sat in `In Testing` with nothing implemented. Read the
  branch before moving anything: `git grep` for the symbol the ticket names, and check the merge
  commit. Two tickets closed this way had been finished for over a week.
- **Verify the security question you were actually asked.** Scanning ports from inside the office
  cannot distinguish "restricted to the office" from "open to the internet" — both answer. Only the
  Security Group's inbound rules, or a scan from a foreign network, settles it. Say which of the two
  you did.
- **Say plainly when a URL or fact came from memory and turned out wrong.** A Microsoft download link
  given from memory 404'd; the verification step that caught it was in the instructions on purpose.
  Check a link before handing it over.

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

## VCT runtime: discovery, the device tick, and identification

These four are the difference between "the instrument answers `*IDN?` but never appears" being a
five-minute question and a five-hour one. All were found against hardware.

**Transports are discovered, not configured.** `Settings/VCT.json` holds **one** tunnel — the TCP
listener, which has nothing to discover because it waits for a device to dial in. Everything else is
found at startup by `ComLayer.TransportDiscovery` and turned into a tunnel by
`ServerCore.DiscoverTransportTunnels`. USB and GPIB are enumerated through VISA (`viFindRsrc`), so a
handle is only ever opened where something answers; serial baud cannot be enumerated, so each
candidate port is probed with `*IDN?` across `SerialBaudCandidates` and the first speed that answers
wins. That last part is what removed the final per-device setting — the PRODIGIT wants 115200 and
the Fluke 9600 on the same adapter.

- **A configured tunnel is left alone** and its port is never probed, so an instrument that does not
  answer `*IDN?` can still be pinned by hand. `AutoDiscoverTransports` (default true) disables the
  whole mechanism.
- **Never probe a Bluetooth COM port.** Opening one can block for many seconds; two on the bench
  stretched startup from ~1.6s to **46s**. `ServerCore.ListProbeableSerialPorts` asks WMI which
  ports are Bluetooth and excludes them — which is why the OS query lives in `ServerCore` and
  `DiscoverSerial` takes the candidate list as a parameter rather than building it.
- **A wrong baud rate still returns bytes**, just meaningless ones. `LooksLikeIdentification`
  therefore requires mostly-printable ASCII with at least one letter; accepting noise would pin an
  instrument to the wrong speed permanently.

**The device tick is re-entrancy-guarded, and it has to be.** `System.Timers.Timer` fires every 2s
whether or not the previous callback finished, and `_TempDeviceHost` is a *shared field* that each
tick clears at the start and reads at the end. Overlapping ticks meant one tick queued a device for
promotion while another cleared the list before it got there — the device was re-queued forever and
never promoted, with no exception and no log. Guarded with `Interlocked` (`_deviceTickRunning`);
the body lives in `DeviceTick()`. Three failure paths that used to be silent now log, including
**an identified device that no BL core claimed** — which is what you see when a `DeviceIdToken` does
not match the SN, or the module is missing from `Settings/ComServerSettings.json`.

**Identification matches the model before the manufacturer.** The HP 53181A and the Agilent 34401A
both answer `HEWLETT-PACKARD`, and the old code compared `Substring(0, 15)` — identical for both, so
the 34401A's `"HEWLETT"` token would claim the counter and drive it with `CONF:VOLT:DC`. Match the
model (`53181A`) first. Any new instrument from a manufacturer already present needs the same
treatment.

**`WebSocketProtocolParaser` does not strip the closing brace.** It splits JSON by hand, so the
**last** field of a message parses with a trailing `}` — `{"CMD":"Status","Value":"Start"}` yields
`Value = "Start}"` and the server ignores it. When sending WS commands by hand, put a throwaway
field last (`,"DeviceID":"0"`). Note the misspelled class name; it is spelled that way in the code.

### The Meatest M-142 cannot do GPIB — and only the M-142

A bit-level corruption on the GPIB bus was attributed first to one instrument, then to the adapter,
and both were wrong. Three instruments on one adapter, one cable, one driver settled it: the
Pendulum CNT-90 (address 7) and Fluke 5322A (address 2) return **0%** corrupt bytes; the M-142
(address 10) returns **86-100%**. It fails on the first high-to-low transition of DIO7 and recovers
on the next byte, which rules out both firmware and software.

It is **not a setting** — the M-142 exposes only interface, address and serial baud/handshake, and
GPIB is eight parallel lines with no format or parity, so no menu item can set a bit on every byte.
**Use its RS-232 port**, which never touches DIO7: Interface = `RS232`, baud 9600, handshake off,
and a **straight 1:1 cable** (2-2, 3-3, 5-5 — it is wired as DCE). Note that this is the *opposite*
of the Fluke 5522A, which needs a null-modem cable for the same rescue.

Corrupted numbers are rejected rather than believed: the corruption turns digits into letters, so
`TryParseValue` fails and the reading is discarded instead of broadcast as a plausible wrong
measurement. That is why those parsers return false rather than 0.

**Do not re-attempt the one-byte-at-a-time read.** It fixes the corruption through VISA and cannot
work through `GpibCom`: NI's device-level `ibrd` re-addresses the instrument on every call, so the
rest of the message is discarded. It was implemented, tested against hardware, and removed.

### The wizard's "already assigned" error is a business rule

`dbo.AssignMeasurmentDeviceToOrderDetailsItems` throws `51000, 'Sensor with specified channel(s)
already assigned to other device.'` when the same logger + sensor pair is used on two devices of one
order line. Despite the message the guard **ignores channels**, so a 5-channel sensor cannot serve
two devices on one line even on different channels. The router maps it to a tRPC `CONFLICT` and the
screen shows a Hebrew message; before that it surfaced as a bare 500. Changing the rule is the
procedure owner's call, not a bug to fix in passing.

**Reproduce a write-path error without writing:** pyodbc with `autocommit=False`, execute the
procedure, read the exception, `rollback()`. Only a faithful payload reproduces — a guessed one
"succeeds" and proves nothing. This is what produced the real text behind two "Internal server
error"s in one afternoon.
