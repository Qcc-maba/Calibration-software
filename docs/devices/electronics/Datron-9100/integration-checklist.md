# Datron / Wavetek 9100 — GPIB bring-up checklist

**STATUS 2026-08-02 — both original blockers cleared and the link is verified live:**
- ✅ **NI-488.2 installed** (adapter status OK; `gpib-32.dll` present in SysWOW64). Note: the DLL is
  `__cdecl` and 32-bit only — `GpibCom` now declares `CallingConvention.Cdecl` and the host must run x86.
- ✅ **9100 found at GPIB PAD 18**, `*IDN?` → `Wavetek Ltd,9100,40733,5.12`, `*OPT?` → `0,1,0,0,1,0`.
- ✅ **Full SCPI-1994 confirmed** (`SYST:VERS?` → `1994.0`) once in Manual mode. `*RST` reverts to
  Manual mode and forces the output OFF, so it is the safe remote entry point.
- ✅ **Commands finalized** — `Datron9100Commands` now holds real, verified SCPI (no placeholders).

Remaining to go fully live: set `GpibPrimaryAddress: 18` in `VCT.json` (step 4), register the BL core
(step 4), and run the end-to-end read/output test (steps 6–7) with the operator present.

See `README.md` (Hebrew) in this folder for the background. This file is the ordered bring-up
procedure.

---

## 0. Prerequisites

- NI GPIB-USB-HS+ adapter (VID_3923 / PID_7618) plugged in.
- **NI-488.2** installed (download from ni.com). This provides `gpib-32.dll`, which `GpibCom`
  P/Invokes. Without it, `GpibCom.Open()` throws a `DllNotFoundException` with an install hint.
- The 9100 powered on and its GPIB **primary address** noted from the front panel (0–30).
- The 9100 programming manual PDF dropped into this folder.

---

## 1. NI MAX — discover the adapter and the instrument address

1. Open **NI MAX** (Measurement & Automation Explorer).
2. Under **Devices and Interfaces**, confirm the **GPIB0** (GPIB-USB-HS+) interface appears with no
   error. If it shows a warning/Code 28, NI-488.2 is not correctly installed — fix that first.
3. Right-click **GPIB0 → Scan for Instruments**. The 9100 should appear at a primary address (PAD).
   Record that PAD — it becomes `GpibPrimaryAddress`. The interface number (0) is `GpibBoardIndex`.
4. Note the exact PAD; if nothing is found, check the 9100's GPIB address setting and cabling before
   going further (an empty scan means `ENOL` / "no listener" later).

---

## 2. `*IDN?` / ID probe (independent of our server)

Prove the link and capture the real identity string **before** wiring the server.

- In **NI MAX**, select the 9100 → **Communicate with Instrument**. Send `*IDN?` and read.
  - If the 9100 answers, record the exact reply (expected to contain `DATRON`, `WAVETEK`, or `9100`).
  - **If `*IDN?` returns nothing / errors**, the 9100 predates IEEE-488.2 `*IDN?`. Consult the
    manual for its identification query and record BOTH the query and the reply format. This value
    drives step 4.
- Confirm the reply's line terminator behaviour (EOI vs. a terminator char). `GpibCom` opens with
  `EOT=assert-EOI` on write and `EOS=none` on read (reads end on EOI or a full buffer), which matches
  standard EOI-terminated instruments. If the 9100 needs an EOS terminator, note it — that is a
  `GpibCom` open-parameter change, not a BL change.

---

## 3. Reconcile the identification with the code

The server identifies a device by matching tokens in the ID reply.

- SN token expected by the BL core: **`Datron9100`** (`Datron9100BLCore.DeviceIdToken`).
- The match happens in `HardwareDeviceHost.handlePacket`, which sets the SN when the ID reply contains
  `DATRON` / `WAVETEK` / `9100`.
- The identify command sent to pending devices is the generic `*IDN?`. **If step 2 showed the 9100 does
  not answer `*IDN?`**, the identify command (not just the BL) must be adjusted so a reply is produced;
  otherwise the device never leaves the pending list. Capture that requirement here before proceeding.

---

## 4. `VCT.json` — configure the GPIB tunnel

Add a tunnel with the GPIB fields set. `GpibPrimaryAddress >= 0` is what switches the tunnel into GPIB
mode (see `ServerCore.Start` → GPIB branch and `Tunnel.GpibPrimaryAddress` / `GpibBoardIndex`).

