---
name: diagnosing-a-station
description: Work out why a calibration station is not working when you cannot sit at it - a blank page or "no internet" screen, a logger that stops recording, or an operator reporting a version as broken. Use when someone reports a station fault, before changing any code.
---

# Diagnosing a station you are not sitting at

Most reports of "the station does not work" have turned out to be the station working slowly, or a
log that lied. Work in this order; each step is cheap and rules out a whole class.

## 1. Exonerate the bundle before suspecting it

Run the shipped web app the way a station runs it, **on a port nothing else owns**:

```powershell
# copy .next\standalone, then .next\static into it as .next\static, then public\
$env:PORT='3011'; node server.js     # with the station .env, plus REMOTE_DATABASE_URL derived
Invoke-WebRequest http://127.0.0.1:3011/ -UseBasicParsing
```

200 with no `[turbopack]`/`hmr-client` chunks in the HTML means the artifact is fine and the fault is
in how it is being started, or on that machine. Delete the scratch copy afterwards — it contains the
production database password.

**Never test on port 3000 on a development machine.** A `next dev` server answers there and has been
mistaken for the installed app more than once, in both directions.

## 2. Read the station's own logs — they ship themselves

`publish-logs.ps1` copies each station's logs to a per-machine folder on the `maba2000` share at
launch **and** once the outcome is known. Use the UNC path, not a drive letter: mappings are
per-user. Look at the newest file's timestamp first — if it predates the version under discussion,
the station never ran that version and everything else you are about to conclude is about the old one.

What to read, in order:

| File | The line that matters |
|---|---|
| `*_launcher.log` | `[1/3]`…`[3/3]`, and whether the service started |
| `*_webapp-launcher.log` | `OK: the web app is serving … after Ns` or `ERROR: node exited after Ns` |
| `*_webapp-error.log` | what node actually said |
| `*_server.log` | `[STARTUP]` / `[REDISCOVER]` / `[RECOVERY]` / `[ALERT]` |

## 3. Two launcher faults that produce a broken-looking station

- **"This site cannot be reached" / no-internet screen.** `start-all.bat` used to open the browser on
  a flat 6-second delay while `start-webapp.ps1` allows the app **90 seconds** to listen. The
  operator saw a dead port; the station came up a minute later. Fixed in **1.6.10** by polling the
  port with a `TcpClient` connect first. **Ask whether a refresh a minute later works** — if it does,
  that was it, and there is nothing else to fix.
- **A log that reports errors on a healthy run.** A `)` inside a batch `echo` inside an `if (...)`
  block closes the block, so `echo Started (hidden)` printed `Started (hidden` and then ran the
  `else` branch. A launcher log that says `FOUND` and three lines later `ERROR: … not found` is this,
  not a missing file. Escape as `^(hidden^)`.

Also know that `net start` failing with **"The service name is invalid"** means the Windows service
is not installed on that machine at all. The launcher falls back to starting the ComServer directly,
so the station works — but nothing runs after a reboot except through the Startup shortcut.

## 4. If the fault is the logger, decide which of the three it is

Power, communication and channels are three different failures with three different repairs, and one
does not cover another. `disconnect-kinds.md` in this skill directory has the symptoms, the code that
handles each, and the bench check that proves it.

**A station is no longer only loggers.** It also hosts oscilloscopes, counters, generators,
calibrators and loads over GPIB, USBTMC and serial, and those fail in ways the three logger kinds do
not cover — an adapter that enumerates with no driver bound, a counterfeit USB-serial chip, an
instrument that corrupts its own replies. Use the **bringing-up-an-instrument** skill and its
`transport-faults.md` for those, and note that its first rule applies here too: decide whether you
have a transport fault or an instrument fault before editing any BL.

## 5. Say what you measured, not what you infer

The station's logs, the payload count and the port owner are facts. "It works now" is not a fact
until something answered. When you have not been able to reproduce a fault — no logger attached, no
logs from that version — say exactly that, and name the check the operator can run that would settle
it. Every wrong conclusion in this area came from reporting a hypothesis in the voice of a result.
