---
name: bringing-up-an-instrument
description: Add a measurement instrument to the VCT server and prove it works against real hardware - the BL recipe, the safety rule every signal source obeys, and how to tell an instrument fault from a transport fault before blaming either. Use when adding or verifying an oscilloscope, counter, generator, calibrator or load, or when a connected instrument is not identified, returns corrupted replies, or measures nothing.
---

# Bringing up an instrument

Nine electronics instruments have gone through this. The pattern is stable; the failures are not in
the code, they are in the transport and in what the manual does not say.

## Write the BL, then admit what you have not proven

The recipe is `docs/architecture.md` §4 — follow it rather than improvising. In short: an SN branch
in `HardwareDeviceHost.handlePacket`, an `IBLCore`, a `BaseBLDevice`, a settings family, module
registration in **both** `ComServerSettings.json` copies, and `docs/devices/<family>/<name>/protocol.md`.

Two mechanical traps:

- **`ComServer.BL.csproj` lists every file explicitly.** A file added or moved without updating it
  compiles nowhere and fails silently at run time.
- **Keep pure parsing in a `<Model>Readings.cs`** beside the BL. It is the only part testable without
  hardware, and it is where the value of the tests is.

A BL written from a manual is **not verified**. Say "written from the manual, never connected" in
those words, and make `protocol.md`'s status header say it too. Half the instruments in
`docs/devices/electronics/` carry a real capture in that header; trust the header, and do not promote
a device without one.

## The safety rule, which is not negotiable

Six of the nine instruments *source* rather than measure — to 1000 V, 20 A, hipot levels, and with
one option 1000 A through a coil.

**The command that energises an output is built, documented with a warning at every layer, and never
issued from an init sequence or a read loop.** Only an explicit commanded target may do it. Init
sequences drive the other way and end de-energised as a stated intention, not as a side effect of
`*RST`. Every source has tests asserting exactly this: no init step is the energise command, the init
ends de-energised, and a setpoint command carries no output-enable. Copy that shape.

When an instrument needs its output on to be useful — a counter needs a signal — **ask the operator
to press the button on the panel.** Offer to send it, do not send it unasked.

## What manuals get wrong or leave out

Every one of these cost hours and none is in a datasheet:

- **`?` is not always the last character.** `:MEASure:VPP? CHANnel1` is a query with an argument.
  Detecting queries with `EndsWith("?")` means the reply is never read and the session stalls after
  one measurement.
- **A query can have side effects.** On the Fluke 5322A, `SAF:<function>?` *selects* that function.
  Read the mode first and ask only for the mode the instrument is already in, or the poll overrides
  the operator's front-panel choice every tick.
- **`*IDN?` can change with a menu setting.** The 5322A answers `5322A` or `5320A` depending on an
  emulation option. Match every spelling the instrument can produce and normalise to one SN.
- **Only one interface is live at a time** on most of these. Selecting GPIB leaves the serial and USB
  ports *silently dead* — total silence, never an error.
- **A counter with no input blocks forever.** It waits for edges and never returns a terminator,
  wedging the session. Guard by measuring voltage first — a query that always answers — and skip the
  frequency query when the input is dead.
- **Terminators vary.** The Pendulum CNT-90 ends replies with `\n` only; code expecting CRLF reports
  a corruption that does not exist.
- **Model tokens are not literal.** The Keysight scope answers `EDU-X 1002A` while everything else
  says `EDUX1002A`. Match with spaces, hyphens and underscores stripped — and require the vendor name
  too, or a loose model match claims something unrelated.

## Ordering in the identification chain

Vendor-level branches are legacy and greedy: `FLUKE` takes the first 11 characters, `HEWLETT` the
first 15. **Any model-specific branch must come before them**, or a counter is claimed by the
multimeter's BL and driven with multimeter commands.

## Parsing: return false, never zero

Reading helpers return `bool` with an `out` value. On a calibrator `0 V` is a legitimate setpoint, so
a parser that returns 0 on failure produces a number indistinguishable from a real reading. This pays
off in an unexpected place: when a bus corrupts digits into letters, the parse fails and the reading
is *discarded* rather than broadcast as a plausible wrong number.

## When it does not answer

Do not start editing the BL. `transport-faults.md` in this directory covers the transport layer:
which of the four `SerialPort.Open()` errors you have, how a GPIB adapter enumerates with no driver
bound, why removing NI-488.2 also kills USB instruments, and how to decide whether a corrupted reply
is the bus or the one instrument on it.

The single most useful habit: **change one variable at a time.** A bit-level corruption measured on
two instruments was blamed on the shared adapter, with real numbers behind it — and the attribution
was wrong, because a broken driver had changed at the same time. Reading the suspect instrument back
on a proven adapter is what settled it, after the user had been told to replace working hardware.
