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

## Before the first build on a machine

The script needs two tools, and it checks for them before changing anything:

- **MSBuild from Visual Studio 18, any edition.** The Community path is tried first, then `vswhere`
  restricted to version 18. The restriction matters: SSMS 22 registers its own MSBuild with
  `vswhere`, and an unrestricted `-latest` picks that one. BuildTools is enough to find MSBuild.
  Whether it has every targeting pack the ComServer needs has not been confirmed yet.
- **Inno Setup 6**: `winget install JRSoftware.InnoSetup`. Without admin rights, winget installs it
  per user under `%LOCALAPPDATA%\Programs\Inno Setup 6`, not `Program Files (x86)`. The script
  looks in both places.

The scripts also once assumed the app repo sat inside this one (`Calibration-software\app`). Now
`New-StationEnv.ps1` also looks for the dev `.env` in the sibling `GIT_ROOT\app`. `setup.iss` takes
`.env.example` from `-WebAppRoot` through `/DWebAppEnvExample`.

Step 3 builds `CalibrationLauncher` as well as the ComServer. Until 1.6.13 it did not, and the
script relied on a `CalibrationLauncher.exe` left over from an earlier build. On a fresh machine
ISCC then failed at `setup.iss` line 143, "Source file ... does not exist".

If the build fails after step 1, check `git status` for `App.config`. The script now restores it
in a `finally` block. Before that fix, an early failure left the production password in a tracked
file.

1.6.12 and earlier were built on a machine with VS 18 Community and Inno Setup already installed.
The first attempt on another machine (1.6.13, 2026-09-24) found Inno Setup missing altogether.

## The order that works

1. **Server code from `develop`**, on an `MBA-<n>` branch that bumps `AppVersion`. A feature branch
   with unmerged commits ships that work to operators, so do not build from one.
2. **UI from app `stg`**, freshly cloned into `C:\tmp\maba-app` (the `-WebAppRoot` default). Then
   run `pnpm install --frozen-lockfile` and the standalone build below.
3. **The clone needs a `.env` before `next build`.** Copy `app\.env` from the dev checkout. Without it
   `NEXT_PUBLIC_S3_BUCKET_DOMAIN` is empty, the images hostname in `next.config.js` becomes `''`, and
   the build compiles and then dies at "Finalizing page optimization" with
   `TypeError: Expected a non-empty string`.
   `NEXT_PUBLIC_*` values are baked into the bundle, so check two of them before building:
   `NEXT_PUBLIC_CALIBRATION_USE_MOCK="false"` and
   `NEXT_PUBLIC_WEBSOCKET_URL="ws://localhost:5001/ws"`, which is the station's own server.
4. **`.next\standalone\.env` must not reach the installer.** Next copies `.env` into the
   standalone output, and `setup.iss` packs `standalone\*` with no excludes. The station ends up
   with `.env.station`, because it is installed over the dev file. But the dev file (staging
   passwords, SQL admin connection string) is still compressed inside the exe, where anyone can
   extract it. Installers up to 1.6.12 very likely carry it. The build script now deletes it just
   before ISCC runs. `Excludes: ".env"` on the webapp line of `setup.iss` would be a second guard,
   and is not in yet.
5. **The DB password** is the `password=` part of `REMOTE_DATABASE_URL_PROD` in `app\.env`, the
   `app_prod` login. `REMOTE_DATABASE_URL_STAGE` is a different login (`app_stage` on `Calibrator`)
   and does not work with the script's defaults. Claude's auto mode refuses to read that password
   and pass it on, so the user runs the build in a real PowerShell terminal. A `!` line typed into
   the VS Code chat box arrives as a chat message and runs nothing:

   ```powershell
   $l = Select-String -Path 'C:\Users\skulas\dev\GIT_ROOT\app\.env' -Pattern '^REMOTE_DATABASE_URL_PROD=' | Select-Object -First 1; $pw = [regex]::Match($l.Line,'password=([^;"]+)').Groups[1].Value; cd C:\Users\skulas\dev\GIT_ROOT\Calibration-software; .\scripts\Build-Station-Installer.ps1 -DbPassword $pw 2>&1 | % { $_.ToString().Replace($pw,'***') }
   ```

