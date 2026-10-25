---
name: run-customer-analysis
description: Build, run, and drive the QCC customer-analysis dashboard (React/Vite + Express, PostgreSQL). Use when asked to start customer-analysis, launch the QCC dashboard, restore/backfill its database, sync it from Priority ERP, or screenshot/smoke-test it.
---

Node/Express + Vite web app (Hebrew RTL dashboard) backed by PostgreSQL,
fed by Python scripts that pull from Priority ERP (SQL Server). Drive it
via `.claude/skills/run-customer-analysis/driver.mjs` — it handles the
Windows-specific server lifecycle and a headless-Chrome screenshot.
This machine is native Windows (no WSL/Docker/xvfb) — every command
below was run directly in PowerShell/Git-Bash on Windows, not a Linux
container.

All paths below are relative to `customer-analysis/` (this directory).

## Prerequisites

Verified present/working on this machine:

- **Node.js** (v24.19 tested — newer than the v20 LTS the docs call for,
  works fine)
- **PostgreSQL 16**, running as a Windows service, with a `qcc_analytics`
  database
- **Python 3.13** + `pip install pyodbc requests python-dateutil python-dotenv`
- **ODBC Driver 18 for SQL Server** (the sync script also accepts 17/13 —
  see `PROBE_DRIVERS` in `local-scripts/sync-customer-data.py`)
- **Git Bash** on PATH (`bash` resolves) — the driver shells out to it
- **Chrome or Edge** for the screenshot step (auto-detected from the
  standard `Program Files` locations)

