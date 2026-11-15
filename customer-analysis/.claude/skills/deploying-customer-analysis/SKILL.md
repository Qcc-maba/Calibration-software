---
name: deploying-customer-analysis
description: Publish the QCC customer-analysis dashboard to maba-dc2 and verify the deploy took. Use when asked to deploy/publish/ship customer-analysis or QCC Analytics, to check which build is live, or to roll a deploy back. For running the app locally instead, use run-customer-analysis.
---

Two machines, one direction: you build and publish to a network share, the
server pulls from it. You never build on the server.

All paths below are relative to `customer-analysis/` (this app's directory).
Console output in deploy scripts is ASCII on purpose — the Windows Server
console renders Hebrew as mojibake.

## The pieces

| Where | What |
|---|---|
| Your machine | `local-scripts/Publish-ToServer.ps1` — builds, then publishes |
| Share | `\\maba-srv\maba2000\Eliran\qcc-latest` — one folder, always the current build, no history |
| maba-dc2 | App at `C:\apps\qcc-analytics-deploy\app`, port 5000, run by a task **or** service named `QCCAnalytics` |
| maba-dc2 | Updater task `QCCAnalyticsUpdate`, script at `C:\apps\qcc-updater\Update-QCCAnalytics.ps1` |

Deploy scripts live in `deploy/`; the Hebrew operator docs are
`deploy/README.md` and `deploy/CLAUDE-ON-SERVER.md`.

**Not this:** `local-scripts/deploy-and-share.ps1` is an older, unrelated path
that deploys into a local service directory and opens a firewall to a
colleague's IP. It has nothing to do with maba-dc2.

## 1. Publish

```powershell
powershell -ExecutionPolicy Bypass -File .\local-scripts\Publish-ToServer.ps1 -WhatIf   # preview
powershell -ExecutionPolicy Bypass -File .\local-scripts\Publish-ToServer.ps1
```

Runs `npm run build`, stages to `<share>.new`, then swaps it in — so the server
can never read a half-copied build. Writes `build.md5` and injects
`ANTHROPIC_API_KEY` from your local `.env` into the published
`env-additions.txt`. Prints the build id; keep it, step 3 wants it.

**The swap never deletes before the new build is in place (MBA-1033).** It
moves `qcc-latest` aside to `qcc-latest.old-<timestamp>`, moves `.new` in, checks
that the share holds the new build and that the server can read it, and only
then deletes the `.old-` folder. Each rename is retried, because over SMB a
rename can fail for a moment with "Access is denied" while something holds a
handle. On 15 November the old delete-then-move order hit that race and left no
share at all. If a publish fails, its red headline says which build is live:

- **`NOT PUBLISHED`**: the previous build is still at `qcc-latest`. Run it again.
- **`THE SHARE IS MISSING`**: both builds are intact beside it. The next run
  moves `.new` into place before doing anything else.
- **`REFUSING TO PUBLISH`**: a `.new` is left over from an earlier publish.
  Beside a live share it is never deleted automatically: look at it, delete it,
  and run again. With no share, the newest complete build (`.new`, else the
  newest `.old-`) is restored first. An incomplete `.new` is never deleted
  either: the share is still restored from an `.old-` if one is complete, and
  then the script refuses.

To put builds back by hand, always rename. Never delete first: delete-then-move
is the order that lost the share. Example: `Rename-Item <share>.new qcc-latest`.

`-SkipBuild` publishes an existing `dist` without rebuilding.

**`deploy/env-additions.txt` is gitignored and was never committed**, so a fresh
clone does not have it and the publish dies with `missing deployment file`. The
share holds the authoritative copy:

```powershell
Get-Content "\\maba-srv\maba2000\Eliran\qcc-latest\env-additions.txt" |
  Where-Object { $_ -notmatch '^ANTHROPIC_API_KEY=' } |
  Set-Content deploy\env-additions.txt -Encoding ascii
```

Drop the `ANTHROPIC_API_KEY` line — the publish script appends it from `.env`,
so keeping it in the template gives the installed `.env` two of them.

## 2. Apply it on the server

Publishing alone should be enough: `QCCAnalyticsUpdate` compares hashes on a
daily schedule, swaps `dist`, backs up to `dist_bak_<date>`, health-checks and
rolls back on failure. To apply immediately, on maba-dc2 **as administrator**:

```powershell
Start-ScheduledTask -TaskName QCCAnalyticsUpdate
Get-Content C:\apps\qcc-updater\update.log -Tail 20
```

**A publish made with the old `Publish-ToServer.ps1` breaks the next automatic
deploy (MBA-1032).** The task works. It runs as SYSTEM, which reaches the share
as the computer account `MABA\MABA-DC2$`. Computer accounts are not in Domain
Users, so the account's access depends on one explicit ACE on `qcc-latest`:
`MABA\MABA-DC2$`, ReadAndExecute, ContainerInherit+ObjectInherit. The old
publish deleted and recreated the folder. The new folder came with inherited
permissions only, so the ACE was gone. From then on the task logged
`Access is denied` every night and still exited 0. That is how MBA-1027 sat
undeployed from 12 to 15 November.

The publish now carries the old folder's explicit ACEs over and makes sure that
ACE is among them. It then checks that the account can read
`payload\dist\index.cjs`, and the publish fails with `PUBLISHED, BUT THE SERVER
CANNOT READ IT` if it can't. Until the fixed script is merged and is the one
you run, check the ACE yourself after every publish:

```powershell
(Get-Acl '\\maba-srv\maba2000\Eliran\qcc-latest').Access |
  Where-Object IdentityReference -like '*MABA-DC2$'
```

If it is missing, `deploy/CLAUDE-ON-SERVER.md` has the grant. You own the
folder as the publisher, so it runs from your machine and needs no Domain Admin.
On the server side, the updater now exits **5** on a denial, so the task's
`LastTaskResult` turns non-zero. An offline share still exits 0. The script in
`C:\apps\qcc-updater\` does not update itself. Copy the new one over by hand,
as `CLAUDE-ON-SERVER.md` shows.

Manual fallback, when the task cannot deploy:

```powershell
robocopy "\\maba-srv\maba2000\Eliran\qcc-latest" "C:\apps\qcc-server-deploy" /E
cd C:\apps\qcc-server-deploy
.\Install-QCCAnalytics.ps1 -Name QCCAnalytics -Target "C:\apps\qcc-analytics-deploy\app"
```

## 3. Verify — from your own desk

`deploy/postman/QCC-Analytics-Post-Deploy.postman_collection.json` holds the
whole check as five assertions. Remote GETs are allowed after Basic auth
(`server/index.ts`), so this does not need server access.

Headless, no GUI:

```powershell
npx --yes newman run deploy\postman\QCC-Analytics-Post-Deploy.postman_collection.json `
  --env-var password=<dashboard password> `
  --env-var "expectedBuild=<build id the publish printed>" `
  --env-var requireFreshRestart=true
```

Or import the file into Postman, fill the collection variables, Run collection.

| # | Check | Fails when |
|---|---|---|
| 1 | `/api/version` is JSON and matches `expectedBuild` | Old build still serving — it answers HTML, the endpoint not existing there |
| 2 | `/api/pricing/health` → `itemsLoaded` = 875 | Price list missing, or the full Priority PART table (5,400+) loaded instead |
| 3 | `/api/pricing/source-status` → `priorityConnected` | **Blocker.** No Priority means no MABA numbers, the whole point of the screen |
| 4 | `/api/pricing/customers?q=given` finds GIVEN IMAGING | Old build |
| 5 | Serial `MY63001093` → `2512750/22` + `170312-7` | The duplicate-serial bug is back |

Variables: `baseUrl` (`http://maba-dc2:5000`), `user` (`mba`), `password`,
`expectedBuild`, `expectedItems` (875), `minModels` (40000),
`requireFreshRestart`, `serialCustomerCode` (10251 = Mobileye).

`requireFreshRestart=true` adds an assertion that uptime is under an hour —
i.e. that something really did restart. Leave it off when checking a
long-running server, or it reports a failure that is not one.

Then the manual part the collection cannot cover — a real customer file through
`/pricing`, exported to Excel and checked:

```powershell
node deploy\check-pricing-export.mjs "<file>.xlsx"
```

Healthy output: `OK   every MABA number belongs to exactly one serial number`.

## 4. Rollback

```powershell
cd C:\apps\qcc-server-deploy
.\Rollback-QCCAnalytics.ps1
```

Returns to the latest `dist_bak_*` in under a minute and keeps what it replaced
as `dist_failed_<date>`. The old `.env` is `.env.bak_<date>`.

## Gotchas

- **Replacing files does not restart the app.** node does not hold
  `dist\index.cjs` open after startup, so the whole `dist` can be swapped while
  the server keeps serving the old build from memory: new code on disk, old
  screen, looking like the deploy did nothing. Confirm the port actually freed —
  `Get-NetTCPConnection -LocalPort 5000 -State Listen` — and judge by
  `/api/version`, never by "the service says Running". This has caused a false
  "deploy did nothing" twice.

- **`data\pricing` is live data**, not build output: ~2,650 matches users
  confirmed by hand, the one asset no build can restore. Install and update both
  refuse to overwrite existing files there. Back it up; never restore it from a
  build.

- **The deploy changes everyone's dashboard login** to `mba` / `1234`, replacing
  IT's pair. Tell people first, or edit `deploy/env-additions.txt` beforehand.

- **`customerName` is mandatory when pricing by serial.** `lookupSerial()` in
  `server/pricing/services/serialIndex.ts` returns null without it — the serial
  index is keyed per customer. Omit it and the request falls through to fuzzy
  matching and reports no MABA number, which looks exactly like a regression.
  Customer names contain a literal `"` (`בע"מ`), so JSON-escape the name or
  express parses nothing and answers 400.

- **The build id can name a commit it does not contain.** `buildId()` in
  `script/build.ts` stamps `<timestamp> (<git short HEAD>)`, and git knows only
  committed work — so a build made with uncommitted edits reports the previous
  commit. The timestamp stays truthful. Commit or stash before publishing.
  (Tracked as MBA-965; guards were written and reverted, see that ticket.)

- **The Anthropic key has no balance.** AI enrichment of unknown items stays off
  until it is topped up; the system disables that layer after the first failure
  rather than retrying per item, and picks it up again on restart.

- **`PRIORITY_DB_*` is deliberately absent** from `env-additions.txt`. The
  pricing screen reads Priority through the credentials the dashboard already
  uses (`SQL_SERVER_ADDR` / `SQL_UID` / `SQL_PWD`) — the ones known to work on
  that server.

- Logs: `C:\apps\qcc-analytics-deploy\app\logs\service.err.log`.

- Don't touch `app\node_modules` (the bundle is self-contained), and never run
  `npm install` or build on the server.
