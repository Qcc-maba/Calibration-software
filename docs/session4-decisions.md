# Decisions, and why — session 4

Written 2026-09-09. Numbering continues from session 3 (which ends at 70), so a decision number means
one thing across the whole handoff.

This session added electronics instruments to a VCT server that had only ever handled temperature and
humidity loggers, and then spent most of its time on the transport layer rather than on the code. The
two BLs written from manuals — Meatest M-142 and Fluke 5322A — are the last of nine. What made the
session expensive was a bus fault that was diagnosed correctly, attributed wrongly, retracted, and
then re-attributed once a third variable was ruled out.

---

## 71. Transports are discovered at startup, not configured per instrument

**Context.** Every instrument had its own tunnel in `VCT.json`: a port name, a baud rate, a GPIB
address. The user's instruction was explicit — settings must be clean and not depend on the device,
and should follow from the identification reply or the database instead.

**Chosen.** At startup the server enumerates VISA/USB, the GPIB bus and the serial ports, sends an
identification packet, and creates a tunnel only for links that answered. `VCT.json` went from eight
static tunnels to one.

**Rejected: a configured tunnel per instrument.** It failed three ways at once. Two instruments
configured on the same COM port collided — the auto-detect grabbed the PRODIGIT's port because the
adapter matched "Prolific". A tunnel for an unplugged instrument wedged the entire device tick on its
bus error, taking every other device down with it. And every new instrument meant editing JSON on
every station.

**The measurement that showed it working:** the Hydra logger moved from COM10 to COM11 between
sessions — a different USB port — and was found with no change anywhere.

**Consequence to carry:** an instrument with no identification command cannot be discovered. Optidew
speaks Modbus and has no `*IDN?`, so it still needs a static tunnel and always will.

---

## 72. Identification lives in the device host, not beside the BL that uses it

**Chosen.** The chain of model matches sits in `HardwareDeviceHost.handlePacket`, with `internal
static` helpers next to it for the awkward cases, and the BL cores match on the resulting SN.

**Rejected: putting the match beside the BL.** It reads as more cohesive and it is wrong — the BL
assembly is not referenced by the core, so the check would have to exist twice. Two copies of "which
instrument is this" is the one duplication this system cannot afford. When the same reasoning came up
for the 5322A, its identification helper was written in the Readings class first and then moved, for
exactly this reason.

**Ordering is load-bearing and not obvious.** The vendor-level branches are legacy and greedy:
`FLUKE` takes the first 11 characters (a rule that exists for the Hydra loggers) and `HEWLETT` the
first 15. Any model-specific branch — 5522A, 5322A, 53181A — **must** be placed before them. Without
that, the HP counter and the Agilent multimeter share an SN, and the counter is claimed by the
multimeter's BL and driven with `CONF:VOLT:DC`.

**Two model tokens are not literal strings**, and both were found by connecting hardware:

- The Keysight scope answers `EDU-X 1002A`; its datasheet, our SN and the settings all say
  `EDUX1002A`. Matched with spaces, hyphens and underscores stripped.
- The Fluke 5322A answers **either** `FLUKE,5322A` or `FLUKE,5320A` depending on an emulation menu on
  the front panel. Both are matched and normalised to one SN, so flipping that option cannot silently
  remove the instrument from the server.

---

## 73. Default units follow the instrument, and `VDC` in this codebase does not mean volts

**The bug.** An oscilloscope broadcast its readings labelled `Celsius`. The flat Celsius default
predated any instrument that measured electricity, and the user's correction was blunt: an instrument
that measures electronics should default to Volt.

**Rejected: mapping the existing `MeasureTypes.VDC` to Volt.** This is the obvious fix and it would
have been a serious regression. Reading `ProcessResults` shows `VDC` here means *a resistance read in
volts and converted to temperature* — a PRT. Remapping it would have relabelled every existing
temperature device in the fleet.

**Chosen.** Add `VoltageDC` for genuine volts and leave `VDC` alone; resolve defaults per family from
the identification SN; and keep the sensor-type rule (RTD / FRTD / thermocouple gives Celsius) on top,
because an instrument wired to a PRT reports temperature whatever else it is. The TTI was marked
`FRTD` for that reason, on the user's correction that it measures temperature too.

**The acceptance test was "nothing else changed":** no pre-existing device altered its behaviour.

---

## 74. A reading helper returns false, never zero

Every parse helper returns `bool` with an `out` value rather than a default.

**Why.** On a calibrator, `0 V` is a legitimate setpoint. A parser that returns 0 on failure produces
a number that is indistinguishable from a real reading the moment it is broadcast, and a wrong
calibration reference is worse than a missing one.

**It paid off somewhere unplanned.** When a GPIB line corrupts digits into letters, the parse fails
and the reading is discarded — the instrument goes quiet instead of publishing plausible wrong
numbers. That property is why a bad bus is merely useless here rather than dangerous.

