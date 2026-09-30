# Decisions, and why — session 8

Written 2026-09-30, for MBA-967 (Hydra2 logger data acquisition). Numbering continues from session 7,
which ends at 88.

The evidence behind all of these is one overnight run. It was Nofar's Excel export of 2026-09-29
15:20 → 2026-09-30 07:15, 1,912 rows, matched value for value to the station's
`logs_20260930-095120_server.prev.log`. Its intervals were 30 s ×1,839, 29 s ×61, 31 s ×8 and
48–49 s ×3. Row count and span agree exactly with a 30 s cadence, so no scan was lost.

---

## 89. The 48 s gaps were false stalls; fix the check, not the timeout

**Context.** Every long gap has a `DataTimeout` "repeated the same reading for 60 seconds" and a
`[RECOVERY]` re-init inside it. The logger reads to 0.1 °C; the bath had settled; three consecutive
scans were identical. The `LOGGED?` replies show the logger's own scan time advancing by 30 s on each
of them (22:52:44, 22:53:14, 22:53:44), so it was scanning throughout.

**Decision.** Put the instrument's scan time into the stale-data signature
(`HardwareDeviceHost.BroadcastAllMeasurements(…, instrumentScanTime, …)`), so that a new scan time
counts as a new measurement.

**Rejected.** Raising the 60 s limit only makes a longer stable stretch trip it. Turning stale
detection off for the Hydra loses the MBA-962 case it was built for: the same log entry read over
and over, which repeats its scan time as well as its values and is therefore still caught.
The comment in `Hydra2DeviceBL.DetectsStaleData` claimed a Hydra never repeats a number. That
premise was false, and the comment now says so.

## 90. Measure the logger's clock offset; do not try to set it to the second

**Context.** `TIME` takes hours and minutes and zeroes the seconds, per the 2620A/2625A manual,
Table 4-8. Measured: a re-init at 19:42:57.7 left the logger 58 s behind.

**Decision.** After `TIME`, read `TIME_DATE?` and keep PC minus logger (plus 0.5 s, because the
logger truncates). Stamp each reading as scan time plus offset. Re-read every 10 minutes and adopt
a new value only past 1.5 s, so that whole-second noise cannot shift the series by a second.

**Rejected.** Waiting for the PC's seconds to reach :00 before sending `TIME`. That delays every
init, recovery included, by up to a minute, and still drifts afterwards.

## 91. No change in the `app` repo

**Context.** The plan was an app branch to use a new timestamp field. The app already parses the
LoggerData `Time` field (`parse-logger-data-message.ts`) and plots, tabulates and exports by it
(`parseLoggerData`, `excel-export.ts`). The server was simply filling it with the send time.

**Decision.** Fill `Time` with the reading's own time (`HardwarePacket.MeasuredAt` →
`ServerCore.FormatLoggerDataTime`, invariant culture) and leave the app alone. No empty app branch
was created.

## 92. Send every stored scan, ordered by scan time

**Context.** `HandleLogData` broadcast only the last entry of a batch and then cleared the logger's
memory, so when two scans were waiting, one was lost. It did not happen in this run, but it happens
whenever a poll falls late.

**Decision.** Broadcast each entry, oldest first by `LogDate`. The manual numbers `LOGGED? n` without
saying which end is 1. Entries with no measurements (a failed read) are skipped, so they cannot tell
the watchdog a scan arrived.

## 93. Let the date-sync step actually run

**Context.** The station logs show `DATE`, `TIME`, `RATE` and never a `TIME_DATE?`. The step
callbacks called `NextStep()` on a step that had already returned `Skip2NextStep`, so the state
advanced twice and step 2 was skipped. Had it run, it would have thrown: `GetSetTimeSession` never
passed the reply packet back.

**Decision.** Remove the extra `NextStep()` calls (the other states already had them commented out).
Hand the packet back as `ResponsePacket`. A clock read that fails is logged and costs only accuracy;
it no longer throws out of the init.

---

## In flight

- **Not yet run against a real logger.** 753 unit tests pass (23 new). The ConsoleHost builds with
  MSBuild. Coverage is 95.15% lines and 91.74% branches, against 95.13% and 91.70% before; the branch
  figure was already under the 95% gate. The first station run should show `[HYDRA Clock]` lines and
  exactly 30 s steps in the export.
- **The run scanned all 20 channels** (`Configured Channels.Count=20`) while 10 were in use; the other
  10 read the open-input value on every scan. This may be MBA-967's "the first confirmation scans all
  channels" item. Not investigated here.
- **The app's "Starting time" is the last sample, not the first.** `addWebSocketDataAtom` overwrites it
  on every reading. It is an app bug and was left alone.
- **`scripts/build.ps1` does not run here.** It hardcodes a former developer's MSBuild and project
  paths. The root `CLAUDE.md` now says so; the script itself is unchanged.
