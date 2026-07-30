# Drivers bundled by the installer

The installer must set up not only the application but also the **hardware drivers** the calibration
system needs on the target machine.

## Required

| Driver | For | Why | Status |
|--------|-----|-----|--------|
| **NI-488.2** (National Instruments GPIB) | GPIB-USB-HS+ adapter → **Datron 9100** master | Without it the adapter is dead (Device-Manager **Code 28**); no GPIB device works | ⛔ **not yet in the installer** |

Serial instruments (e.g. Agilent 34401A) use the in-box Windows serial stack and need no extra driver
(a USB-serial adapter brings its own driver, e.g. Prolific).

## How to add NI-488.2 to `setup.iss`

NI-488.2 is a large (~GB) third-party package, so **do not commit it to git**. Two options:

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

> Tracked as a requirement in the Datron 9100 work — see `docs/devices/Datron-9100/README.md`.