---

## 75. The output-enable command is built, marked, and never called

Six of the nine instruments source rather than measure: up to 1000 V and 20 A, hipot and flash-test
levels, and with one option 1000 A through a 50-turn coil.

**Chosen.** Build the energise command, document it with a warning at every layer it passes through,
and issue it only from an explicit commanded target. Init sequences drive the *other* way and end
de-energised as a stated intention rather than as a side effect of `*RST`. Each source has tests
asserting all three properties.

**Deliberately not built:** any wiring from an application command to an output enable. That is a
product decision — who authorises energising an output and how it is confirmed — not a coding gap,
and it stays open for all six.

In practice this meant asking the operator to press `Output` on the generator's panel before the
counter could measure anything. Offering to send the command and waiting for an answer is the shape
to keep.

---

## 76. The Transmille 3200A was researched and deliberately not written

Three instruments were researched together. The M-142 and the 5322A were written from their manuals;
the 3200A was not.

**Why.** It has no `*IDN?`, a proprietary `F1/S12.32<CR>` dialect, and no documented baud rate.
Everything written from that manual would have been a guess presented as a driver, and it would have
needed a static tunnel to reach at all. It needs the hardware in hand first.

---

## 77. The byte-wise GPIB read: built, measured against hardware, and removed

**Problem.** An instrument's replies arrived with bit 6 set on bytes that should have had it clear.
The user asked whether software could work around it, and specifically whether a delay would help.

**Measured first.** A delay between commands cannot help — the corruption happens between consecutive
bytes *inside one reply*. Reading one byte per call puts milliseconds between bytes instead, and
through VISA it worked: **0/60 correct became 57/60**.

**Rejected and deleted.** It cannot be done on the path the server actually uses. NI's device-level
`ibrd` re-addresses the instrument on every call, so the rest of the message is discarded — the server
received exactly one byte, `M`. It was implemented, wired through a station-wide setting, tested
against the instrument, and then removed rather than left in place as dead code with a caveat. 95%
would not have been acceptable for measurements in any case.

**Kept from that work:** `TransportDiscovery.FindGpibListeners`, a driver-level `FindLstn` bus scan
used as a fallback when VISA's GPIB enumeration returns nothing — which it did while an instrument
was answering normally at address 10.

---

## 78. The bus corruption is one instrument, and the route to that answer was wrong twice

This is the expensive decision of the session and the one worth reading.

**What was concluded, retracted, and re-concluded.** The corruption was first attributed to the Fluke
5522A. Then a second instrument showed the identical signature on a different cable, so it was
attributed to the shared GPIB adapter — with a real measurement behind it: of the bytes requiring the
line low, 0 of 176 failed with no preceding "high" byte, and 32 of 32 failed when one immediately
did. **The user was told to replace the adapter.** Then NI-488.2 was reinstalled and its driver
properly bound, and two other instruments read perfectly on that same adapter and cable — 30/30
byte-identical. The adapter conclusion was retracted, and the DIO7 finding was retracted along with
it, which was also wrong.

**What settled it.** Isolation: three instruments, one adapter, one cable, one driver, one session.
Two at 0% failure, the Meatest M-142 at 86–100%. It is the M-142.

**Ruling out a setting before calling it hardware.** The user proposed an instrument setting, which
was the right instinct and worth checking. It is not one: GPIB is eight parallel lines with no format
and no parity, and the M-142's manual exposes three interface options with standard interface
functions. No menu item can set a bit on every byte.

**The lesson, now in `CLAUDE.md`.** Two variables changed at the same time and the stronger-sounding
conclusion was presented instead of the isolation step. When more than one thing has changed, say so
and isolate; do not spend the user's hardware budget on the more confident-sounding story.

**The workaround** is the M-142's RS-232 port, a separate physical path that never touches that line
— the same thing that rescued the 5522A from the same symptom.

---

## 79. The 5322A read loop is gated on the function the instrument is already in

**Found by connecting hardware, invisible in the manual.** `SAF:<function>?` does not merely read a
setpoint — it *selects* that function. Proven directly: `SAF:MODE?` returned `GBR`, `SAF:LOOP?` moved
the instrument to `LOOP`, `SAF:GBR?` moved it back, with an empty error queue throughout.

**The bug this was.** The BL, written from the manual, queried the ground-bond setpoint on every poll
regardless of mode. It would have dragged the calibrator into Ground Bond every two seconds and
silently overridden whatever the operator selected on the panel.

**Chosen.** Ask `SAF:MODE?` first and request a setpoint only for the mode the instrument is already
in; in any other function, log the mode and broadcast nothing. A test walks the other thirteen
documented functions and asserts none of them triggers the query.

**Consequence:** adding the remaining ~20 functions is not a matter of writing more builders. Each
one has to be gated the same way.

---

## 80. NI driver state is part of the system, and it is diagnosable

