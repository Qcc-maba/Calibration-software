# Decisions, and why — session 2

Written 2026-09-09, the same day as session 1 and directly after it. Numbering continues from
session 1 (which ends at 55) so that a reference to a decision number means one thing across the
whole handoff. Nothing here is appended to `session1-decisions.md`; where this session supersedes
something written there, it says so.

This session is one story: a station was reported broken, and it was not.

---

## 56. Exonerate the artifact before suspecting it

**Context.** The report was "the version does not work, and there is again a screen about no internet
connection". The installer had been built and copied to the share an hour earlier, and the web app
inside it had been rebuilt from newer application code — so the bundle was the obvious suspect.

**Chosen.** Reproduce the artifact's behaviour first, in isolation. The shipped `.next\standalone`
was laid out exactly as the installer lays it out, given the station's own `.env`, and started on
**port 3011**: HTTP 200, 92 KB of RTL Hebrew HTML, no `[turbopack]`/`hmr-client` chunks, so a
production build. The artifact was fine, which moved the whole investigation to how it is started.

**Rejected — installing it locally as the first step.** It changes the machine, takes minutes, and
would not have separated "the bundle is bad" from "the launcher starts it wrong", because both
present as a browser that cannot reach the page.

**Rejected — testing on port 3000.** A `next dev` server owns that port on a development machine,
and measuring it while believing it to be the installed app is a mistake already recorded twice in
this handoff. A spare port makes the question unambiguous.

**Detail worth keeping:** the scratch copy holds the production database password, because the
station `.env` does. It was deleted at the end of the check.

---

## 57. Wait for the port, do not wait for a number of seconds

**Context.** `start-all.bat` opened the browser on a flat six-second delay after launching the web
app. `start-webapp.ps1`, which it launches, allows that same app **90 seconds** to start listening —
and logs the outcome either way. Six against ninety, in the same launcher, written at different
times.

From a cold start under `Program Files` the app takes far longer than six seconds, so the browser
arrived at a dead port and showed "this site cannot be reached" — which an operator reads as *no
internet*. The station then came up perfectly, a minute later, after the person had already reported
it broken. It is the recurring symptom, and it is a race, not a fault.

**Chosen.** Poll the port with a `TcpClient` connect, up to two minutes, and open the browser once
something answers. If nothing answers, open it anyway and log where to look.

**Rejected — a longer fixed delay.** Any constant is wrong somewhere: too short on a cold or busy
station, and pure waiting on a warm one. The condition that matters is observable, so observe it.

**Rejected — `Get-NetTCPConnection`.** `start-webapp.ps1` already carries a fallback for builds where
that cmdlet is missing. A `TcpClient` connect is exactly what the browser is about to do and works
everywhere.

**Verification.** Both branches were run through `cmd.exe` — the shell that actually executes the
file — against a live port and a dead one, and each reported correctly. A first attempt to test the
one-liner from inside PowerShell was worthless: the outer shell expanded `$ok`, `$i` and `$c` before
`cmd` ever saw them, and it failed for a reason that does not exist in the real file.

---

## 58. A log that reports an error on a healthy run is worse than no log

**Context.** The station's own launcher log contained, three lines apart:

```
  webapp/server.js - FOUND
  Web App started via start-webapp.ps1 (hidden
  ERROR: server.js not found!
```

**Cause.** A `)` inside a batch `echo` inside an `if (...)` block terminates the block. `echo Started
(hidden)` printed `Started (hidden`, ended the `if`, and let the `else` branch run unconditionally —
so **every successful launch logged both errors**. The rest of the file already escaped as `^(…^)`;
these two lines did not.

**Chosen.** Escape them, and treat the class as a hazard rather than a typo: this file's diagnostics
are the only thing anyone gets from a customer machine, and they had been quietly lying for as long
as the lines existed.

**Rejected — leaving it as cosmetic.** It is not cosmetic. It is a fabricated error in the one
artifact used for remote diagnosis, and it points at a missing file that is present.

---

## 59. Publish the logs twice — the outcome is the part worth having

**Context.** `publish-logs.ps1` ran once, from `start-webapp.ps1`, **before** node was started. The
line that says whether the station came up — `OK: the web app is serving after Ns` or
`ERROR: node exited after Ns` — is written up to 90 seconds later, so it never reached the share
until somebody launched the station a second time. Every remote diagnosis so far was made on a log
that stopped at the launch line, for this reason alone.

**Chosen.** Keep the publish at launch and add one after the outcome is known, plus one on the crash
path. Factored into a single `Publish-StationLogs` so the three calls cannot drift.

**Rejected — publishing only at the end.** A crash before node starts (no node on PATH, missing
`.env`, port already held) would then ship nothing at all — which is precisely the case where the
logs matter most.

---

## 60. A version number that has left the machine is spent

**Chosen.** The launcher fixes shipped as **1.6.10**, an hour after 1.6.9 was built and copied to the
shared folder.

**Rejected — rebuilding 1.6.9 with the fix.** It had already been copied to the share and could
already have been installed. Two different installers under one version number cannot be told apart
by the share, by the operator, or by `install.log` — and the version is the only thing tying a
station's behaviour to a build.

