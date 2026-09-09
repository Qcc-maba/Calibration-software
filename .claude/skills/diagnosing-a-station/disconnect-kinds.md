# The three ways a logger disconnects

Named by the user, and they are not interchangeable. All three are handled in the server as of
**1.6.9**; none had met a real Fluke Hydra at the time it was written, so the bench checks below are
still the first real test.

| | Power | Communication | Channels |
|---|---|---|---|
| What happened | the logger was switched off and on | the cable or adapter dropped | one sensor was pulled |
| What the link says | still connected — the port never closed | disconnected | still connected |
| What the app shows | data simply stops | the device disappears | **nothing at all** |
| Handled by | `HardwareDeviceHost.ReinitializeBL`, driven from the `DataTimeout` watchdog | the rediscovery timer, `VCTSettings.RediscoverIntervalSeconds` (30 s) | per-channel alert in `Hydra2DeviceBL` |

## Power

A power-cycled logger comes back with its scan configuration erased while its serial port stayed
open. Nothing looks disconnected, and **no discovery pass can find it** — the port is still held. Only
re-sending the setup sequence starts it scanning again.

`CheckDataTimeouts` calls `ReinitializeBL` on the timeout edge: sessions are reset (in-flight request
cleared, queue drained) and the BL's `OnConnection(true)` rebuilds the state machine. Five attempts,
a minute apart, then it stops — a logger that is simply switched off would otherwise be
re-initialised every minute forever, each attempt re-reading the master corrections from SQL. The
restart happens **after** the device read lock is released, for the same reason.

**Bench check:** power-cycle the logger mid-scan. Expect `DataTimeout`, then
`[RECOVERY] SN=… re-initializing the device BL` in `server.log`, then data resuming and
`DataRestored`.

## Communication

Discovery used to run once, at startup, so unplugging and replugging ended the session for good — the
pending device is dropped the moment its link reports disconnected and nothing looked again. The
app's manual refresh only redraws the client. A separate 30-second timer now re-runs discovery;
transports already held are passed in as claimed so a live instrument does not acquire a second
tunnel. It is deliberately not folded into the 2-second device tick: a serial pass opens each
candidate port and waits for `*IDN?`, which would stall every live device.

**Bench check:** unplug the logger's cable, wait, plug it back in. Expect `[REDISCOVER]` passes in
`server.log` and the logger returning without restarting the software.

## Channels

The Hydra reports `9.00E+9` for an open input — `Hydra2DeviceBL.DISCONNECTED_CHANNEL_READING`. It
arrives looking like any other reading, and it used to be dropped with a bare `continue`: no alert,
no log line, and the calibration carried on with **fewer points than the operator asked for**. This is
the dangerous one, because it is the only one that is invisible.

Now edge-detected per channel: `ChannelDisconnected` naming the channel on the way out,
`DataRestored` naming the same channel on the way back.

**Not covered:** a channel that stops appearing in the scan output altogether. The loop pairs
measurements to configured channels by index and stops at the shorter of the two, so a short reply is
just a short reply. Whether the Hydra can produce one has not been observed.

**Bench check:** pull one thermocouple mid-scan. Expect an alert naming that channel and that
channel's trace shaded in the UI; plug it back and expect the shading to close.

## The alert contract — why the type and the channel are not free choices

The web app declares `TAlertType` as a **closed union**: `DataTimeout`, `OutOfRange_Low`,
`OutOfRange_High`, `ChannelDisconnected`, `DataRestored`. Any other name is parsed, stored and never
rendered — so a channel coming back is announced as `DataRestored`, however unhelpful that reads.

The app also closes a channel's shaded disconnect range only on a `DataRestored` carrying the **same
`deviceId:channel` key**. A restore sent as `ALL` leaves that channel shaded for the rest of the
session. Device-wide alerts pass `Channel:"ALL"` and `Value:"0"` as placeholders because
`parse-alert-message.ts` returns null on the first blank field and drops the whole alert silently.

A BL reaches this path through `HardwareDeviceHost.RaiseAlert(type, message, channel)` →
`EventsBus.DeviceAlert` → `ServerCore`. The BL is the only layer that can see a lost channel: to
everything above it, `9.00E+9` is a number.
