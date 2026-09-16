# Installer — the calibration station installer

Claude Code loads this file when working under `Installer/`. The build itself is driven by
`scripts/Build-Station-Installer.ps1`, outside this directory. Skills: **`shipping-a-station-installer`**
to build and hand over a version; **`diagnosing-a-station`** when a station is reported broken —
including why "the station does not work" usually means "not yet", and how to verify a station
honestly.

## The calibration station installer

`Installer/setup.iss` (Inno Setup 6) packages the ComServer, the built web app and the launcher
scripts into one `CalibrationSoftware-Setup-vX.Y.Z.exe`. Build it with
`scripts/Build-Station-Installer.ps1 -DbPassword <pw>`, which does config → MSBuild → ISCC →
payload check in one pass and restores `App.config` to its committed default afterwards.

**Where the data comes from.** The topology is
`Priority → on-prem (priority_kyul / kyulan on the PRI instance, via SQL Agent jobs) → AWS (which
*pulls* over a linked server) → calibration station`. **The station reads from AWS.** Do not point
it at the on-prem `Calibrator` database: that is a frozen legacy carcass with none of the app's
tables. See `docs/session1-decisions.md`.

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
- **NI-488.2 is deliberately not bundled** — see `Installer/DRIVERS.md` and `docs/session1-decisions.md`.

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