```jsonc
{
  "Tunnels": [
    {
      "Name": "Datron9100-GPIB",
      "GpibPrimaryAddress": 4,   // <-- the PAD recorded in step 1
      "GpibBoardIndex": 0        // <-- NI interface number (GPIB0 => 0)
    }
    // ... other tunnels
  ]
}
```

- Leave `SerialPortName` / `Address` / `Ports` unset on this tunnel — with `GpibPrimaryAddress >= 0`
  the GPIB branch is taken and those are ignored.
- Also confirm the BL module is registered so the identified device gets claimed: the
  `Datron9100BLCore` must be listed in `ComServerSettings.json` → `Modules` (same as the other cores).

---

## 5. Commands — DONE (real SCPI, verified live)

All command strings live in ONE place: `Datron9100Commands` (bottom of
`Systems/Hydra-Group/ComServer/ComServerBL/Device/Datron9100BL.cs`), delegating to the
"Datron / Wavetek 9100" region of `HydraProtocolHelper`. These are the real, verified SCPI commands:

- **`InitSequence`** = `*RST` (→ Manual mode + output OFF) then `*CLS`. No source value; output stays OFF.
- **`BuildReadValue()`** = `SOUR:VOLTage?` — the 9100 is a **source**, so this echoes the programmed
  DC setpoint (`1.000000E+00` after `*RST`), not a measurement. Interpret units/format in the parser.
- **Output control** builders are present but intentionally *not* auto-invoked: `BuildSelectFunction`
  (`SOUR:FUNC:SHAP DC|SINusoid|…`), `BuildSetVoltage/Current/Resistance/Capacitance/Frequency`,
  `BuildOutputOn`/`BuildOutputOff` (`OUTP:STAT ON/OFF`). A commanded calibration target does:
  `*RST` → `SelectFunction` → `Set…` → `OutputOn`, and `OutputOff` when done.
- Error/status: `BuildReadError` (`SYST:ERR?`), `BuildOperationComplete` (`*OPC?`).

---

## 6. Expected identify → BL flow (what "working" looks like in the log)

1. `ServerCore.Start` logs `Opening GPIB board 0 address <PAD>...` then `GPIB address <PAD> opened OK`.
   - A failure here logs the decoded `ibsta/iberr` (e.g. `ENOL` = wrong address / device off,
     `ENEB` = wrong board index / driver not loaded, `EDVR` = driver missing).
2. The 2-second pending timer sends the identify query; the reply reaches `handlePacket`, which sets
   `SN = Datron9100`.
3. The device is promoted to identified, `InitSessions()` runs, and a connection event fires.
4. `Datron9100BLCore.OnDeviceConnetion` matches the SN, creates a `Datron9100BL`, and attaches it.
5. `StateWork__InitSystem` walks `InitSequence`; then `StateWork__Read` issues the read query in a
   callback-driven loop.

---

## 7. Verify a reading reaches the WebSocket

1. Start the server/GUI (`ComServer.Hosts.GUIMonitor`, or
   `.\scripts\Start-Calibration-Stack.ps1 -BuildServer`).
2. Watch the log for the open-OK line and the `SN = Datron9100` identification.
3. Confirm `ReadValueCallback` is broadcasting: `HW_Device.BroadcastAllMeasurements` produces an
   `E,<SN>,<ch>,<value>` event that flows through `IncomingEvents` → `EventsBus` →
   `ServerCore.BroadcastToWebSockets` → `LoggerData` message.
4. Connect a WebSocket client to `WebSocketListenPrefix` (default `http://localhost:5001/ws/`; the app
   uses `NEXT_PUBLIC_WEBSOCKET_URL` — they must match) and confirm `LoggerData` messages with the 9100
   value arrive. A browser dev-console WebSocket, or the app's live view, is sufficient.
5. Cross-check the value against the 9100 front panel.

If the device identifies but no measurements arrive, the usual causes are: the BL core is not
registered in `ComServerSettings.Modules`, or the read query/parse is still a placeholder (step 5).
See `docs/architecture.md` §5 (debugging table).

---

## Remaining (all software-side / operator-supervised — no external blockers)

- Add the GPIB tunnel to `VCT.json` with `GpibPrimaryAddress: 18`, `GpibBoardIndex: 0` (step 4).
- Register `Datron9100BLCore` in `ComServerSettings.json` → `Modules` (step 4).
- Run the host as **x86** (the driver DLL is 32-bit only) and do the end-to-end read test (steps 6–7).
- Live OUTPUT/sourcing test (`OutputOn` with a real target) should be done with the operator present,
  as it energises the terminals with real V/I.
