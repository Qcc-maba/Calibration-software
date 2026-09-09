# Drivers bundled by the installer

The installer must set up not only the application but also the **hardware drivers** the calibration
system needs on the target machine.

## Required

| Driver | For | Why | Status |
|--------|-----|-----|--------|
| **NI-488.2** (National Instruments GPIB) | GPIB-USB-HS+ adapter → **Datron 9100** master | Without it the adapter is dead (Device-Manager **Code 28**); no GPIB device works | ⚙️ **installed separately** — deliberately not in the installer |

Serial instruments (e.g. Agilent 34401A) use the in-box Windows serial stack and need no extra driver
(a USB-serial adapter brings its own driver, e.g. Prolific).

## Why NI-488.2 is not in the installer

It was bundled in v1.6.3–v1.6.6 and taken out again in **v1.6.7**. NI ships a ~9 MB *online*
installer that downloads several hundred MB while it runs, which turned a **3-minute** station
installation into **15 minutes** — on every machine, for hardware most stations do not have. A
serial-only bench (the Fluke loggers, the PRODIGIT load, the Agilent meters) never needs it.

Install NI-488.2 by hand on the stations that actually get a GPIB master.

Setup still *detects* it and records the outcome in `install.log`:

```
GPIB: NI-488.2 present - GPIB masters (e.g. Datron 9100) can be used
GPIB: NI-488.2 absent  - serial instruments work, GPIB masters will not until the driver is installed separately
```

That line is the whole point of keeping the check: the symptom of a missing driver is an empty
graph, which is expensive to diagnose remotely and cheap to answer from a log.

`GpibDriverInstalled` looks for `gpib-32.dll` in **SysWOW64** (it is the 32-bit DLL the ComServer
loads; `{sys}` is System32 on x64 and will not hold it) and for the NI key under both the 64-bit and
`Wow6432Node` views. The `Wow6432Node` check was missing and made Setup report the driver absent on a
machine that had it.

## If you ever want it back in the installer

`Installer\drivers\ni-488.2_26.5_online.exe` — National Instruments' **online** installer, ~9 MB.
It is gitignored (`Installer/drivers/`): NI's redistributable, not ours. A fresh clone must drop the
file back in before building, or ISCC fails on the missing source.

- `[Files]` ships it to `{tmp}` with `Check: GpibDriverMissing`, so a station that already has the
  driver carries no extra weight and re-installs stay fast.
- `[Run]` executes it with `--quiet --accept-eulas --prevent-reboot`, `waituntilterminated`.
- `ssPostInstall` re-checks and records the outcome in `install.log` — the symptom of a missing
  driver is otherwise silent (an empty graph), which is expensive to diagnose remotely.

**It downloads several hundred MB while it runs**, so the station needs internet for that step and it
can take minutes. Failure is deliberately non-fatal: a serial-only bench must still finish.

`GpibDriverInstalled` looks for `gpib-32.dll` in **SysWOW64** (it is the 32-bit DLL the ComServer
loads; `{sys}` is System32 on x64 and will not hold it) and for the NI key under both the 64-bit and
`Wow6432Node` views.

## Alternative: bundle the offline package

The full offline installer is ~GB, so **do not commit it** either. If you prefer it over the online
one — a station with no internet, say:

1. **Bundle the offline installer** — place NI's `ni-488.2_*.exe` next to the build (gitignored),
   ship it via `[Files]`, and run it silently from `[Run]`:
   ```
   [Files]
   Source: "drivers\ni-488.2.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall
   [Run]
   Filename: "{tmp}\ni-488.2.exe"; Parameters: "--quiet --accept-eulas"; \
     StatusMsg: "Installing GPIB driver (NI-488.2)..."; Check: GpibDriverMissing
   ```
2. **Download at install time** — smaller installer, needs internet during setup.

Prefer a `Check:` that skips the install when NI-488.2 is already present (detect `gpib-32.dll` in
System32 or the NI registry key), so re-installs are fast. Verify NI's redistribution terms and the
current silent-install switches against their documentation before shipping.

> Tracked as a requirement in the Datron 9100 work — see `docs/devices/electronics/Datron-9100/README.md`.