6. **Nothing created only to build may stay behind.** The build script's `Remove-BuildSecrets`
   deletes these files once ISCC has run, whether it succeeded or failed. It also deletes them as
   soon as an earlier step fails. The clone's `.env` is deleted only when `-WebAppRoot` is not a
   developer checkout (`<root>\app` or the sibling `GIT_ROOT\app`). All of them are gitignored, so
   nothing else would warn you they are still there. If a build is interrupted (Ctrl+C, a closed
   window), `finally` may not run, so delete them by hand:

   | File | Holds |
   |---|---|
   | `C:\tmp\maba-app\.env` | the whole dev `.env`, copied in for step 3 |
   | `Installer\assets\.env.station` | the production DB password |
   | `Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config` | the production DB password. Leave it and a ComServer started from `bin\Release` on this machine talks to production |

   ```powershell
   Remove-Item C:\tmp\maba-app\.env, .\Installer\assets\.env.station, `
     .\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe.config
   ```

   All three are regenerated by the next build. When adding a build step that creates another
   temporary file holding a secret, add it to `Remove-BuildSecrets` and to this table. Afterwards,
   check that no production password is
   left anywhere under the two checkouts:
   ```bash
   git ls-files --others --ignored --exclude-standard -z | xargs -0 grep -l CalibratorProd | grep -v '\.exe$'
   ```

   Some hits are expected, because these developer files predate any build and are not the
   build's to delete: the repo `.env`, `DBA\.env`, `customer-analysis\.env`,
   `.claude\settings.local.json` and Debug test configs. Anything else, and anything under
   `Installer\` or `bin\Release`, is a leftover. Apart from those files, the installer should be the
   only place the password remains.

Two checks from Eliran's handover ("Calibration Estate", section 30A) that the script does not make:

- **The ComServer host must be 32-bit.** An earlier installer shipped a 64-bit host, which cannot
  load the 32-bit GPIB library, so every GPIB master was dead on installed stations while working
  on the dev machine. The csproj sets `Prefer32Bit` for Release as well as Debug. Confirm it on the
  built exe: `32BITREQUIRED` and `32BITPREFERRED` must both be set. The 1.6.13 build passed.
- **The standalone output contains symlinks.** Turbopack writes
  `.next\node_modules\<package>-<hash>` links with absolute targets in the build clone
  (`@aws-sdk/client-s3`, `@prisma/client` and `@react-pdf/renderer`, about 490 files).
  ISCC follows them and packs the real files; the 1.6.13 payload count only adds up with them
  included. So the clone must still exist when ISCC runs. Never delete or move it before step 4.

The repo root of app also carries committed scratch scripts, `sp_*.sql` and a few `.xlsx` files,
which the standalone tracer copies into the bundle. They are harmless to run but do not belong on
customer machines. Cleaning them up belongs in the app repo.

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

**Read the payload count the script prints.** A healthy build is thousands of files (4,730 for
1.6.13, 23.4 MB; 4,523 for 1.6.10; ~2,600 before the portal screens landed). Around 18 means the web app silently did not
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

The shared folder is `F:\Eliran\Nofar`, which holds every installer since 1.6.7. The operators'
instructions are in `START-HERE.txt` there, and it names one installer to run ("INSTALL THIS: ...").
Copying a new exe into the folder changes nothing for them until that file names it. Updating
`START-HERE.txt` is operator communication, so agree the wording with the user first.
Copy to the shared folder and verify the copy, then name the exact filename when you tell anyone
about it — several versions accumulate there and the newest is not the first one listed:

```powershell
Copy-Item $src $dst -Force
(Get-FileHash $src -Algorithm SHA256).Hash -eq (Get-FileHash $dst -Algorithm SHA256).Hash
```

Deleting the older installers from a shared folder is the user's call, not yours — ask.
