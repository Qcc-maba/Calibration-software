# Systems/VCT — the VCT hardware server core

Claude Code loads this file when working under `Systems/VCT/`: sessions, discovery, the device tick,
identification, the WebSocket protocol and alerts. The instruments themselves — their BLs, the
loggers, the M-142 — are in `Systems/Hydra-Group/CLAUDE.md`. Build and test commands are in the root
`CLAUDE.md`. Skills: **`bringing-up-an-instrument`** and **`diagnosing-a-station`**.

## Running and testing it

App on `http://localhost:3000`, WebSocket on `ws://localhost:5001/ws/` (must match
`NEXT_PUBLIC_WEBSOCKET_URL` in `app\.env`).

`Run-VCT-Core-Coverage.ps1` gates on **line *and* branch** at 95%. Branch coverage sits at ~93% on
`master`, so the script exits non-zero even when every test passes — check the "Passed!" line before
believing the run failed, and don't attribute the gate failure to your own change without first
confirming with `git diff --numstat` that you touched a `VCT.Core` source file at all.

## VCT server architecture

The end-to-end pipeline (full diagram in `docs/architecture.md` §1):

```
device --RS232/TCP/Modbus--> IComLayer --> HardwareDeviceHost --> BaseSession --> IDeviceBL
                                              (parser, SN id)      (request queue)  (state machine)
                                                                                        |
                              WebSocket clients <-- ServerCore.BroadcastToWebSockets <---+
```

Points that are not obvious from any single file:

- **`BaseSession` runs one request at a time.** A timer dequeues a single `BaseRequest` per tick;
  a device reply is matched to whichever session is waiting. Adding a request does not send it.
- **`HardwareDeviceHost` owns one physical device** and routes parsed packets to its sessions.
  Device identity comes from the `*IDN?` reply, not from configuration.
- **Three settings files, three classes** — `VCT.json` (`VCTSettings`: tunnels, device timeouts,
  WebSocket prefix), `ComServerSettings.json` (`ComServerSettings`: which `IBLCore` modules to load
  by reflection, IP→master mapping), `HydraBL_Settings.json` (`HardwareBL_Settings`: per-device
  channels, rate, sensor, `Masters[]`).
- **Masters** are reference standards loaded from SQL via `CalibrationRepository.InitMasters`; they
  apply a correction curve to readings.
- Adding a device is a fixed recipe — follow `docs/architecture.md` §4 rather than improvising.

## Transport code

- **A query is detected by a `?` anywhere, not at the end.** `:MEASure:VPP? CHANnel1` is a query with
  an argument; checking `EndsWith("?")` means the reply is never read and the session stalls after one
  measurement. `VisaCom.IsQuery` / `GpibCom.IsQuery` (in `VCT.ComLayer`) scan for `?` anywhere — keep
  it that way.

## Settings files

- **Settings files must be written with `FileMode.Create`.** `OpenOrCreate` does not truncate, so
  saving a shorter file over a longer one leaves valid JSON followed by a garbage tail. Fixed in the
  three VCT settings classes; **`Libraries/Connectors/JSON/FileReadWrite.cs` still has it**, so
  anything using that helper inherits the bug.

## Alerts are a closed contract with the web app

`ServerCore.BuildAlertMessage` emits `CMD:"Alert"` lines that the app parses field by field. Two
properties of the app side decide what the server may send, and both fail silently:

- **`AlertType` is a closed union.** The app declares `TAlertType` as exactly `DataTimeout`,
  `OutOfRange_Low`, `OutOfRange_High`, `ChannelDisconnected`, `DataRestored`. A new type name is
  parsed, stored and never rendered — so a channel coming back is announced as `DataRestored`, not
  as some more descriptive name.
- **A restore is matched to its disconnect by `deviceId:channel`.** `getChannelDisconnectRanges`
  closes a shaded range only with a `DataRestored` carrying the *same* channel, so a per-channel
  alert must name its channel and its restore must name it again. A restore sent as `ALL` leaves
  that channel shaded for good.

Every field must also be non-empty: `parse-alert-message.ts` returns null on the first blank and
drops the whole alert with nothing logged on either side. That is why device-wide alerts send the
placeholders `Channel:"ALL"` and `Value:"0"` rather than omitting them.

