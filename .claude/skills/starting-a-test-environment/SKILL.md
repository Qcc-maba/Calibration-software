---
name: starting-a-test-environment
description: Bring up a complete local environment to test an app-repo branch or PR by hand - a throwaway git worktree, the Next app, a real or simulated VCT WebSocket, the local or staging database, and the portal sign-in API - then report what is actually wired and tear it all down afterwards. Use when asked to test, try, reproduce or review a PR in a browser rather than by reading the diff, or when someone needs a working copy of the whole system on their machine.
---

# Starting a test environment

Everything here runs on one workstation and touches nothing shared except the staging database.
The goal is a browsable app in a **throwaway** checkout, so the developer's own working copy and
`.env` are never disturbed, and one command puts the machine back.

This is the *running* half. Where the app repo lives, its branches, and the Next.js traps are the
**`working-on-the-app-repo`** skill. What to check once it is up is **`verifying-ui-work`**.

## Ask before starting

Two questions, because the answers change which services start and what the environment can prove:

1. **Real VCT or a simulated WebSocket?** Simulated is right unless the task is about logger data
   or a calibration run.
2. **Local Docker database or staging?** Staging is right unless the task risks writing bad data —
   **but portal sign-in does not work against the local database** (see below).

Do not guess. A wrong answer here is discovered twenty minutes later.

## 1. A throwaway worktree

Never test a PR by checking it out in the developer's own clone — they are usually mid-task on
another branch.

```powershell
$app  = 'C:\Users\<you>\dev\GIT_ROOT\app'
$work = 'C:\Users\<you>\dev\pr141'          # anywhere outside GIT_ROOT

git -C $app fetch origin pull/141/head:pr-141 -f
git -C $app worktree add $work pr-141
Copy-Item "$app\.env" "$work\.env"
Copy-Item "$work\.env" "$work\.env.bak"     # restore point for teardown
```

Every edit below is to `$work\.env`. The real `.env` is never touched.

## 2. Install into the worktree - the expensive trap

**Do not junction or symlink `node_modules` from another checkout.** It looks like it works, and it
does for `vitest`, `tsc` and `eslint` - but Turbopack refuses to start:

```
FATAL: Symlink node_modules is invalid, it points out of the filesystem root
```

and the `--webpack` fallback then fails too, because this repo ships a `babel.config.js` which
disables SWC, and Babel cannot compile `src/lib/cookies/user-cookie.ts` (500 on every route). This
is the same class of problem as "it will not run from OneDrive" in `working-on-the-app-repo`:
Turbopack wants a real directory under the project root.

So: a real install, even when the PR does not touch the lockfile.

```powershell
Set-Location $work
npx --yes pnpm@9.15.0 install --frozen-lockfile
```

`pnpm` is often **not on PATH** even though the repo's `packageManager` names it - hence `npx`. Keep
the version in step with `packageManager` in `package.json`. The install reuses the machine's pnpm
store (`%LOCALAPPDATA%\pnpm\store`), so it takes well under a minute and costs hardlinks, not a
second copy of `node_modules`.

## 3. Pick the database

### Staging (the default)

Nothing to do. `.env` already carries `REMOTE_DATABASE_URL_STAGE`, and `src/env.js` resolves it for
every non-production build. It is a shared server, not a sandbox - normal reads and ordinary app
writes are fine, bulk or destructive work is not.

### Local Docker

```powershell
docker start calibrator-test-sql        # port 14330, database CalibratorTest
docker logs calibrator-test-sql | Select-String 'SQL Server is now ready for client connections'
```

Then point the worktree's `.env` at it - the login is `calib_test`, password `CALIB_TEST_PASSWORD`
from `DBA\.env` in this repo:

```
REMOTE_DATABASE_URL_STAGE="sqlserver://localhost:14330;database=CalibratorTest;user=calib_test;password=<CALIB_TEST_PASSWORD>;encrypt=true;trustServerCertificate=true"
```

**What works and what does not** (verified 2026-09-23 against the container as it stands):

| | |
|---|---|
| Internal sign-in and screens | works as-is - `dbo.GetLoginUser` is present, 2146 rows in `Users`, `calib_test` can read them |
| Portal sign-in | works **after deploying three procedures** - everything else they need is already there |

Only the portal *tables* were copied into `CalibratorTest` (`CustomerPortalOtp`,
`CustomerPortalRequest`, `CustomerPortalRequestItem`), not the procedures. Three are needed, not two:
the sign-in API calls `dbo.CreateCustomerPortalOtp` and `dbo.VerifyCustomerPortalOtp`, and the first
of those calls `dbo.GetPriorityContactsByEmail` for its fallback. All three are committed under
`database/procedures/`.

