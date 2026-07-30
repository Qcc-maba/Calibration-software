# Datron / Wavetek 9100 — GPIB bring-up checklist

Exact steps to bring the 9100 online once the two blockers are cleared:
1. **NI-488.2 driver installed** (adapter currently in Device-Manager Code 28), and
2. **the 9100 programming manual** is available to replace the placeholder commands.

See `README.md` (Hebrew) in this folder for the background. This file is the ordered bring-up
procedure. Work top to bottom; do not skip the ID probe (step 3) before touching the BL.

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

## 5. Replace the placeholder commands from the manual

All command strings live in ONE place: `Datron9100Commands` (bottom of
`Systems/Hydra-Group/ComServer/ComServerBL/Device/Datron9100BL.cs`). Everything there is a labelled
placeholder today. From the manual, replace:

- **`InitSequence`** entries (reset / clear / remote, plus any output/range setup the 9100 needs).
- **`BuildReadValue()`** — the value/output query. Note the 9100 is a **source**: decide whether the
  value to broadcast is a measurement or the programmed setpoint.
- The reply format (for the parser) and the **`OverloadValue`** sentinel constant in `Datron9100BL`.

Do not guess Datron mnemonics — transcribe them. The state machine iterates `InitSequence` by index,
so adding/reordering steps needs no state-machine change.

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

## Still blocked on the user

- **NI-488.2 install** — until then `GpibCom.Open()` cannot succeed (Code 28).
- **9100 programming manual** — needed to replace the placeholder init/read commands and reply format.
- **The 9100 GPIB primary address** — read from the front panel / NI MAX scan (step 1) for `VCT.json`.