If PostgreSQL isn't installed yet: **`winget install PostgreSQL.PostgreSQL.16`
fails on this network** — every version's installer resolves to
`get.enterprisedb.com`, whose CloudFront CDN returns `403 Forbidden` here
(confirmed: other hosts like `github.com`/`postgresql.org` work fine, so
it's specific to that CDN, not a general outage). Get the installer some
other way (a different network, or ask the user to provide it) and run it
manually; `psql`/`pg_restore`/etc. end up in
`C:\Program Files\PostgreSQL\16\bin\`.

## Setup

```bash
npm install
```

`local-scripts/config.example.py` has a bug: it defines `SERVER_API_URL`
but `sync-customer-data.py` imports `REPLIT_API_URL` — copying the example
literally breaks the import silently (falls through to a worse env-var
fallback). Already fixed in `config.example.py` in this repo; if you're
recreating `local-scripts/config.py` from scratch, use `REPLIT_API_URL`,
not `SERVER_API_URL`.

### Environment

`.env` (gitignored) must define at minimum:

| Variable | Notes |
|---|---|
| `DATABASE_URL` | `postgres://<user>:<pass>@localhost:5432/qcc_analytics` — URL-encode special characters in the password (`@` → `%40`, etc.) |
| `NODE_ENV` | `development` |
| `PORT` | `5000` |
| `PRODUCTION_URL` | Set this to `http://localhost:5000` (i.e. itself) — otherwise the server's auto-migration job (`server/routes.ts`, `autoMigrateEnabled` defaults `true`) pushes every synced customer to the old dead Replit prod URL on a timer. There's no env var to disable the job itself, only to redirect its target. |

For the Python sync scripts, `local-scripts/config.py` (gitignored, not
`.env` — the scripts don't read `.env` at all) needs `SQL_CONFIG`
(amaba/Priority) and `REPLIT_API_URL = 'http://localhost:5000/api/sync/customer-data'`;
see `config.example.py` for the shape. Get real Priority credentials from
the user — don't invent or reuse stale ones from docs.

### Database

If `qcc_analytics` is empty, get it from a `pg_dump -Fc` of the real one
(ask the user) — don't try to build 8000+ customers by hand. Restore:

```bash
"/c/Program Files/PostgreSQL/16/bin/pg_restore.exe" -U postgres -h localhost -p 5432 \
  -d qcc_analytics --no-owner --no-privileges -v "<path-to-dump>"
```

**If `pg_restore` dies with `out of memory` partway through a table**,
don't assume the machine is low on RAM — one customer row in a dump we
hit was individually huge (500KB+ and climbing) and crashed `pg_restore`
outright. Diagnose which row with `pg_restore --data-only -t <table> -f
out.sql <dump>` and look at how far it got / how big the last line is
before it died. **PG16's `pg_restore` has no `--exclude-table-data`**
(that flag is PG17+) — to skip just the bad table (and everything after
it in the archive, since a corrupt block desyncs sequential reads for
everything downstream: `pg_restore -l <dump> > toc.list`, comment out
(prefix with `;`) the bad table's `TABLE DATA` line **and every line
after it** (constraints/indexes live at the very end of the archive,
after all data — they become unreachable too), then
`pg_restore -L toc.list -d qcc_analytics <dump>`. Recreate the missing
primary keys/indexes by hand from `shared/schema.ts` afterward (every
table there has `.primaryKey()` on an obvious column) — **don't** run
`drizzle-kit push` to do this if the DB has tables outside the tracked
schema (e.g. manual `*_bk_YYYYMMDD` backup tables): it'll offer to
`DROP` them as "data-loss statements" and hang waiting for a TTY
confirmation that doesn't exist in a non-interactive shell.

Load the skipped table's good rows back in with a hand-trimmed
`pg_restore --data-only -t <table> -f partial.sql <dump>` (drop the
truncated last row, append `\.`, then `psql -f partial.sql`), then
re-sync the one bad customer fresh from Priority once the app is up
(see below) rather than fighting the dump further.

## Run (agent path)

```bash
node .claude/skills/run-customer-analysis/driver.mjs start   # launches, returns immediately
node .claude/skills/run-customer-analysis/driver.mjs wait    # blocks until http://localhost:5000 responds
node .claude/skills/run-customer-analysis/driver.mjs smoke   # hits the API + screenshots the dashboard
node .claude/skills/run-customer-analysis/driver.mjs stop    # kills whatever owns :5000
```

`smoke` fetches `/api/customers/list` (checks the count is non-zero),
fetches one customer record, and screenshots the loaded dashboard to
`.claude/skills/run-customer-analysis/screenshots/dashboard.png`. Server
log is `.claude/skills/run-customer-analysis/server.log`. Both are
gitignored — regenerated every run.

| command | what it does |
|---|---|
| `start` | Launches `tsx server/index.ts` via `bash -c '... & disown'`, detached, logs to `server.log` |
| `wait` | Polls `http://localhost:$PORT/` (default 30s timeout) |
| `smoke` | `wait`, then `GET /api/customers/list` + one customer + a screenshot |
| `stop` | Finds the PID listening on `$PORT` (`netstat`) and `taskkill /F`s it |

Override the port with `PORT=5001 node driver.mjs start` (and matching
`wait`/`smoke`/`stop` calls).

## Run (human path)

```powershell
$env:NODE_ENV="development"; $env:PORT="5000"; npx tsx server/index.ts
```
Ctrl-C to stop. Opening `http://localhost:5000` in a browser is the
manual equivalent of `smoke`.

## Test

```bash
npx tsc --noEmit
```
Passes clean (no errors) as of this writing. `npm run check` runs the
same thing but its `package.json` definition doesn't matter for `dev`
purposes — only `dev`/`start` have the Windows env-var problem below.

## Backfilling data from Priority

```bash
PYTHONIOENCODING=utf-8 python local-scripts/sync-customer-data.py -c <CUSTNAME>
PYTHONIOENCODING=utf-8 python local-scripts/sync-customer-data.py --ship   # UPS/Ship expenses
```

`-c` accepts either Priority's internal `CUST` id or the customer-facing
`CUSTNAME` (tries `CUSTNAME` first, falls back to `CUST`) — either works.
Full-catalog sync (`sync-customer-data.py` with no args) syncs every
customer; only run that when you actually mean to refresh everyone, it's
not fast.

## Gotchas

- **`PYTHONIOENCODING=utf-8` is required** to run any of the
  `local-scripts/*.py` scripts on Windows — without it, the first Hebrew
  character any script tries to `print()` throws
  `UnicodeEncodeError: 'charmap' codec can't encode character ...`
  (Windows console defaults to cp1252). The scripts otherwise ran fine;
  it's purely a console-output crash, not a logic bug.
- **`package.json`'s own `dev`/`start` scripts don't run on Windows** —
  they use POSIX `NODE_ENV=development tsx ...` syntax, which cmd.exe/
  PowerShell can't parse. Use the driver (sets env via `child_process`/
  bash, not shell syntax) or the PowerShell one-liner above.
- **`spawn(..., { detached: true })` throws `spawn EINVAL` on Windows**
  when the target is a `.cmd` shim (`npx.cmd`) — a real Node-on-Windows
  interaction, not a config mistake. Shelling out to `bash -c '... &
  disown'` (what the driver does) reliably detaches instead.
- **Chrome headless screenshots can hang indefinitely** two different
  ways: (1) `--headless=new` (the current default) silently ignores
  `--virtual-time-budget` — use `--headless=old`. (2) Even with
  `--headless=old`, a leftover/other Chrome process holding the default
  profile's lock file will make a new headless instance hang for minutes
  contending for it — always pass a dedicated `--user-data-dir` (the
  driver uses `screenshots/chrome-profile/`) plus
  `--disable-background-networking --disable-sync --disable-default-apps
  --no-first-run` to also skip first-run network calls (GCM
  registration, etc.) that can otherwise block process exit.
- **`winget install PostgreSQL.*`** (any version, 9 through 18) fails on
  this network — all resolve to a CloudFront-fronted EnterpriseDB URL
  that 403s here specifically (unrelated hosts work fine). Not a code
  problem; get the installer another way.
- **`drizzle-kit push` is not safe to run blind on a DB restored from a
  production dump** — this project's DB has manually-created backup
  tables (`*_bk_20260823` etc.) that aren't in `shared/schema.ts`.
  `push` detects them as extraneous and offers to `DROP` them
  ("data-loss statements"), then hangs forever on a TTY confirmation
  prompt in a non-interactive shell. Add missing constraints/indexes by
  hand instead (see Database section above).
- **The Ship/UPS API token in `.env` (`SHIP_AUTH_TOKEN`) expires** and
  there's no working automated refresh in this repo copy
  (`local-scripts/refresh-ship-auth.bat`, referenced in comments,
  doesn't exist here) — refreshing it requires a human to log into
  `newbetaapp.ship.co.il` and copy `auth_token` out of DevTools
  localStorage. `--ship` sync will fail with HTTP 401 on every endpoint
  it tries until that happens; that's expected, not a bug to chase.
- **QCCData SQL Server access is optional** — `sync-customer-data.py`
  logs `[WARN] אין גישה ל-QCCData` and continues without lab calibration
  dates if `QCCDATA_SQL_USER`/`PASSWORD` aren't set. Non-fatal.

## Troubleshooting

- **`Test-NetConnection -Port 5432` returns `False` / API calls hang for
  ~10s then return nothing**: Postgres isn't running or `DATABASE_URL`
  points at the wrong place. The Node server itself boots fine either
  way (the `pg` pool is lazy) — only `/api/*` routes that touch the DB
  hang/fail.
- **`psql`/`pg_restore`: `password authentication failed for user
  "postgres"`**: wrong password in the command vs. what the Postgres
  installer was actually given — ask the user, don't guess.
- **`ModuleNotFoundError: No module named 'pyodbc'`**: `pip install
  pyodbc requests python-dateutil python-dotenv` (see Prerequisites).