Three separate NI faults cost most of a day between them, and all three are now written down because
none is discoverable from the symptom.

- **A GPIB adapter can enumerate with no driver bound.** `Status OK`, error code 0, no warning icon —
  while `ni488k` stays `Stopped`, no board is registered, and VISA answers `0xBFFF00A5` on
  `GPIB0::INTFC`. NI MAX says so in as many words. It happens when NI-488.2 is installed with the
  adapter already plugged in. Neither re-plugging nor a reboot fixes it; `pnputil /add-driver` with
  the staged `ni488.inf` plus `/scan-devices` does, and the tell is the device renaming itself to
  `NI GPIB-USB-HS+`.
- **Removing NI-488.2 also removes 32-bit VISA**, which kills USBTMC for instruments that have
  nothing to do with GPIB. The VCT server is x86 and needs the 32-bit runtime specifically.
- **`viFindRsrc("GPIB?*INSTR")` is not a bus scan.** It reported no instruments while one answered
  normally; it reflects NI MAX registration, not the bus.

**Rejected: treating any of these as an instrument fault.** Each was first visible as "the instrument
does not answer", and each would have led to editing a BL that was already correct.

---

## 81. Counterfeit USB-serial adapters, identified by the error rather than the chip

A CH340 adapter enumerated cleanly — `Status OK`, error code 0, genuine VID/PID, a bound `wch.cn`
driver — and failed **every** open at **every** baud rate. This is the second such adapter on this
bench; a PL2303 did the same thing earlier in the project.

**Chosen: read the `SerialPort.Open()` error rather than guessing.** The four errors are four
different faults — a stale registry entry, a driver refusing a clone chip, another process holding
the port, and a port that opens and then goes quiet (cable, baud or the instrument's own interface
setting). Only the last one is worth taking to the instrument.

**Rejected: rolling the driver back to a pre-detection version.** It works and it is a workaround, not
a fix; the adapter is still a clone. Use the Prolific adapter that drives the Hydra, or an FTDI one.

---

## In flight — session 4

**Two of the nine BLs have never measured a real signal, for different reasons.**

- **Meatest M-142 — blocked on hardware.** Written from the manual, never verified end to end. Its own
  GPIB circuit is faulty (decision 78), so it must move to RS-232: instrument menu
  `8. Interface = RS232`, `10. baud = 9600`, `11. Handshake = OFF`, and a **straight 1:1** cable — not
  the null-modem the 5522A needs. The first serial adapter tried was the counterfeit CH340 of
  decision 81. At session end the bench had been unplugged for a swap and the machine saw no
  instruments at all.
- **HP 53181A — the quickest remaining win.** Identified long ago, its no-signal guard works, but it
  has never been fed an input. The Siglent generator is proven as a source: the same pairing verified
  the CNT-90 at `1000.000743 Hz` against a 1 kHz setpoint. Feed the counter from it.

**Three instruments have only ever run against a resting state.** The 5322A (command set verified
against `FLUKE,5322A,655320925,1.018`, error queue clean), the 5522A (0 V in standby) and the PRODIGIT
3111 (empty input) have never seen a real calibration target. That needs a target, not a cable.

**Remote output enable is unwired for all six source instruments** (decision 75). Product decision.

**The 5322A reads only the ground-bond setpoint.** The other functions are recognised and logged but
have no setpoint query, and each must be gated per decision 79.

**Two devices are effectively dormant.** TTI is identified but its state machine is commented out and
it broadcasts nothing. Optidew cannot be auto-discovered at all and needs a static tunnel.

**Known bugs found and deliberately not fixed:**

- **`Libraries/Connectors/JSON/FileReadWrite.cs` writes with `FileMode.OpenOrCreate`**, which does not
  truncate — a shorter save over a longer file leaves valid JSON followed by a garbage tail. The three
  VCT settings classes were fixed; this shared helper was not, so anything using it inherits the bug.
- **The WebSocket message parser does not strip the closing brace.** It splits JSON by hand, so the
  *last* field of a message parses with `}` attached — `"Value":"Start"` yields `Start}` and the
  server ignores it. One parser already works around it by stripping `{`; the others do not. Sending a
  throwaway field last is the current workaround.
- **A stale `MabaCalibrationServer` service keeps taking the WebSocket port.** It runs an old build
  from a verification directory, restarts within seconds of being stopped despite having no recovery
  actions configured, and holds the COM ports. Setting it to manual start was proposed four times and
  **not done** — it changes how the machine boots and needs the owner's decision.
- **An absent GPIB tunnel can still wedge the device tick.** Discovery avoids creating one, so this is
  mostly latent, but a statically configured tunnel for a disconnected instrument will still block
  every other device.

**The VCT.Core branch-coverage gate.** 671 tests pass; the gate fails on branch coverage against its
95% threshold. Pre-existing, unchanged by this session.