---

## 61. Rebuild the web app, and say what that pulls in

**Context.** The standalone bundle in the build folder was two days old, while the application
repository had moved on — including the fix for the ticket item the user described as "already
closed, it just needs building and verifying".

**Chosen.** Rebuild the standalone from the current application checkout before compiling the
installer. Payload went from ~2,600 files to **4,523**, and the installer from 21.5 MB to 24.6 MB,
which is the portal screens arriving.

**Rejected — shipping the existing bundle.** Faster, and it would have shipped a version whose UI
fix was absent while the release notes said it was present. That is how an item gets reported broken
twice.

**Stated rather than hidden:** the application checkout also had uncommitted portal work in it
(`middleware.ts`, a customer `blocked` page, translations), and a build takes the working tree as it
finds it. Those changes are in 1.6.10.

**Checked before shipping:** the generated station `.env` keeps a whitelist, and an application that
gains a *required* environment variable without it gains a station that starts and then fails every
request. The only genuinely required server variable is still `REMOTE_DATABASE_URL`, which the
launcher derives — so the whitelist is still complete. Note that `.optional()` and `.default(...)`
are often on a continuation line in `env.js`, which makes a one-line grep over-report; that mistake
has been made here before.

---

## 62. Write to the operator in her language, in her ticket, and say what was not tested

**Chosen.** The instructions to Nofar went on MBA-962 in **Hebrew**, naming the exact file to install,
explaining that the screen she saw was a race and not a fault, listing what changed in each of the
three disconnect kinds — and stating plainly that **none of it has been tested against a real logger**,
because none was connected, so her test is the first one.

**Rejected — English, per the repo convention.** Tickets here are written in English because Dako and
Oleksandr read them. That reason does not apply to a comment addressed to a Hebrew-speaking
calibrator about what to do at her bench.

**Rejected — reporting the fixes without the caveat.** Three behaviours were described that have
never run against hardware. Presenting them as verified would have made her doubt her own
observations when one of them misbehaves.

**One testable instruction was included on purpose:** wait a minute and refresh. If that shows the
application, the six-second race is confirmed as what she saw — the diagnosis is a hypothesis until
her logs or that check settle it, and it is labelled as one.

---

## 63. A binary handed to someone else must be rebuildable from the branch

**Context.** The Release build for 1.6.9 consumed four source files that were sitting uncommitted in
the working tree from earlier sessions — a GPIB `FindLstn` discovery path and a 5322A protocol note
among them. Separately, the rediscovery code shipped in the same build had **never been compiled**
until that day, and it carried a syntax error (`CS0579`) that had been sitting there for two days.

**Chosen.** Commit the source the build consumed, in its own commit, saying plainly that it is not
this change's work and that the only claim made for it is that the test suite passes with it in place.

**Rejected — leaving it and noting it.** An installer that cannot be rebuilt from any branch is not
a release; it is a copy of one machine's working directory.

---

## In flight — session 2

**Nothing in 1.6.10 has been verified against a logger.** No Fluke Hydra was connected on the day any
of it was written. The three bench checks that would settle it are in
`.claude/skills/diagnosing-a-station/disconnect-kinds.md`.

**The browser-race diagnosis is unconfirmed for the specific report.** No logs from 1.6.9 or 1.6.10
have reached the share — the newest station logs there are from **08:36**, an older version, hours
before either build existed. The refresh-after-a-minute check in the ticket comment is what confirms
or kills it.

**MBA-962, item by item:**

1. *Automatic logger detection* — the operator's own report says it now starts without picking a COM
   port manually. Needs one more confirmation on 1.6.10.
2. *Connected-logger indication* — the fix is client-side and is compiled into 1.6.10 for the first
   time. **Unverified.** The operator also asked for the logger and sensor numbers to show, and for
   the "נוסף" column to be empty unless the sensor returns two values; that was not addressed.
3. *Units as symbols* — **not started.**
4. *Disconnect and reconnect* — all three kinds are handled in the server; see above about hardware.

**The Windows service is not installed on that station.** Its launcher log shows `net start` failing
with "The service name is invalid", after which the launcher starts the ComServer directly. The
station works; nothing runs after a reboot except through the Startup shortcut. Nobody has decided
whether that matters.

**Three installers now sit in the shared folder** (1.6.7, 1.6.9, 1.6.10). The ticket comment names
1.6.10 explicitly, but deleting the older two from a shared folder was offered and not authorised.

**`session1-decisions.md` contradicts itself about `correction.log`** — an earlier in-flight entry
says it grows without bound, and its own decision 50 says it was deleted. The later entry is
correct. Left as it stands, because a session file is not edited after the fact.

**The `VCT.Core` coverage gate is still red**: 94.66% line, 91.10% branch against a 95% threshold,
with 687 tests passing. Pre-existing, and no clean pre-change baseline was measured.

**`CLAUDE.md` on `ai/handoff` carried a section twice** — "The station does not work" usually means
"not yet", duplicated byte for byte by the merge from `master`. Removed in this handoff commit.
Worth a look at the next merge, in case the same block lands twice again.
