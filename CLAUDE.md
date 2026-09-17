# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Documentation and UI strings are Hebrew-first (RTL) — preserve Hebrew text verbatim when editing.
`README.md` and `docs/architecture.md` are both in Hebrew and are the primary references for the
VCT server; **read `docs/architecture.md` before changing anything under `Systems/`**.

**This file holds only what every task needs.** Knowledge about one area lives beside that area's
code, in a nested `CLAUDE.md` that Claude Code loads when it works in that directory — see "Where the
detail lives" below. Procedures that repeat are skills under `.claude/skills/` (index:
`.claude/skills/README.md`). The per-session files `docs/session<n>-decisions.md` are why each call
was made, including what was tried and rejected; decision numbers run continuously across those
files, so a reference to one means a single thing.

When you learn something durable, put it where it will be read: in the nested `CLAUDE.md` of the area
it belongs to, or in the skill whose procedure it changes. Add to this root file only what applies
across areas — every line here is loaded into every session.

## How work is done here

Every change goes through a Jira ticket, a feature branch and a pull request. Jira project **MBA**.

1. **Ticket first.** A `Bug` for a fix, a `Story` for new functionality. The description says what is
   wrong, where, and the proposed change.
2. **Branch off a freshly pulled `develop`**, named `MBA-<num>-<kebab-case-slug>` — for example
   `MBA-963-customer-picker-duplicate-names`.
3. **Commit on that branch**, every subject starting `MBA-<num>: `. Group by intent and say **why**,
   with the measured numbers; the `committing-work` skill has the rest.
4. **Open a PR into `develop`**, titled `MBA-<num>: <summary>` and linking the ticket. Push and open
   the PR only when asked.

**Never commit directly to `develop`, `master` or `main`.**

**Check a PR's state before adding to its branch.** A commit pushed to a branch whose PR has already
merged lands nowhere — it does not reopen or extend the PR, and the PR page keeps showing only what
it merged. Put the commit on a new branch off `develop` and open a new PR. For the same reason, before
deleting a merged branch confirm `git diff origin/develop <branch>` is empty.

The branches you will find:

| Branch | What it is |
|---|---|
| `develop` | The integration branch. Every PR targets it. |
| `master` | GitHub's default branch, but it **lags** — an ancestor of `develop`, not moved by the PR flow. Do not branch from it. |
| `Eliran` | The working branch of a developer who has since left. Not a trunk: do not branch from it or commit to it. It held commits never merged into `develop` when it was retired — measure with `git log origin/develop..origin/Eliran` before merging or deleting it. |

One-off personal helper scripts are kept outside the repository, not left untracked inside it.

## What lives here

This repo holds several independently deployed systems that share a domain (MABA calibration), not
one application:

| Area | Stack | Notes |
|------|-------|-------|
| `Systems/VCT/`, `Systems/Hydra-Group/` | C# **.NET 4.8** | The VCT hardware server. `UnifiedSystemV1.sln`. |
| `Systems/CustomerPortalApi/`, `InstructionAssistant/`, `OrderAttachments/`, `Priority/`, `ReportArchiveSync/` | C# **net10.0** | Separate services, own csproj each. Several run as Windows Services **on the same box** — see the `installing-a-windows-service` skill. |
| `customer-analysis/` | Node + React + Postgres | QCC Analytics dashboard. Undocumented in README — see `customer-analysis/CLAUDE.md`. |
| `app` (separate repo) | Next.js | The web app **and** the customer portal. **Its own git repo** (`Qcc-maba/app`), normally cloned beside this one as `GIT_ROOT\app`; `/app/` is gitignored in case it is cloned inside. Not a submodule — do not merge it into this one, and do not run it from inside OneDrive. |
| `database/procedures/` | T-SQL | One file per SQL Server object, named `<schema>.<Object>.sql`. |
| `archive/` | — | Dead code. Not built. |

`packages/`, `bin/`, `obj/` are not in git; run `nuget restore` before a first C# build.

## Where the detail lives

A nested `CLAUDE.md` is loaded when you work in its directory; a skill is loaded when its task comes
up. Read the one for the area before changing it.

