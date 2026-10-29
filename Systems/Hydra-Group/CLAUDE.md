# Systems/Hydra-Group — instruments and loggers

Claude Code loads this file when working under `Systems/Hydra-Group/`, where the instrument BLs live
(`ComServer/ComServerBL`). The server core that drives them — sessions, discovery, identification,
alerts — is in `Systems/VCT/CLAUDE.md`.

Skills: **`bringing-up-an-instrument`** for the BL recipe, the safety rule every signal source obeys,
what manuals leave out, and its `transport-faults.md` (serial `Open()` errors, counterfeit adapters,
GPIB adapters with no driver bound, NI-488.2 and NI-VISA, the two kinds of USB);
**`diagnosing-a-station`** and its `disconnect-kinds.md` for a logger that stops recording.

## Instrument bring-up (`docs/devices/`)

`docs/devices/` is split by what an instrument does, and the code folders mirror it:
`electronics/` (volts, current, frequency, power) and `temperature/`. The folder split is
**organisational only** — namespaces stayed `...HydraDevices.BLCore` / `...HydraDevices.Device` with
no extra level, so a `TypeName` in `ComServerSettings.Modules` does not change when a file moves.
`ComServer.BL.csproj` lists every file explicitly, so **a move that does not update the csproj
silently drops the file from the build.**

Nine electronics instruments have BLs. Each has a `protocol.md` whose status header states plainly
whether it was verified against hardware or written from a manual — trust that header, and do not
promote a device to "verified" without a capture.

**The one rule every source instrument enforces:** the command that energises an output is built,
marked, and **never issued from an init sequence or a read loop** — only from an explicit commanded
target. Tests assert this per device (no init step is the energise command; the init *ends*
de-energised; a setpoint command carries no output-enable). Keep that shape when adding a source.

## Two details the skill does not name

- **Where each instrument's "active interface" setting lives.** Only one interface is live at a time,
  and selecting GPIB leaves serial and USB silently dead. The menus: 5522A `HOST`; 5322A
  `Setup > Interface > Active interface`; M-142 `8. Interface`.
- **The 32-bit VISA runtime lives in `SysWOW64`.** The VCT server is x86, so a 64-bit-only VISA install
  leaves it unable to open any USBTMC instrument while every GUI tool still works.

## How instrument settings should behave

- **Settings should follow the instrument, not the other way round.** "אני רוצה שההגדרות יהיו
  נקיות ולא תלויות במכשיר." Config is not the place to name ports, baud rates and addresses per
  device; discover what is attached and key everything off the identification reply.
- **A default that is wrong for a whole class is a bug, not a detail.** Every instrument broadcast
  `Celsius` because that was the historic default — "בגדול מכשיר שמודד אלקטרוניקה ערך ברירת
  המחדל צריך להיות וולט." Fixing it required reading what the existing enum members actually meant
  rather than what they were named — see decision 34.

## The three ways a logger disconnects

They are three different failures with three different repairs, and MBA-962 is the ticket where
they were separated. Do not treat one as covering another:

1. **Power.** The logger is power-cycled. Its serial port stayed open the whole time, so the link
   reports connected and no discovery pass can find it — the port is still held. It comes back with
   its scan configuration erased and will never produce data again on its own. Repair:
   `HardwareDeviceHost.ReinitializeBL`, driven from the `DataTimeout` watchdog in
   `ServerCore.CheckDataTimeouts`, bounded to five attempts a minute apart.
2. **Communication.** The cable or adapter drops. The link does **not** report it: .NET's `SerialPort`
   just stops saying it is open, with no error and no event, so an identified device used to stay in
   the device list with a dead link. Rediscovery then opened the same port a second time (station,
   8 Oct 2026, MBA-967). Repair: `ServerCore.ReleaseDeadLinks`, run on every device tick, closes a
   link that no longer reports open (`HardwareDeviceHost.ReleaseDeadLink`); the device disconnects
   with the usual alert, and the rediscovery timer (`VCTSettings.RediscoverIntervalSeconds`) finds
   the instrument again without a server restart. Rediscovery never probes a port a link holds,
   including one opened through the AUTO tunnel.
