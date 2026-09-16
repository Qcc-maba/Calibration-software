# customer-analysis — the QCC Analytics dashboard

Claude Code loads this file when working under `customer-analysis/`. The root `CLAUDE.md` holds what
every task needs; this file holds what this app needs. Procedures live in this app's own skills,
under `customer-analysis/.claude/skills/`: **`run-customer-analysis`** (run it locally, restore or
sync its database, screenshot it) and **`deploying-customer-analysis`** (publish to maba-dc2 and
verify that the deploy took).

## Commands

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

There is **no test runner in this project**. To drive the UI, import Playwright by file URL from a
scratch `.mjs`. On the machine this was first written on, Playwright 1.58 came from a sibling
`maba2000-web/frontend/node_modules/playwright` checkout, with its browsers in the shared
`~/AppData/Local/ms-playwright` cache — that checkout does not exist on every machine, so check before
relying on it. Use `locale: 'en-US'` in the browser context: that is what reproduces locale-dependent
bugs here.

## Architecture

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

## Scratch scripts

- Node scratch scripts that `import sql from 'mssql'` must live **inside `customer-analysis/`** —
  module resolution is by script location, so a script in a temp directory cannot find the package.
  Clean them up afterwards; they are easy to leave behind.
