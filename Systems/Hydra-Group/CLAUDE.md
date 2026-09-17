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
2. **Communication.** The cable or adapter drops, the link reports disconnected, the pending device
   is dropped. Repair: the rediscovery timer (`VCTSettings.RediscoverIntervalSeconds`), which finds
   the instrument again without a server restart.
3. **Channels.** One sensor is pulled while everything else stays healthy. The Hydra reports
   `9.00E+9` (`Hydra2DeviceBL.DISCONNECTED_CHANNEL_READING`) for an open input — a value that
   arrives looking like any other reading. Repair: a per-channel `ChannelDisconnected` alert on the
   falling edge and `DataRestored` on the rising one. This is the dangerous one: before the alert
   existed, the reading was dropped with a bare `continue` and the calibration carried on with fewer
   points than the operator had asked for, with nothing on screen and nothing in the log.

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