3. **Channels.** One sensor is pulled while everything else stays healthy. The Hydra reports
   `9.00E+9` (`Hydra2DeviceBL.DISCONNECTED_CHANNEL_READING`) for an open input — a value that
   arrives looking like any other reading. Repair: a per-channel `ChannelDisconnected` alert on the
   falling edge and `DataRestored` on the rising one. This is the dangerous one: before the alert
   existed, the reading was dropped with a bare `continue` and the calibration carried on with fewer
   points than the operator had asked for, with nothing on screen and nothing in the log.
   The channels reported down (`_disconnectedChannels`) are what the app has been told, so they
   **survive every re-init** — Confirm, USB replug, power-cycle recovery (MBA-967, review of #30). They
   used to be cleared in `OnCreateStates`: a sensor plugged back in meanwhile then never announced its
   return (the app kept it down for good, and its next unplug was not toasted), and one still out was
   announced down again after every reconnect. Now the first scan after the init decides, channel by
   channel; a channel the new configuration no longer scans is closed at the init with a `DataRestored`
   ("Channel 14 removed from the scan - no longer monitored") and forgotten
   (`ForgetChannelsNoLongerScanned`). The state lives on the BL, which is kept per serial
   (`BaseBLCore._blBySN`) on a host ServerCore reuses for a known serial, so a new link reaches it.

## The Hydra 2625A is polled, and its readings carry the logger's own time (MBA-967)

The logger scans on its own timer (`INTVL`, 30 s) and keeps each scan in memory; the server polls it
(`LOG_COUNT?` → `LOGGED? n` → `LOG_CLR`, with a 28 s wait when nothing is stored). So the moment a
reading reaches the app lags its scan by a varying amount. Until MBA-967 every reading was stamped with
that send time, and evenly spaced scans showed up 29/30/31 s apart.

- **Each reading's `Time` is the logger's scan time**, moved onto the PC clock:
  `HardwarePacket.MeasuredAt` → `ServerCore.FormatLoggerDataTime`. The app already plots, tabulates and
  exports by that field, so no app change was needed. Without a scan time (another instrument, or the
  clock not read yet) it is the send time, as before.
- **The logger's clock cannot be set to the second.** `TIME` takes hours and minutes and sets the
  seconds to 00 (2620A/2625A manual, Table 4-8), so every init leaves it behind by however far into the
  minute it ran. `TIME_DATE?` does return seconds, so the offset is **measured** at init and re-read
  every 10 minutes (`Hydra2DeviceBL.LoggerClockRefreshInterval`), and a new reading replaces the offset
  only when it moves by more than 1.5 s. Whole-second readings disagree by a second on their own, and
  following them would put back the 29/31 s steps.
- **A settled bath repeats itself.** The logger reports to 0.1 °C, so identical scans are normal.
  Judged on values alone, the stale-data check declared a stable overnight run "stalled" three times
  and reset the logger, costing a 48 s gap each time. The scan time is now part of the comparison
  (`HardwareDeviceHost.BroadcastAllMeasurements(…, instrumentScanTime, …)`): a new scan time is a new
  measurement.
- **Every stored scan is sent**, oldest first by scan time. The old code broadcast only the last entry
  of a batch, so when two were waiting the older was cleared unsent. The manual does not say which end
  `LOGGED? 1` is, which is why the order comes from the scan times.
- **Each scan is sent once.** The batch is cleared (`LOG_CLR`) only after it is sent, and polling goes
  on when the clear fails, so the next poll reads the same entries again. A scan no newer than the last
  one sent (`_lastBroadcastScanTime`) is skipped and logged; without that, every failed clear re-sent a
  growing run of old points with times running backwards. The mark is reset by every init, because
  `TIME` puts the logger's clock back to the minute. A logger stuck on one entry therefore goes silent
  and is caught by the 60 s data watchdog rather than by the stale-data check.
- **A query's reply arrives as the data line, then `=>`.** `GetSetTimeSession` answers on the first
  complete line and now hands that packet back as `ResponsePacket`. It used to hand back nothing, so
  the old `TIME_DATE?` check would have thrown a `NullReferenceException` if it had ever run.
- **Only one polling loop may be live.** Every init starts a loop, and a re-init drops only the
  request in flight. A loop asleep in its 28 s wait woke up afterwards and polled next to the new
  one. From three loops up, one loop's `LOG_CLR` landed between another's `LOG_COUNT?` and `LOGGED?`,
  the logger answered `!>`, and that scan was gone: 1,291 scans in Nofar's logs, cured only by
  restarting. Each loop now carries a generation (`_pollGeneration`) and stops once a newer one
  exists. To spot this in a log, count `LOG_COUNT?` per 30 s: one loop sends about 2.
- **It never ran.** A `SingleState` step that returns `Skip2NextStep` is already advanced by the state
  machine. Its reply callback must not call `NextStep()` as well, or the next step is skipped. In
  date sync that skipped `TIME_DATE?` on every init, and the station logs show `DATE`, `TIME`, `RATE`
  with nothing between.
- **Several sensors share one logger.** Each sensor's `SensorsAssociation` used to *replace* the
  channel list, so sensor A on 1-3 and B on 4-6 left the logger scanning 4-6 only, and every reading
  went out labelled as B's. After a `LoggerConfiguration` on the same connection, a `SensorsAssociation`
  now adds its channels (union; `LoggerConfiguration` still sets the list); without one it replaces, as
  before. Each `LoggerData` line carries the sensor that owns its channels — one
  line per sensor. Details in `Systems/VCT/CLAUDE.md`.
- **Every setup command waits for its reply.** The init steps return `Wait4Work`, and
  `Hydra2DeviceBL.AdvanceWhenAnswered` moves the state on when the reply arrives (failed replies too; no
  reply at all moves on at the state's 5 s timeout). They used to return `Skip2NextStep`, so only the
  500 ms device timer kept two commands apart. A request is queued on a pool thread, and when the pool was
  busy (the 30 s rediscovery, on the bench on 2026-10-06) commands went out in pairs 1–2 ms apart.
  `RATE 0` then landed while the logger was answering `TIME_DATE?`, the reply came back as
  `11,5,0,10,6,26?>`, and the run used send-time stamps. `SingleState` now only waits when the reply has
  not already moved the step on, and `NextStepFrom(step)` ignores a reply whose step timed out.
- **A failed clock read is retried at the next poll**, not in 10 minutes (`_loggerClockReadSucceeded`).
- **"Stop scan" stops it until the next Confirm.** `Status:"Stop"` from the logger window ends with
  `Hydra2DeviceBL.StopScanning` on the tick thread: state machine parked, polling generation moved on, then
  `SCAN 0`, `LOG_CLR`, `*RST` (each waits for the previous reply; bench: stopped cleanly). The host keeps
  it stopped - the watchdog, the power-cycle recovery and a live reconfiguration leave it alone, and a
  reconnect sends the three commands again rather than an init (a stop made while the link was down sent
  nothing, and the logger kept scanning) - until a `Status:"Start"` re-inits it. Details in `Systems/VCT/CLAUDE.md`.

## Each Hydra 2625A channel is compensated with its own sensor (MBA-1007)

Until MBA-1007 every reading was compensated with `Hydra2type.Masters[0]` from `HydraBL_Settings.json`,
whatever sensor the operator chose. On the bench (2026-10-28) the operator chose 31-98 on channels 11-13 and
all 21 readings were corrected with 21-449: 22.1 became 22.0701 instead of 22.2336.

- **The sensor comes from the app's `SensorsAssociation`** (`DeviceID` on its `BatchChannels`), into
  `HardwareBL_DeviceType.ChannelMasters` via `HardwareBL_Settings.SetWebSocketChannelMasters`. It is routed and
  held until identification exactly like the channel list, added or replaced exactly like the channels and
  labels, and never saved to the file (`[JsonIgnore]`). A channel no association named uses the last
  association's sensor, because that is the label it reaches the app under.
- **`Masters` keeps two other jobs:** it routes a logger's messages to a family, and it compensates for an
  app that sends no association at all. Do not put an operator's sensor into it.
- **Only families listed in `HardwareBL_Settings.ChannelMasterFamilies` (Hydra2) record a sensor.** The others,
  `Agilent34401aBL` among them, still compensate with `Masters[0]`. Recording a sensor for them would only make
  the log name a sensor that no reading is corrected with.
- **The map is per family, not per connection like the labels.** A reading is compensated once, in the BL,
  before it is broadcast to every client. So the last client to configure the logger decides, as it already
  does for the channel list.
- **A LoggerConfiguration clears the per-channel sensors but keeps the last one** (`ClearWebSocketChannelMasters`,
  review of #41).
  - This mirrors the labels. Without it, run 1 with 31-98 on 11-14 followed by run 2 with 21-675 on 11-13 left
    channel 14 shown as 21-675 and corrected as 31-98.
  - Keeping `Last` means a scan that lands between a re-sent LoggerConfiguration and its associations (the graph
    screen does that mid-run) uses the previous sensor, never the file's master.
- **No certificate, no reading.** A sensor whose certificate isn't loaded is not compensated with another's,
  and its channels are not sent. The scan itself is still broadcast, so the data watchdog does not reset a
  working logger. With the current app nothing shows on screen (decision 2026-10-29); an alert needs a new
  `AlertType` on both sides (see `Systems/VCT/CLAUDE.md`).
- **Certificates load at every init**, before the first scan: the file master plus every associated sensor,
  latest version only (`@GetLatestVersionOnly=1`).
  - A sensor associated mid-run is loaded **in the background**, never on the poll thread. A load is two
    queries of up to 30 s each, which could let the data watchdog reset the logger.
  - "No certificate on file" (0 rows) is an answer, `CalibrationRepository.IsKnownToHaveNoCorrections`. It is
    not asked again until the next init.
  - A failed read is retried every `CertificateRetryInterval` (30 s).
  - The held-back channels are logged once per sensor per init, and again after each load attempt:
    `[HYDRA Correction] CH11,12 | NOT SENT: sensor '99-1': ...`.
- **`correction.log` writes are serialised and never throw** (`CalibrationRepository.AppendCorrectionLog`).
  Two loads at once, from an init and a background load or from two instruments, used to throw "being used by
  another process" out of a BL's init.
- **The log is the validation record:** `[HYDRA Correction] CH11 | Raw=22.1000 | Corrected=22.2336 | Status=OK | MasterID=31-98 | From=sensor`.
  `From=settings file` means the app associated nothing. `scripts/Get-HydraCompensationPairs.ps1` turns
  `server.log` into the raw → compensated table for a time range and checks each pair against
  `dbo.fnMasterValueAfterCorrection` (read-only).
- **Bench-verified on STAGE 2026-10-29:** sensor 31-98 on channels 11-13 gave 54/54 readings `From=sensor`.
  Raw 22.2-22.7 °C matched 31-98's certificate equation to within 6e-5, which is the log's 4-decimal rounding.

## The VCT ignores the certificate's equation (open, found under MBA-1007)

A certificate (`dbo.MeasurementDevicesCorrections`, one row per range, newest `CorVersion` only) is a
**piecewise-linear fit**: each row covers `[Value1, Value2]` with its own `Equation` (`x * (slope)  + const`),
and `Deviation` is only that equation evaluated at `Value1`. Every row on STAGE carries an `Equation`: 31,455
rows over 1,435 devices.

There are three implementations of the compensation, and the VCT is the one that disagrees:

| Where | Model |
|---|---|
| `dbo.fnMasterValueAfterCorrection` (sensors-table "master after correction", computed when read) | Evaluates the containing range's equation and continues the nearest range past either end. This is the reference implementation; tests are in `database/tests/Test-fnMasterValueAfterCorrection.sql`. |
| App `src/lib/helpers/master-sensor-compensation.ts` | The matching range's equation, falling back to point interpolation. It only parses `x * (a) ± b`; the SQL handles nine shapes. |
| VCT `CalibrationRepository.CalcDeviationForTemperature` | **Interpolates between `(Value1, Deviation)` points and ignores `Equation`**, although `GetMeasurementDevicesCorrections` returns it on STAGE. |

Inside a range the results agree to about 1e-5. They differ at the certificate's ends: above the last `Value1` the VCT holds the last deviation flat.
For 31-98 that gives 249.96 → 250.540 against the certificate's 250.430, the same fault Nofar caught in the SQL under MBA-811.
Further faults in the VCT, not yet measured:

- **`Value2` is read as humidity.** For temperature it is the range end, so `CalculateCornersValues` adds four
  invented corner points 10° beyond each end, and those points feed the interpolation near the ends.
- **A reading exactly on the last point** returns `Deviation`, not `value - Deviation`.

To fix: evaluate the range's equation as the SQL function does, read `Value2` as the range end, and reuse the
SQL test cases. Check first that PROD's `GetMeasurementDevicesCorrections` also returns `Equation`; only STAGE
was read.

Nothing stores compensated values. The live readings go to the graph and the Excel export (MBA-485/886).
`MasterValue` on measurement points is raw and is compensated on read, while the precision flow's `MeasuredValue` is the graph average, which the VCT has already compensated.
Nothing records which is which, so storing a VCT-compensated value as `MasterValue` would compensate it twice (MBA-1008).

## The Meatest M-142 cannot do GPIB — and only the M-142

A bit-level corruption on the GPIB bus was attributed first to one instrument, then to the adapter,
and both were wrong. Three instruments on one adapter, one cable, one driver settled it: the
Pendulum CNT-90 (address 7) and Fluke 5322A (address 2) return **0%** corrupt bytes; the M-142
(address 10) returns **86-100%**. It fails on the first high-to-low transition of DIO7 and recovers
on the next byte, which rules out both firmware and software.

It is **not a setting** — the M-142 exposes only interface, address and serial baud/handshake, and
GPIB is eight parallel lines with no format or parity, so no menu item can set a bit on every byte.
**Use its RS-232 port**, which never touches DIO7: Interface = `RS232`, baud 9600, handshake off,
and a **straight 1:1 cable** (2-2, 3-3, 5-5 — it is wired as DCE). Note that this is the *opposite*
of the Fluke 5522A, which needs a null-modem cable for the same rescue.

Corrupted numbers are rejected rather than believed: the corruption turns digits into letters, so
`TryParseValue` fails and the reading is discarded instead of broadcast as a plausible wrong
measurement. That is why those parsers return false rather than 0.

**Do not re-attempt the one-byte-at-a-time read.** It fixes the corruption through VISA and cannot
work through `GpibCom`: NI's device-level `ibrd` re-addresses the instrument on every call, so the
rest of the message is discarded. It was implemented, tested against hardware, and removed.

