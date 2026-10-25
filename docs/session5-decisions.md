# Decisions, and why — session 5

Written 2026-09-09. Numbering continues from session 4 (which ends at 81), so a decision number means
one thing across the whole handoff.

**This session's substantive decisions are already filed as 42–49 in `session1-decisions.md`.** A
parallel agent split the working `docs/decisions.md` into the per-session files and pushed them to
`ai/handoff` while this session was still running, so the order-attachments work, the shared-machine
outages, the MBA-946 measurement, the PRI database finding and the rebrand are all recorded there.
Filing them again here would duplicate eight entries and break the rule that a decision number means
one thing.

What follows is only what those entries do not contain: a measurement that corrected one of them
after it was written, and the skill decisions taken during this wrap-up. The in-flight section at the
end is re-verified against the servers as of today, and supersedes the one in session 1.

---

## 82. The port table was wrong, and a source comment is what made it wrong

Decision 46 ("one service, one configuration key") was written with a port table saying the
Instruction Assistant listens on 5311. It does not. Measured on the machine:

```
MabaInstructionAssistant   pid=5636   listening=5312
MabaOrderAttachments       pid=6380   listening=5313
```

`Maba.VCT.CustomerPortalApi` is not installed on that workstation at all; 5314 is its **dev** port.

**Where the wrong number came from.** The header comment in `Systems/OrderAttachments/Program.cs`
names CustomerPortalApi as the service it collided with on 5312, and the table was written from that
comment rather than from the machine. The comment was written during the outage it describes, and it
records what was believed at the time — the service that actually owned 5312 was the Instruction
Assistant.

**Chosen.** Correct the table, and add the instruction to verify with
`Get-NetTCPConnection -State Listen -OwningProcess <pid>` rather than trusting a comment. The comment
in `Program.cs` is code and was left alone; a future session that wants to fix it should be told what
is wrong with it, which is now in both `CLAUDE.md` and the new skill.

**Rejected: quietly changing the number.** The interesting part is not that 5311 was wrong, it is
that a plausible in-code comment was treated as a measurement. That is the same failure the working
notes already warn about in other forms.

---

## 83. A skill for installing these services, because three have gone through it

**Context.** `MabaInstructionAssistant`, `Maba.VCT.CustomerPortalApi` and `MabaOrderAttachments` are
net10 services installed on the same machines. Nothing in `.claude/skills/` covered installing one.
`shipping-a-station-installer` is the Inno Setup station bundle, which is a different artefact for a
different audience; `diagnosing-a-station` mentions services only to say that `net start` failing
means one is absent.

**Chosen.** `installing-a-windows-service`, whose description names the failure shapes rather than
the task, because that is what decides whether it loads: *"one starts and answers nothing"*, and
*"installing one appears to break an unrelated project"*. Neither of those reads as "install a
service" to someone in the middle of them, which is exactly when the skill is needed.

The error-code table moved to a sibling `failure-codes.md`. Every row is a failure whose message
names the mechanism and not the cause — 1639 is a quoting problem reported as an invalid command
line, 1069 is a missing privilege reported as a logon failure.

**Rejected: folding this into `shipping-a-station-installer`.** They share the word "install" and
nothing else. A station installer goes to an operator; these services are configured by hand on a
server, and their failure modes are about *other processes on the same box*.

---

## 84. Three skills corrected in place rather than rewritten

**`changing-a-database`** gained three things this session proved and it did not have: derive a
primary key by counting distinct candidates rather than reading column names (the `(order, LINE)`
assumption failed on the first rebuild); temp tables receiving `OPENQUERY` results need
`COLLATE DATABASE_DEFAULT`, which bites *inside* one procedure where nothing looks cross-server; and
count the rows a shared function's output would change before deploying it — the first
`fnUnreverseVisualText` fix was right for `RE:` and corrupted 24 device descriptions.

**`verifying-ui-work`** gained the boundary trap: a `not-found` inside a route segment renders for
every case you test by calling `notFound()` and does nothing for an address matching no route. The
generalisation is the point — exercise the route the user takes, not the one that is easy to trigger
from code — plus the note that host-branching middleware needs both hosts sent explicitly.

**`committing-work`** gained the rule that a `reference/*` branch must typecheck and lint before
handover, with the MBA-930 branch named as the counter-example, and the routing rule that Dako owns
the portal while everything else goes to Oleksandr.

**Rejected: rewriting any of them.** Each is working procedure that earlier sessions paid for. The
corrections are additive and name the specific claim they add.

**Left alone deliberately:** `bringing-up-an-instrument`, `diagnosing-a-station`,
`merging-stale-branches`, `portal-data-path`, `shipping-a-station-installer`. This session touched
none of their subject matter. `portal-data-path` was the near miss — MBA-946 is a portal problem —
but it is about routing and 404 behaviour, not about the path to data, and widening a skill's scope
to fit one finding is how descriptions stop discriminating.

---

## In flight — re-verified 2026-09-09

Supersedes the in-flight list in session 1. Everything below was checked against the servers or the
working copy today.

**The MBA-946 fix is written and still not committed or pushed.** It is uncommitted on
`reference/MBA-946-not-found` in the app repo: a root `not-found`, a customer-segment `not-found`, a
shared panel component, a shared `isInternalHost` predicate the middleware now imports, and two new
translation keys in both `en` and `he`. `tsc --noEmit`, eslint and prettier all pass, and both host
branches were verified by request against a running dev server. The ticket sits in *In Testing* with
the gap still open. **This is the highest-value loose end** — the work is done and invisible.

**MBA-862 is a confirmed live bug on PROD.** Re-measured today: `dbo.AssignCarToOrder` still matches
"BUGGY — catch swallows the error", `modify_date` 2026-08-31. The mutation reports success while
nothing is written. The repo carries the `THROW;` fix and it has not been deployed to either
environment. Naive text searches pass because three unrelated `THROW 51000` validation guards are
present. Deploying it was offered and not answered.

**`PLAYWRIGHT_BROWSERS_PATH` is still set machine-wide.** Confirmed still set today, to a directory
holding only chromium-1234, while the sibling frontend pins **1208** — that build exists only in the
per-user cache. Clearing it needs elevation and this session was not elevated. The attachments
service no longer depends on it.

**MBA-930's backend is live, its front end is a draft.** The service is `Running`, `/health` reports
database ok, share reachable, cache writable and Chromium installed. `libreOfficeInstalled: false`,
so Office attachments still 422. The UI `reference/*` branch was pushed without a typecheck.

**`portal.qcc.co.il` does not resolve.** Checked today: `stg.qcc.co.il` and `cal.qcc.co.il` both
return 200 in about a second, the AWS maintenance having ended. The portal hostname has no DNS
record, so nothing on that host path can be tested end to end — including the middleware branch the
MBA-946 fix was written for, which had to be verified with an explicit `Host` header instead.

**Two tickets were offered and not opened:** the N+1 in the customer-info hover, and
`GetNumberOfLoggersConfiguredByUser` missing from both environments.

**Still needed from IT:** the service account (`docs/IT-REQUEST-service-account.md`) — the
attachments service currently runs as a named human account, which was explicitly a "get it working
first" decision — LibreOffice on the server, and a decision on which host owns the service.

**A process note for whoever runs the next wrap-up.** Two agents wrote to `docs/decisions.md` and
`CLAUDE.md` in the same working copy during this session. Edits reported as applied were silently
overwritten, and a block had to be renumbered twice because the other agent renumbered underneath it.
If a file changes between reading and editing it, re-read before trusting the result — and prefer
appending at the end of a file over anchoring mid-file while that is happening.
