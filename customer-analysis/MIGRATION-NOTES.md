# Migration Notes — running QCC Customer-Analytics outside Replit (Windows)

Static-analysis notes for lifting this app off Replit and running it locally in this
repo. Nothing here was executed (`npm install` / `npm run build` were intentionally
**not** run). Everything below is derived from the source.

The app is a monorepo: **Vite/React client** (`client/`) + **Express/TS server**
(`server/`) + shared Zod/Drizzle schema (`shared/`), plus **local Python sync scripts**
(`local-scripts/`) that push data into the server over HTTP. Data lives in **PostgreSQL**
(Drizzle ORM). The Python scripts read the source-of-truth **MS SQL Server** (Priority
ERP `amaba` + `QCCData`) via `pyodbc` — the Node server does **not** read SQL Server
(see "Dead code" below).

---

## 1. Ordered checklist to build & run locally

1. **Install runtimes**
   - **Node 20 LTS** (matches `.replit` `nodejs-20`). Avoid Node 23+ on Windows because of
     `reusePort` — see Issue I-4.
   - **PostgreSQL 16** running locally (or in Docker).
   - **Python 3.11** + the **Microsoft ODBC Driver 17/18 for SQL Server** (only needed on
     the machine that runs the sync scripts, which must have LAN access to
     `maba-priority\pri`).

2. **Provision PostgreSQL** and get a connection string, e.g.
   `postgresql://postgres:postgres@localhost:5432/qcc`.
   Quick Docker option (this folder has **no** compose file of its own — the
   `docker-compose.yml` in the sibling `maba2000-web/` is a *different* project):
   ```powershell
   docker run -d --name qcc-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=qcc -p 5432:5432 postgres:16
   ```

3. **Set environment variables** for the server (see the env table in §2). At minimum
   `DATABASE_URL`. There is currently **no dotenv loader in the server** (`server/index.ts`
   does not import `dotenv`), so either:
   - export them in the shell before `npm run dev`, **or**
   - add `import 'dotenv/config';` as the first line of `server/index.ts` and create a
     `.env` (recommended — `.env` is already gitignored). `dotenv` is **not** currently a
     dependency, so this needs `npm install dotenv`.

4. **Fix the npm `dev`/`start` scripts for Windows** (Issue I-1). The scripts use the
   POSIX form `NODE_ENV=development tsx …`, which fails in cmd/PowerShell.
   - Preferred: `npm install -D cross-env` and change scripts to
     `cross-env NODE_ENV=development tsx server/index.ts` /
     `cross-env NODE_ENV=production node dist/index.cjs`.
   - No-install workaround (PowerShell), no package.json change needed:
     ```powershell
     $env:NODE_ENV="development"; npx tsx server/index.ts
     ```

5. **Install JS deps**: `npm install` (installs the `@replit/*` vite plugins too — that is
   fine, see I-2).

6. **Create the DB schema**: `npm run db:push` (drizzle-kit push; requires `DATABASE_URL`).
   This project ships **no SQL migrations** — the schema is pushed from `shared/schema.ts`.
   The server also runs one idempotent `ALTER TABLE … ADD COLUMN IF NOT EXISTS sync_id`
   at startup (wrapped in try/catch), so ordering is not fragile.

7. **Disable / retarget the auto-migration to old Replit prod** (Issue I-3, important).
   After every sync the server schedules a push of all data to
   `https://client-analytics-dashboard--eliran8hadad.replit.app`. Set
   `PRODUCTION_URL` to a harmless value or (better) set `migrationStatus.autoMigrateEnabled`
   default to `false` in `server/routes.ts`. Running the server with
   `NODE_ENV=production` also skips it, but that changes other behavior (static serving).

8. **Run the server (dev)**: `npm run dev` (after the I-1 fix) → serves API **and** client
   through Vite middleware on `http://localhost:5000` (or `PORT`). The client uses only
   **relative** `/api/...` URLs (verified across `client/src/pages/*`), so no client-side
   host needs configuring.

9. **Production build (optional)**: `npm run build` (→ `tsx script/build.ts`: Vite builds
   the client to `dist/public`, esbuild bundles the server to `dist/index.cjs`). Then
   `npm run start` serves the pre-built client statically from `dist/public`. Both build
   and start need the Windows env-var fix (I-1); `start` needs `NODE_ENV=production`.

10. **Set up the Python sync** (feeds the server; see §3):
    ```powershell
    copy local-scripts\config.example.py local-scripts\config.py
    # edit config.py: set SQL_CONFIG + REPLIT_API_URL = http://localhost:5000/api/sync/customer-data
    pip install pyodbc requests python-dateutil python-dotenv
    python local-scripts\sync-customer-data.py --url http://localhost:5000
    ```

