# Transport faults: serial, GPIB and USB

An instrument that does not answer is usually not the instrument. Work down this file before touching
a BL.

## Serial: the four `SerialPort.Open()` errors are four different faults

Guessing between these wastes hours; the message tells you which one you have.

| Error | Meaning | What to do |
|---|---|---|
| `A device which does not exist was specified` | stale registry entry, no device behind it | ignore the port; it is a ghost from an adapter that was removed |
| `A device attached to the system is not functioning` | device present, driver refuses to open it | counterfeit chip — swap the adapter |
| `Access denied` | another process holds the port | find the owner before anything else |
| opens fine, then silence | cable, baud rate, or the instrument's interface setting | check the instrument's menu first, then the cable type |

**Counterfeit USB-serial adapters are common and invisible.** Two have appeared on this bench — a
PL2303 and a CH340. Both enumerate cleanly, show `Status OK` with error code 0, no warning icon, and
the genuine VID/PID; both fail **every** open at **every** baud rate. Prolific and WCH ship drivers
that detect clone silicon and refuse the port while leaving the device fully enumerated. The PL2303
announced itself in its own device name (`PL2303TA DO NOT SUPPORT WINDOWS 11 OR LATER`) — read the
full name before blaming the instrument.

Reach for the Prolific adapter that drives the Fluke Hydra logger; it is proven here. An FTDI-based
adapter is the safe thing to buy.

**Cable direction is per-instrument and not guessable.** The Fluke 5522A needs a **null-modem**; the
Meatest M-142 needs a **straight 1:1** (it is wired as DCE). Getting it backwards produces the same
total silence, with no error anywhere. The manual's connector table is the authority.

## GPIB: an adapter can enumerate with no driver bound

The most confusing failure in this area, because everything looks healthy:

- Device Manager: `Status OK`, `ConfigManagerErrorCode 0`, no warning icon
- NI MAX: lists it by its raw `USB\VID_...` path, not as `GPIB0`, and says
  **"Windows does not have a driver associated with your device"**
- `ni488k` (the NI-488.2 kernel driver) stays `Stopped`
- No board is registered, so `viOpen` on `GPIB0::INTFC` returns `0xBFFF00A5`,
  *"interface number not configured"*
- The device's `Service`, `DriverInfPath` and `DriverProvider` properties are all empty

**Cause:** NI-488.2 was installed while the adapter was already plugged in, so the INF never bound.

**Fix,** from an **elevated** prompt — the driver is already staged in the Windows driver store as an
`oem*.inf`; find it by provider `National Instruments`, class `GPIB`, original name `ni488.inf`:

```
pnputil /add-driver <that oem inf> /install
pnputil /scan-devices
```

**The tell that it worked:** the device renames itself from `GPIB-USB-HS+` to **`NI GPIB-USB-HS+`**,
`ni488k` goes to `Running`, and NI MAX lists it as `GPIB0`.

Re-plugging the adapter does **not** fix this, and neither does a reboot — both were tried.

**`viFindRsrc("GPIB?*INSTR")` is not a reliable bus scan.** It depends on what is registered in NI
MAX, and it reported no instruments while one was answering perfectly at address 10.
`TransportDiscovery.FindGpibListeners` asks the NI-488.2 driver directly (`FindLstn`) and finds what
VISA misses. `FindLstn` also detects a device that holds the bus without speaking SCPI.

## USB: two completely different things share the word

- **Virtual COM port (CDC)** — the instrument looks like a serial port. Needs no NI software at all.
  The Fluke 5322A's USB is this.
- **USBTMC** — a test-and-measurement class device. It gets **no** COM port and needs NI-VISA for both
  its kernel driver and `visa32.dll`. The Keysight scope and the Siglent generator are this. The tell
  in Device Manager is `USB Test and Measurement Device (IVI)`.

**The VCT server is x86** (`gpib-32.dll` ships 32-bit only), so it needs the **32-bit** VISA runtime.
A 64-bit-only install leaves the server unable to open any USBTMC instrument while every GUI tool on
the machine still works.

**NI-488.2 and NI-VISA share components.** Uninstalling NI-488.2 also removes the 32-bit `visa32.dll`
and kills USBTMC for instruments that have nothing to do with GPIB. The symptom is
`viOpenDefaultRM` failing with `0xBFFF009E` while `visa32.dll` still exists in `System32`.

## Is the corruption the bus, or one instrument?

Corrupted-but-structured replies — the message is the right length and decodes if you clear one bit —
mean a data line is not being driven. Two questions settle it, in this order:

1. **Does the corruption depend on what preceded each byte?** Group every received byte that requires
   the line low by how many "high" bytes came immediately before it. A line that fails only on the
   first high-to-low transition and recovers is marginal; one that fails regardless is dead.
2. **Do other instruments on the same adapter, cable and driver read clean?** This is the one that
   actually decides it. Three instruments, one adapter, one cable, one session: two at 0% failure and
   one at 86–100% means the fault is that one instrument.

**Do not attribute a fault to shared hardware while more than one variable has changed.** That
mistake was made here: a reinstalled driver and a swapped instrument changed together, the shared
adapter was blamed with a table of real measurements behind it, and the user was told to replace
hardware that turned out to be fine.

**It is also worth ruling out a setting before calling it hardware — but know when you can.** GPIB is
eight parallel lines with no format and no parity, and the M-142 exposes three interface options
(interface, address, serial baud/handshake) with standard interface functions. No menu item can set a
bit on every byte. That reasoning is what made "it is the instrument" safe to state.

**What a corrupted reading actually costs:** the corruption turns digits into letters, the parser
fails, and the reading is discarded. The instrument goes quiet rather than publishing a wrong number.
That is the intended behaviour, not a workaround — but it means an instrument on a bad line is
useless, not merely noisy.

## The workaround that does not work

Reading one byte per call puts milliseconds between bytes and lets a marginal line settle. Through
VISA it works — 0/60 correct became 57/60. It **cannot** be done on the path the server uses: NI's
device-level `ibrd` re-addresses the instrument on every call, so the rest of the message is
discarded and the server receives exactly one byte. It was built, measured against hardware and
removed. Do not re-attempt it on the `gpib-32` path.
