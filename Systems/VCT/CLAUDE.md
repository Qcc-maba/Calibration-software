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