| Working on | Read |
|---|---|
| The QCC Analytics dashboard — `customer-analysis/` | `customer-analysis/CLAUDE.md`; skills `run-customer-analysis` and `deploying-customer-analysis` in `customer-analysis/.claude/skills/` |
| The VCT server core: sessions, discovery, identification, WebSocket, alerts — `Systems/VCT/` | `Systems/VCT/CLAUDE.md` |
| Instruments and loggers — `Systems/Hydra-Group/` | `Systems/Hydra-Group/CLAUDE.md`; skills `bringing-up-an-instrument`, `diagnosing-a-station` |
| The order-attachments service — `Systems/OrderAttachments/` | `Systems/OrderAttachments/CLAUDE.md` |
| The portal's sign-in API — `Systems/CustomerPortalApi/` | `Systems/CustomerPortalApi/CLAUDE.md`; skill `exposing-a-service-publicly` |
| Installing any net10 service on a MABA server | skill `installing-a-windows-service` |
| The calibration station installer — `Installer/` | `Installer/CLAUDE.md`; skills `shipping-a-station-installer`, `diagnosing-a-station` |
| SQL objects and data fixes — `database/` | `database/CLAUDE.md`; skill `changing-a-database` |
| The web app and customer portal — the separate `app` repo | skills `working-on-the-app-repo`, `verifying-ui-work`, `portal-data-path` |
| Committing, pushing, and what must never be committed | skill `committing-work` |
| A long-diverged branch | skill `merging-stale-branches` |

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

### customer-analysis
```powershell
npm run build      # tsx script/build.ts -> dist/index.cjs + dist/public
npm run check      # tsc
npm start          # production bundle
python scripts/gen-priority-queries.py   # after editing either sync-*.py query
```
**`npm run dev` does not work on Windows** — `customer-analysis/CLAUDE.md` says how to run the server
instead. The web app's commands are in the `working-on-the-app-repo` skill.

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

## Priority

### Priority is the source of truth, and nothing is ever deleted from it

A contact that disappears from Priority is marked **inactive**, never removed.
`CustomerContacts.IsActive` carries `PHONEBOOK.INACTIVE` through
`stg.LoadCustomerContactsFromPriority` → `stg.MergeCustomersContactsData`, and the portal procedures
filter on it. Deleting rows to make a screen behave is not an option, in either direction.

**Nothing is ever deleted from Priority, or because of Priority.** "שיביא אותם במצב INACTIVE זה
בסדר. אסור להמחק מהפריוריטי." When a record should stop appearing, carry a flag; do not remove a
row on either side.

### Priority data traps

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

## STAGE and PROD

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
- **Deploy a procedure to STAGE *and* PROD, or say plainly that you did not.** Half of the SQL from a
  session ending up on STAGE only is the single most common way this repo ends up with
  "works here, missing there" bugs. `Compare-Schema.ps1` will show it; `docs/session1-decisions.md` lists what
  is currently one-sided.

## Secrets

- **Never echo a password, and never write one into a document.** Connection secrets live in env
  files only — not in runbooks, not in tickets, not in terminal output, not in a commit message.
- Several `.config` files in this repo carry plaintext database passwords. Don't add more, don't echo
  them into terminal output, and don't paste them into commit messages or docs.

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
- **A file can come back as a stale, shorter copy of itself.** OneDrive sync did this when a checkout
  lived there, and a parallel session editing the same tree does the same. **After rewriting a whole
  file, read `git diff --cached --numstat` before trusting the result**: an edit that only adds must
  show zero deletions, and `wc -l` will happily confirm the wrong number. The `committing-work` skill
  has the incident and its numbers.
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
- **Git Bash mangles Hebrew in `curl --data-urlencode`.** A Hebrew search that returns nothing from
  the shell may work perfectly — re-test with `fetch` and `encodeURIComponent` from a Node script
  before believing the server is at fault.
- A heredoc in the Bash tool eats backslash escapes; write files containing `'\'` with the Write
  tool instead.

## Working style — corrections from past sessions

Each of these was a correction made in a real session on this repository, and each applies to any
task.

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
- **Change one variable at a time before attributing a hardware fault.** A bit-level corruption was
  measured on two GPIB instruments and blamed on the shared adapter, with a table of numbers behind
  it. The numbers were right; the attribution was wrong, because a broken driver had changed at the
  same time. Only reading the suspect instrument back on a *proven* adapter settled it, and by then
  the user had been told to replace a working adapter. When two things changed, say so and isolate,
  rather than presenting the stronger-sounding conclusion.
- **Explain the mechanism, not just the conclusion.** "לא הבנתי מה אתה רוצה שאני אעשה" and
  "איך זה קשור ל-USB?" both followed answers that were technically complete and practically useless.
  When asking for a physical action, name the instrument, the panel, and the button.
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