```powershell
$pw = # MSSQL_SA_PASSWORD from DBA\.env
foreach ($p in 'dbo.GetPriorityContactsByEmail','dbo.CreateCustomerPortalOtp','dbo.VerifyCustomerPortalOtp') {
  docker cp "database\procedures\$p.sql" calibrator-test-sql:/tmp/$p.sql
  docker exec calibrator-test-sql /opt/mssql-tools18/bin/sqlcmd `
    -S localhost -U sa -P $pw -C -d CalibratorTest -f 65001 -b -i /tmp/$p.sql
}
```

**`-f 65001` is not optional.** These files carry Hebrew comments, and `sqlcmd -i` reads a UTF-8 file
in the console codepage and mangles them silently. Confirm afterwards with
`OBJECT_DEFINITION(OBJECT_ID('dbo.CreateCustomerPortalOtp')) LIKE N'%ישקר%'`.

Nothing else is missing: `dbo.CustomerContacts` (60,376 rows), `dbo.Customers` (11,328), the
`dbo.GetPortalCustomerIds` function and the `CustomerPortalOtp` table are all present. There is **no
linked server** to Priority in the container, and that is fine by design - the Priority `PHONEBOOK`
lookup is only a fallback for an address the local mirror does not know, and an unreachable linked
server is caught and falls through as "not a known contact". Verified: an unknown address returns
`EmailNotFound` rather than an error.

Sign in as a contact that exists in the **local** `CustomerContacts`. The container holds scrambled
data, so an address that works against staging is not guaranteed to exist here - look one up rather
than assuming. Measured end to end once deployed: create returns `Created` resolving the customer
from the `Mirror`, a wrong code returns `Invalid`, the right code returns `Verified`.

When querying the container by hand, note its collation differs from the system catalogs': string
concatenation over `sys.objects` needs `COLLATE DATABASE_DEFAULT` or it fails with a collation
conflict.

Deploying into this container is throwaway and needs none of the ceremony a shared server does. The
moment the same object has to reach STAGE or PROD - including noticing that one of them is behind -
that is the **`changing-a-database`** skill, and its order of work applies in full.

## 4. Pick the WebSocket

The app connects to `NEXT_PUBLIC_WEBSOCKET_URL`, `ws://localhost:5001/ws` by default.

### Simulated

```powershell
node <this-skill-dir>\simulated-vct-websocket.mjs $work
```

It listens on the same host and path, so no `.env` change. It accepts connections, echoes a
greeting, and answers `ValidateMABA` with `Valid` - enough to prove the socket connects, drops and
round-trips. Its console printing `client connected` is the cheapest proof a screen really opened a
socket.

It sends **no logger data**, so calibration graphs stay empty. Set
`NEXT_PUBLIC_CALIBRATION_USE_MOCK="true"` in the worktree `.env` if the task needs a populated
graph.

### Real VCT

Run `Systems/VCT`; its `WebSocketListenPrefix` defaults to `http://localhost:5001/ws/`, matching the
same env var. Real traces still need a logger attached - **`bringing-up-an-instrument`**.

## 5. The portal sign-in API - only if portal login is needed

Skip this whole section when the task is internal-only, or when the portal screens can be reached
without signing in.

**Disable mail before anything else.** Development is not a dry run.
`Systems/CustomerPortalApi/appsettings.Development.json` carries a working Office 365 mailbox, and
the service tolerates a send *failure* but never skips the send - so a plain `dotnet run` here
really does email the customer whose address was typed, from a company address. Override it in the
launching shell only, so no file changes:

```powershell
$env:CustomerPortal__Smtp__Host = '127.0.0.1'
$env:CustomerPortal__Smtp__Port = '9'
dotnet run --project Systems/CustomerPortalApi --urls http://localhost:5314
```

The send then fails with `SocketException (10061)`, which Development swallows, and the code is
still issued. Nothing reaches the contact - which is why no mail arrives during a correctly set up
test, even though the configuration is real.

**Port 5314, not 5312.** 5312 is this same service's port *in production* on `MbaCustWeb`, and on a
development workstation it is occupied by the installed MabaInstructionAssistant service (whose own
project runs on 5311). Running a local instance on 5312 is worse than a clash: its `/health`
answers with a body identical to production's, so a health check aimed at the wrong window looks
like proof the server is fine.

Two values in the worktree `.env` must follow:

```
CUSTOMER_PORTAL_API_URL="http://localhost:5314"
CUSTOMER_SESSION_SECRET="<CustomerPortal:SessionSecret from appsettings.Development.json>"
```

**The secret is the silent one.** If it differs, the API mints a session cookie the app rejects, and
nothing anywhere says so - sign-in just does not take. Compare the two before blaming the code.

Endpoints, useful for smoke-testing without a browser:

```
GET  /health
POST /api/customer-auth/request-otp   {"email":"..."}   -> {"status":"sent"} | {"status":"emailNotFound"}
POST /api/customer-auth/verify-otp    {"email":"...","code":"000000"}
```

Requesting a code is rate limited to 5 per 900 s; past that the response carries
`retryAfterSeconds` and the UI shows a generic failure.

## 6. Start and smoke-test

```powershell
Set-Location $work
& .\node_modules\.bin\next.CMD dev        # http://localhost:3000
```

Then check these before handing the environment over. Server-side checks do not run JavaScript, so
no WebSocket is attempted - that is the point of the last row.

| URL | Expect |
|---|---|
| `http://localhost:3000/websocket-test` | 200, page reports connected |
| `http://localhost:3000/sign-in` | 200 |
| `http://localhost:3000/customer/sign-in` | 200 |
| `http://portal.localtest.me:3000/customer/sign-in` | 200 |
| `http://portal.localtest.me:3000/sign-in` | **404** - the middleware rewrite to `/customer/blocked`, which is correct |
| `http://localhost:5314/health` | 200, if the portal API is running |

**Use `localhost`, never `127.0.0.1`.** The middleware's internal-host allowlist is `localhost`,
`cal.qcc.co.il`, `stg.qcc.co.il` and `*.vercel.app`. `127.0.0.1` is not on it, so internal routes
are rewritten to a 404 - and on branches that gate the WebSocket by host, the socket silently never
connects. The repo's own `TEST_URL` is `http://127.0.0.1:3000`, which is worth knowing before
trusting an e2e run.

**`portal.localtest.me` is the portal host stand-in.** It resolves to `127.0.0.1` from public DNS,
so no hosts file and no admin rights. To the app it is an unknown external host, exactly like
`portal.qcc.co.il`.

## 7. Report what is wired

Before handing over, say in a few lines what the environment actually is. Whoever tests next cannot
see the flags that were chosen, and a wrong assumption here invalidates the result:

- which **database**, by name and host - staging `Calibrator` on the shared server, or local
  `CalibratorTest` in Docker
- which **WebSocket** - simulated, or a real VCT, and whether a logger is attached
- whether the **portal API** is running, and that **mail is disabled**
- **how to sign in** to each side
- anything **switched off**: the Priority API variables are usually absent from `.env`, so
  Priority-backed features stay dark; that is configuration, not a bug in the branch

## 8. Tear down

Do this when asked, and offer it when testing is clearly over.

```powershell
# stop the dev server, the WebSocket and the portal API (whatever launched them)
Copy-Item "$work\.env.bak" "$work\.env" -Force      # only matters if $work is kept
git -C $app worktree remove $work --force
git -C $app branch -D pr-141
docker stop calibrator-test-sql                      # only if this session started it
```

If a `node_modules` **junction** was used anywhere despite the warning above, delete it with
`(Get-Item $path).Delete()`. `Remove-Item -Recurse` follows the junction and empties the **real**
`node_modules` it points at.

## Credentials

**The values live in `credentials.local.md` beside this file**, which is gitignored. Create it from
`credentials.local.example.md` if it is not there yet, and ask a teammate for the internal password -
it is shared and real, so it stays out of the repo where rotating it would otherwise mean rewriting
history.

| Where | How |
|---|---|
| Internal app, `localhost:3000/sign-in` | the username field is a dropdown of every user email in the database - pick one, then the shared password from `credentials.local.md` |
| Customer portal, `/customer/sign-in` | any real portal contact - `eliran_ha@mba.co.il` resolves on staging; the one-time code is in the same file |

The portal one-time code is the one value safe to write down, and the example file carries it: when
the API runs in Development from a loopback caller it forces **every** code to a fixed value and logs
`DEVELOPMENT LOGIN CODE IS ACTIVE` at startup, so it is the code genuinely stored for that request,
and it cannot happen on a reachable service. With mail disabled it is the only way in, and nothing
reaches the contact.

The identity chain behind portal sign-in - which customer a contact maps to, and how Priority is
read - is **`portal-data-path`**.
