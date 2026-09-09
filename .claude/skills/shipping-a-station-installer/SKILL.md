---
name: shipping-a-station-installer
description: Build and hand over a calibration-station installer - the build script, the version rule, the payload check that catches a missing web app, and getting it onto the shared folder. Use when asked to produce a new station version, to put a build in front of an operator, or when a station needs the latest server or UI changes.
---

# Shipping a station installer

One command does the whole build:

```powershell
.\scripts\Build-Station-Installer.ps1 -DbPassword <pw>
```

App.config → `.env.station` → MSBuild (Release) → ISCC → payload check, and it puts `App.config`
back to its committed STAGE default afterwards. Defaults target AWS `CalibratorProd`, which is
correct: the topology is `Priority → on-prem → AWS → station`, and the station reads from AWS.

The output lands in `Installer\` as `CalibrationSoftware-Setup-v<version>.exe`.

## Four things that decide whether the build is any good

**Bump the version for every build you hand to anyone.** `#define AppVersion` at the top of
`Installer\setup.iss`. Rebuilding under a number that has already left your machine produces two
different installers with one name, and neither the share nor the operator can tell them apart. This
session shipped 1.6.9, found a launcher fault an hour later, and shipped 1.6.10 rather than
replacing 1.6.9 in place.

**The web app is not built by that script, and a stale bundle is invisible.** It is built separately,
outside OneDrive, and only picked up from `-WebAppRoot`:

```powershell
# in the app checkout, which must live outside OneDrive - Turbopack cannot resolve pnpm symlinks there
$env:BUILD_STANDALONE='true'; $env:SKIP_ENV_VALIDATION='1'; npx next build
```

**Check the build's timestamp against the app repo's last commit before you ship.** A two-day-old
`.next\standalone` compiles into the installer perfectly happily and ships UI fixes that are not in
it — which is exactly how a "fixed and shipped" item gets reported as still broken.

**Clean up after verifying a build on your own machine.** A verification install leaves the
`MabaCalibrationServer` Windows service running the *verified* copy from wherever it was installed,
set to start automatically. Days later it is still there: it takes the WebSocket port so a dev server
cannot open its listener, and it holds the COM ports so discovery finds nothing. It restarts within
seconds of being stopped even with no recovery actions configured, so stopping it is not enough —
decide with the owner whether to set it to manual start or remove it, and do not leave it running
against an old build. The symptom that gives it away is a dev server logging that the WebSocket
prefix "conflicts with an existing registration on the machine".

**Read the payload count the script prints.** A healthy build is thousands of files (4,523 for the
1.6.10 build; ~2,600 before the portal screens landed). Around 18 means the web app silently did not
make it in. The script fails below 2,000 for that reason — do not raise or bypass that floor.

**Every required env var must be on the whitelist.** `scripts\New-StationEnv.ps1` keeps `$keep`,
because shipping `app\.env` verbatim put staging passwords and test accounts on customer machines.
Adding a required variable to the app without adding it there gives a station that starts and then
answers every request with "Invalid environment variables". Check before shipping:

```bash
# required = declared in src/env.js server block with neither .optional() nor .default()
sed -n '/server: {/,/client: {/p' src/env.js | grep -vE "optional\(\)|\.default\(" | grep -E "^\s+[A-Z_]+:"
```

Beware that `.optional()` and `.default(...)` are often on a *continuation line*, so a one-line grep
over-reports. Today the only genuinely required one is `REMOTE_DATABASE_URL`, and the launcher
derives it from `REMOTE_DATABASE_URL_PROD`.

## Commit the source before the binary leaves

A binary handed to someone else must be reproducible from the branch. Two failures this session came
straight from ignoring that: rediscovery code sat uncommitted and **had never once been compiled**
(it had a syntax error), and the Release build pulled in four other uncommitted instrument files that
had to be committed afterwards so 1.6.9 could be rebuilt at all. Build, then `git status --porcelain`
over `Systems/` and `Installer/`, and commit anything the build consumed.

## Handing it over

`Installer\assets\.env.station` is generated and **gitignored** — it holds the production database
password. Never stage it, never paste its contents anywhere.

Copy to the shared folder and verify the copy, then name the exact filename when you tell anyone
about it — several versions accumulate there and the newest is not the first one listed:

```powershell
Copy-Item $src $dst -Force
(Get-FileHash $src -Algorithm SHA256).Hash -eq (Get-FileHash $dst -Algorithm SHA256).Hash
```

Deleting the older installers from a shared folder is the user's call, not yours — ask.