11. **Type-check** anytime with `npm run check` (`tsc`, noEmit).

---

## 2. Environment variables

| Var | Used by | Required? | Notes |
|-----|---------|-----------|-------|
| `DATABASE_URL` | server (`server/db.ts`), `drizzle.config.ts` | **Yes** | PostgreSQL conn string. `db.ts` and `drizzle.config.ts` throw if missing. |
| `PORT` | server (`server/index.ts`) | No | Defaults to `5000`. `.replit` set `PORT=5000`. |
| `NODE_ENV` | server + `vite.config.ts` | Effectively yes | `development` → Vite middleware; `production` → static serve from `dist/public` + skips auto-migration. Must be set in a Windows-safe way (I-1). |
| `PRODUCTION_URL` | server (`routes.ts:131`) | No but **set it** | Target of the auto-migration. Defaults to the old Replit prod URL. See I-3. |
| `SYNC_SECRET` | server (`routes.ts` `checkSyncSecret`) | No | If unset, the global-sync endpoints are open (fine for local). Must match `config.py`'s `SYNC_SECRET` if set. |
| `SHIP_API_EMAIL` | server `/api/ship/sync-live` **and** Python `--ship` | For UPS/Ship features | UPS Israel (ship.co.il) login. |
| `SHIP_API_PASSWORD` | server `/api/ship/sync-live` **and** Python `--ship` | For UPS/Ship features | — |
| `SHIP_CUSTOMER_ID` | server + Python | No | Defaults to `699226`. `.replit` set this under `[userenv.shared]`. |
| `SQL_SERVER_ADDR` | **only** `server/db/mssql.ts` (dead code) + not read by active server routes | No | Format `IP\INSTANCE,PORT`. Not needed unless `customer-service.ts` is wired in. |
| `SQL_UID` / `SQL_PWD` / `SQL_DATABASE` | same as above (dead code); Python reads its own `SQL_CONFIG` from `config.py` | No (server) | The **Python** scripts use `config.py`'s `SQL_CONFIG`, not these env vars (env only as fallback if `config.py` is absent). |
| `REPLIT_INTERNAL_APP_DOMAIN` / `REPLIT_DEV_DOMAIN` | `vite-plugin-meta-images.ts` | No | Absent locally → plugin no-ops. Harmless. |
| `REPL_ID` | `vite.config.ts` | No | Absent locally → Replit cartographer/dev-banner plugins are skipped. Harmless. |

Python-side config (in `local-scripts/config.py`, copied from `config.example.py`):
`SQL_CONFIG` (Priority `amaba`), `QCCDATA_CONFIG` (`QCCData`), `REPLIT_API_URL`
(**point at `http://localhost:5000/api/sync/customer-data`**), `SHIP_API_CONFIG`, optional
`SYNC_SECRET`.

---

## 3. How the Python sync feeds the server (data flow)

There is **no direct DB link** between the Node server and MS SQL Server in the running
code. Instead:

1. `local-scripts/sync-customer-data.py` (and `sync-ups-expenses.py`,
   `sync-operational-query.py`, `sync-financial-query.py`) connect to SQL Server with
   `pyodbc` using `config.py`.
2. They compute per-customer aggregates + scores and **HTTP POST** them to the server's
   sync endpoints (`/api/sync/customer-data`, `/api/sync/department-stats`,
   `/api/sync/calibrators`, `/api/sync/company-return-documents`,
   `/api/sync/company-calibration-alerts`, `/api/sync/monthly-call-stats`, …).
3. The server **upserts** each record into PostgreSQL (`synced_customers` etc.) and then
   rebuilds an **in-memory cache** (`buildCustomerListCache()` in `routes.ts`): the
   `/api/customers/list` payload is pre-serialized to a JSON string and pre-gzipped so
   reads are served in <5 ms. The cache is rebuilt in the background after each sync and
   on startup; it is **not** persistent — a server restart rebuilds it from PostgreSQL.
4. The client reads only the PostgreSQL-backed API. So the local run needs: PostgreSQL up,
   server running, and at least one successful Python sync to populate data.

The target URL is set either by `REPLIT_API_URL` in `config.py` or overridden per-run with
`--url http://localhost:5000`. The `run-sync-*.bat` helpers in `local-scripts/` and
`qcc-sync-scripts/` still hardcode the old Replit dev/prod URLs — pass `--url` or edit them.

---

## 4. Replit-specific coupling to change

