# Drivers bundled by the installer

The installer must set up not only the application but also the **hardware drivers** the calibration
system needs on the target machine.

## Required

| Driver | For | Why | Status |
|--------|-----|-----|--------|
| **NI-488.2** (National Instruments GPIB) | GPIB-USB-HS+ adapter → **Datron 9100** master | Without it the adapter is dead (Device-Manager **Code 28**); no GPIB device works | ⚙️ **installed separately** — deliberately not in the installer |

Serial instruments (e.g. Agilent 34401A) use the in-box Windows serial stack and need no extra driver
(a USB-serial adapter brings its own driver, e.g. Prolific).

## USB-serial adapters: power saving (MBA-987)

The loggers hang off a USB-serial adapter (Prolific PL2303 `VID_067B`, FTDI `VID_0403`, CH340
`VID_1A86`, CP210x `VID_10C4`).
- **What happened on station NOFAR (1.6.15).** That adapter dropped off the bus twice mid-run (MBA-967,
  7 and 8 Oct 2026):
  - USB selective suspend was enabled on AC and DC;
  - the station is a laptop that goes on battery;
  - the event that proves a drop (Kernel-PnP/Device Management **1010**, "surprise removed") had
    already been overwritten. A monitor that is "surprise removed" every ~9 s filled the default
    5 MB log within a day.
- **What Setup does now.** STEP 8 of `setup.iss` runs `assets\Set-StationUsbPower.ps1` as
  administrator on every install, upgrades included.

| Setting | Mechanism | Limits |
|---|---|---|
| USB selective suspend off, AC and DC | `powercfg /setacvalueindex` and `/setdcvalueindex` for subgroup `2a737441-…` setting `48e6b7a6-…` = 0, in **every** scheme; then `powercfg /setactive` on the active scheme | A Group Policy under `HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\48e6b7a6-…` overrides the plan. The script logs it but does not touch it |
| "Allow the computer to turn off this device to save power" off: adapters, USB hubs, root hubs and xHCI host controllers | Present devices: WMI `root\wmi` `MSPower_DeviceEnable.Enable = false`, which is what the Device Manager checkbox does. KMDF drivers (Prolific `ser2pl`, `USBHUB3`, `USBXHCI`), present or not: `Enum\<instance>\Device Parameters\WDF\IdleInWorkingState = 0`, where the framework stores that checkbox and reads it whenever the device starts | WDM drivers (FTDI `FTDIBUS`/`FTSER2K`, CH340) have no stored value, so an unplugged one is covered only once it is plugged in and the task runs. Per device instance: a new port or a new adapter is a new instance |
| Kernel-PnP/Device Management and System logs at least 50 MB, enabled | `EventLogConfiguration` (`Get-WinEvent -ListLog`), never shrunk | An estimate: ten times the one day the 5 MB default held on NOFAR, not yet measured |
| Adapters plugged in later | Scheduled task `MabaCalibration-UsbPower`, run as SYSTEM. Triggers: startup (+1 min), any logon (+30 s), and Kernel-PnP/Configuration event **400** "device configured" (+20 s), which Windows writes when it sets up a device instance it has not seen before. It re-runs the script into `logs\usb-power.log` | An adapter Windows already knows, plugged back into the same port, raises no 400 event. A KMDF adapter is covered by the stored value anyway; a WDM one waits for the next logon or startup |

**Why a task, not the launcher.** `start-all.bat` and `start-webapp.ps1` run as the operator,
without elevation, and none of these settings can be written without it. Event 400 was chosen over
410 ("started") and over the Device Management log, because both of those fire on every re-plug
and every flap of the monitor. The Configuration log held 356 events in six months on a dev laptop.

**Best effort.** Each setting is logged before and after in `install.log`, as lines tagged
`[USB-POWER]`, and ends with `done (apply): N change(s), M warning(s)`. The script never throws and
always exits 0, so a refusal from Windows cannot stop a station from installing.

**Uninstall** removes the scheduled task and leaves the power and event-log settings in place:
- they are harmless on any machine;
- the previous values exist only in `install.log`;
- putting USB power saving back on a machine with a logger still attached would bring back the drops.

**How to check it on a station.** Run `Collect-UsbEvents.ps1` (local-scripts; copy in
`F:\Eliran\Nofar`) as Administrator:
- "Power plan … every scheme" shows `AC=0x00000000 DC=0x00000000` for each scheme;
- "Per-device power saving" shows the adapter with `turn-off-to-save-power=False`;
- "Stored power choice" shows `IdleInWorkingState=0` for a KMDF adapter;
- the "Installer USB power task" section shows the task and its last result.

Without elevation, `Set-StationUsbPower.ps1 -ReportOnly -LogPath <file>` prints the same values and
changes nothing.

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