A BL reaches this path through `HardwareDeviceHost.RaiseAlert(type, message, channel)`, which fires
`EventsBus.DeviceAlert` for ServerCore to broadcast. `AlertMessageFormatTests` and
`DeviceRecoveryTests` copy the app's regexes verbatim — update them in the same change as the app.

## Several sensors on one logger: channels add up, readings carry their own sensor (MBA-967)

On Confirm the app sends one `LoggerConfiguration` (every channel of the logger), then one
`SensorsAssociation` **per sensor** (only that sensor's `BatchChannels`), then `Status:"Start"`. Two
rules follow, both fixed after the bench showed sensor A on 1-3 and B on 4-6 leaving only 4-6 scanned
and every reading labelled as B's:

- **`LoggerConfiguration` sets the channel list; a `SensorsAssociation` only adds to it**
  (`HardwareBL_Settings.AddWebSocketSensorChannels` — a union, live and in the held pre-identification
  config). Channels already present change nothing, return null, and so trigger no re-init.
- **Labels are per channel.** `WebSocketDeviceHost.ChannelLabels` maps channel → the association that
  named it; a `LoggerConfiguration` for logger L clears L's labels (a new Confirm starts fresh).
  `ServerCore.BuildLoggerDataLines` sends **one `LoggerData` line per distinct label**, same `Time`, in
  the unchanged line format; unlabelled channels go under `Associated*` (the last association) as
  before. With no labels the output is byte-identical to the old single line. Labels are keyed by
  channel number only, per socket — with two loggers on one socket using the same channel numbers they
  would collide (as the single association always did).

## VCT runtime: discovery, the device tick, and identification

These four are the difference between "the instrument answers `*IDN?` but never appears" being a
five-minute question and a five-hour one. All were found against hardware.

**Transports are discovered, not configured.** `Settings/VCT.json` holds **one** tunnel — the TCP
listener, which has nothing to discover because it waits for a device to dial in. Everything else is
found at startup by `ComLayer.TransportDiscovery` and turned into a tunnel by
`ServerCore.DiscoverTransportTunnels`. USB and GPIB are enumerated through VISA (`viFindRsrc`), so a
handle is only ever opened where something answers; serial baud cannot be enumerated, so each
candidate port is probed with `*IDN?` across `SerialBaudCandidates` and the first speed that answers
wins. That last part is what removed the final per-device setting — the PRODIGIT wants 115200 and
the Fluke 9600 on the same adapter.

- **A configured tunnel is left alone** and its port is never probed, so an instrument that does not
  answer `*IDN?` can still be pinned by hand. `AutoDiscoverTransports` (default true) disables the
  whole mechanism.
- **Never probe a Bluetooth COM port.** Opening one can block for many seconds; two on the bench
  stretched startup from ~1.6s to **46s**. `ServerCore.ListProbeableSerialPorts` asks WMI which
  ports are Bluetooth and excludes them — which is why the OS query lives in `ServerCore` and
  `DiscoverSerial` takes the candidate list as a parameter rather than building it.
- **A wrong baud rate still returns bytes**, just meaningless ones. `LooksLikeIdentification`
  therefore requires mostly-printable ASCII with at least one letter; accepting noise would pin an
  instrument to the wrong speed permanently.

**The device tick is re-entrancy-guarded, and it has to be.** `System.Timers.Timer` fires every 2s
whether or not the previous callback finished, and `_TempDeviceHost` is a *shared field* that each
tick clears at the start and reads at the end. Overlapping ticks meant one tick queued a device for
promotion while another cleared the list before it got there — the device was re-queued forever and
never promoted, with no exception and no log. Guarded with `Interlocked` (`_deviceTickRunning`);
the body lives in `DeviceTick()`. Three failure paths that used to be silent now log, including
**an identified device that no BL core claimed** — which is what you see when a `DeviceIdToken` does
not match the SN, or the module is missing from `Settings/ComServerSettings.json`.

**Identification matches the model before the manufacturer.** The HP 53181A and the Agilent 34401A
both answer `HEWLETT-PACKARD`, and the old code compared `Substring(0, 15)` — identical for both, so
the 34401A's `"HEWLETT"` token would claim the counter and drive it with `CONF:VOLT:DC`. Match the
model (`53181A`) first. Any new instrument from a manufacturer already present needs the same
treatment.

**`WebSocketProtocolParaser` does not strip the closing brace.** It splits JSON by hand, so the
**last** field of a message parses with a trailing `}` — `{"CMD":"Status","Value":"Start"}` yields
`Value = "Start}"` and the server ignores it. When sending WS commands by hand, put a throwaway
field last (`,"DeviceID":"0"`). Note the misspelled class name; it is spelled that way in the code.

**`Status:"Stop"` is momentary, not a persistent "stay off" state (MBA-974).** It calls
`dev.Disconnect()` once on every live hardware device; it does not touch discovery. A configured or
auto-discovered serial port stays claimed either way (`ServerCore.cs` — RediscoverTransports treats
the currently-held transports as claimed, same as a static tunnel), so the next 30s rediscovery pass
reopens the port, re-probes `*IDN?`, and the device reconnects on its own within seconds if it is
still physically plugged in and powered. There is no code path that makes a device *stay* disconnected
short of unplugging it, stopping the whole ComServer process, or removing its tunnel entry from
settings and restarting.

## Live reconfiguration (MBA-974) and why `ReinitializeBL` has one safe caller

A `SensorsAssociation`/`LoggerConfiguration` message arriving while a device is already connected
updates `HardwareBL_Settings`'s in-memory `Channels`/`MeasurementRate`/`Interval` — nothing more. The
BL only ever reads that settings object once, during its init state machine (InitSystem → DateSync →
Rate → InitChannels → Logs), which runs to completion once per connect and is never ticked again
(`BaseBLDevice.Step__Start_Work` sends `CurrentStep` to `Close` once all states finish). So a channel
added while connected is silently never scanned until the device happens to reconnect while that
channel count is the current one in memory — which is a race, not a guarantee. Confirmed live against
a real Fluke 2625A: `HardwareBL_Settings.ApplyWebSocketConfig` logged `Applied channels ...
channels=[1,2,3,5,11,15]` while `[HYDRA HandleLogData] Received LogsResponse: Measurements.Count=4,
Configured Channels.Count=6` kept firing on every poll.

The fix is to re-run the BL's init sequence (`HardwareDeviceHost.ReinitializeBL`, the same MBA-962
power-cycle-recovery entry point) whenever a live change lands — but **`ReinitializeBL` has exactly
one safe caller: `ServerCore.CheckDataTimeouts`, on the device tick thread, after `DeviceHost_Slim`'s
read lock is released.** Two reasons, both real and both only show up on real hardware, never in a
test:

- `ReinitializeBL` → `BL.OnConnection(true)` resets `CurrentStep`/`States_CurrentIndex` and every
  state. `BL.OnTimer()` (`Step__Start_Work`) runs on the device tick and can be mid-`DoWork` on that
  same state array at any moment. Calling `ReinitializeBL` from anywhere else races the tick.
- `OnCreateStates()` does a blocking SQL read (`HC.Init(...).GetAwaiter().GetResult()`). Calling
  `ReinitializeBL` while holding `DeviceHost_Slim`'s lock — e.g. inline from a WebSocket message
  handler — blocks that thread for the read's duration and stalls anything waiting on the write lock.

So a live-reconfiguration trigger (`ServerCore.MainEventsBus_LiveHardwareReconfigured`, the WS event
handler) must never call `ReinitializeBL` itself. It marks the device instead
(`HardwareDeviceHost.MarkPendingReconfigure`/`TakePendingReconfigureReason`, `Interlocked` so a mark
from the WS thread and a take from the tick thread never race) and `CheckDataTimeouts` folds marked
devices into the same `toRecover` list it already uses for power-cycle recovery. Two marks before the
next tick coalesce into one re-init rather than the second restarting the first mid-sequence — this
is exactly what happens if a `SensorsAssociation` and a `LoggerConfiguration` for the same change
arrive back to back, which they normally do.