| # | Item | Where | Action |
|---|------|-------|--------|
| I-1 | `NODE_ENV=…` POSIX prefix in `dev`/`start`/(build sets it internally) | `package.json` scripts | Add `cross-env`, or use the PowerShell workaround. **Hard blocker on Windows.** |
| I-2 | `@replit/vite-plugin-runtime-error-modal` imported unconditionally | `vite.config.ts:5,11` | Harmless (just a dev error overlay) and stays installed via devDeps. Optional: remove the import + plugin call and drop the 3 `@replit/*` devDeps. `cartographer`/`dev-banner` are already gated behind `REPL_ID` (dynamic import) so they self-skip. |
| I-3 | Auto-migration POSTs all data to old Replit prod after each sync | `server/routes.ts:131` (`PRODUCTION_URL`), `scheduleAutoMigration`, `runMigrationToProduction` | **Set `PRODUCTION_URL`** and/or flip `autoMigrateEnabled` default to `false`. Otherwise every local sync tries to push to the dead Replit URL (network noise / potential data leak to an old deployment). |
| I-4 | `httpServer.listen({ … reusePort: true })` | `server/index.ts:104` | Ignored on Node 20 (unknown option). On Node ≥23 `reusePort` can throw `ENOTSUP` on Windows. Stay on Node 20, or delete the `reusePort` line. |
| I-5 | Bind host `0.0.0.0` (server + Vite) | `server/index.ts:103`, `vite.config.ts:44` | Works on Windows (binds all interfaces). Optionally change to `127.0.0.1` for local-only. `allowedHosts: true` is fine locally. |
| I-6 | `vite-plugin-meta-images` reads `REPLIT_*` domains | `vite-plugin-meta-images.ts` | No-ops locally (returns null). No change needed. |
| I-7 | `.replit`, `main.py`, `pyproject.toml`, `uv.lock` (Replit/nix scaffolding) | root | Not used off-Replit. Leave or delete; `main.py` is a stub `print("Hello…")`. `pyproject.toml` only lists `python-docx` and does **not** capture the real Python deps (see §1.10). |
| I-8 | `migrate-to-production.mjs` | root | One-off dev→prod copy against hardcoded Replit URLs. Not part of run; ignore locally or update both URLs if reused. |
| I-9 | `scripts/post-merge.sh` git hook (`npm install && db:push && build`) | `scripts/post-merge.sh` | Was wired via `.replit [postMerge]`. Bash — won't auto-run outside Replit; run its steps manually if desired. |

---

## 5. Dead / unused code (won't affect local run)

- `server/db/mssql.ts` + `server/services/customer-service.ts` are the only `mssql`
  consumers, and **nothing imports `customer-service.ts`** (verified by grep). They are not
  reachable from `server/index.ts`, so esbuild won't bundle them and the server never opens
  a SQL Server pool. `mssql` / `@types/mssql` can stay as deps but are effectively unused by
  the server. (SQL Server access happens exclusively in the Python scripts.)
- `script/build.ts`'s esbuild `allowlist` names many packages not in `package.json`
  (`axios`, `openai`, `stripe`, `jsonwebtoken`, `cors`, …) — leftovers from a template.
  They simply don't match and are ignored; not a problem.

---

## 6. Ignored / do-not-commit (already in `.gitignore`)

`attached_assets/` and `screenshots/` are Replit scratch dirs containing pasted dumps with
PII/credentials — gitignored, **not** to be read or committed. Also ignored: `config.py`,
`.env*`, `.local/`, `node_modules`, `dist`, `*.tar.gz`. Note `config.example.py` currently
contains **real-looking SQL/Ship credentials** in the committed template — consider
scrubbing them to placeholders (that file is **not** gitignored).

---

## 7. Open questions for the user

1. **PostgreSQL**: reuse the local Postgres from `maba2000-web`, or a dedicated instance/DB
   for QCC? (They are separate projects; sharing a server is fine, use a separate database.)
2. **Auto-migration (I-3)**: is the old Replit production URL still live and should local
   ever push to it? If not, confirm we can hard-disable `autoMigrateEnabled` /
   `migrate-to-production.mjs`.
3. **Ship/UPS API from a local IP**: Replit's IP was WAF-blocked, which is why syncing went
   through the local script. From your LAN, do you want the server's `/api/ship/sync-live`
   route enabled (needs `SHIP_API_*`), or keep shipments coming only via the Python `--ship`
   flow?
4. **`config.example.py` secrets**: OK to replace the real credentials in the committed
   template with placeholders?
5. **Which folder is canonical for the sync scripts** — `local-scripts/`, the duplicate
   `qcc-sync-scripts/`, or the three root-level `sync-*.py`? They appear to be copies; pick
   one to maintain to avoid drift.
6. **`cross-env` vs dotenv**: do you want me to actually patch `package.json` +
   `server/index.ts` (add `dotenv`), or keep those as documented manual steps?
