# Decisions, and why — session 6

Written 2026-09-09. Numbering continues from session 5 (which ends at 84), so a decision number means
one thing across the whole handoff.

**This session's substantive decisions are already filed as 27–31 in `session1-decisions.md`**, along
with its in-flight list under *"In flight — the portal go-live"*. A parallel agent split the working
`docs/decisions.md` into the per-session files while this session was still running and swept those
entries in under their original numbers. Re-filing them here would duplicate five entries and break
the rule that a number means one thing. For reference, they are:

| | |
|---|---|
| **27** | the portal API runs on the production SQL host, behind IIS |
| **28** | one SAN certificate on the IP:port binding — not a certificate per hostname |
| **29** | launching the portal meant releasing four months of the internal system |
| **30** | security fixes by `pnpm.overrides`, pinned inside the existing major |
| **31** | two go-live gates dropped after re-reading what they actually protected |

What follows is only what those do not contain: the skill decisions taken during this wrap-up. The
in-flight section at the end is re-verified against the live systems today and supersedes the portal
list in session 1.

---

## 85. A skill for the half that comes after the service starts

**Context.** `installing-a-windows-service` (decision 83) ends at *"start it, then read `/health`"*.
That is the right boundary for a service serving its own machine. This session took one the rest of
the way — a public hostname, TLS, a reverse proxy — and nothing in `.claude/skills/` covered any of
it. The runbook's section on it was fifteen lines of intent: *"IIS → new site, certificate, URL
Rewrite"*, which is exactly the outline that hides the three traps.

**Chosen.** A separate skill, `exposing-a-service-publicly`, with the certificate work in a sibling
`certificate-and-binding.md` because it is long and is read at a different moment — you consult it
once, before ordering, not while debugging a rule.

Its description names the failure shapes rather than the task, following the reasoning in decision
83: *"a reverse-proxy rule returns 404 or 500"*, *"a new hostname is served the wrong certificate"*.
Nobody in the middle of a 500 searches for "expose a service".

The 404-vs-500 split earns its place in the skill: **404 means the rewrite never fired** (no matching
binding, or ARR's proxy not enabled at server level) and **500 means the rule set a server variable
that is not allow-listed**. Two steps, two codes, and knowing which one you are in is most of the
work.

**Rejected: extending `installing-a-windows-service`.** They are one continuous task on the day you
do them and two different tasks every time afterwards. Installing is about *other processes on the
same box*; exposing is about IIS, http.sys and a certificate authority. Merging them would have
produced a skill whose description could not discriminate, which is the failure mode decision 83 was
careful about.

**Rejected: leaving it in `CLAUDE.md`.** The facts are there and belong there. But `CLAUDE.md` is read
to understand the repository, and this is a procedure to follow under time pressure with a public
site down. The skill links back rather than restating.

---

## 86. Three skills corrected in place, one deliberate near miss

**`installing-a-windows-service`** — its port table said `Maba.VCT.CustomerPortalApi` is *"5314 in
dev"*, which was all session 5 could see from a workstation where it is not installed. On
`MbaCustWeb` it listens on **5312**, the number the Instruction Assistant holds on the dev machine.
The same port meaning different services on different machines is worse than a collision, because
nothing conflicts and nothing errors: a **local** portal-API instance answers `/health` with a body
byte-identical to production's. Two rounds of server commands were run on a workstation before that
was noticed — they failed with `Get-WebBinding is not recognized`, the correct answer for a machine
with no IIS. Added the `hostname`-first rule and a pointer to the new skill.

Its `failure-codes.md` gained **error 1053**. A service that starts, binds its port and never signals
the SCM looks like a configuration or credential fault and is neither — the binary was built as a
console web app without `UseWindowsService`. Nothing in the logs says so.

**`merging-stale-branches`** — gained the app-repo case, where the same operation **is a production
deploy**: `main` is Vercel's Production branch, so the merge releases the whole internal system. Also
the rejected escape hatch, which is the part most likely to be re-proposed — pointing the customer
domain at a `stg` branch deployment looks like clean decoupling and would have served customers
**staging data**, because a branch build runs as `VERCEL_ENV=preview`. And a scale note: this merge
had **4 conflicting paths, not 91**, because both branches were live rather than independent imports,
so the "take the working branch's side" shortcut did not apply — one conflict was a real semantic
difference needing a decision.

**`committing-work`** — its table said the app repo's *"deployments come off `stg`"*. Corrected:
`stg` builds `stg.qcc.co.il`, but production comes off `main`. Measured — a route existing only on
`stg` went 404 → 200 on `cal.qcc.co.il` within minutes of the push.

**Rejected: rewriting any of them.** Each is working procedure earlier sessions paid for. Every change
above names the specific claim it corrects.

**Left alone deliberately:** `bringing-up-an-instrument`, `changing-a-database`,
`diagnosing-a-station`, `shipping-a-station-installer`, `verifying-ui-work`. This session touched none
of their subject matter.

`portal-data-path` was the near miss, and it is worth saying why it was left. The WebSocket toast
(below) is a portal bug and the temptation is to file it there. But that skill is about the portal's
**path to data** — deployments, the firewall, the identity chain, Priority. A component mounted too
high in the layout tree is not that, and widening a description to fit one finding is how descriptions
stop discriminating. Session 5 made the same call about MBA-946 for the same reason.

---

## In flight — re-verified 2026-09-09

Supersedes the portal list in session 1. Checked against the live systems today, not recited.

**The portal is still not live.** `portal.qcc.co.il` does not resolve — the domain was never attached
in Vercel. The API half is up and correct, re-measured today from outside the network:

```
https://portal-api.qcc.co.il/health   200  {"status":"ok","database":"configured","smtp":"configured"}
POST .../request-otp  without the key  401     <- enumeration guard holding
https://portal.qcc.co.il/                000     <- NXDOMAIN
```

**MBA-960 is the one code blocker and it is untouched.** Re-checked on `origin/stg` today:
`AppProviders.tsx` still mounts `SocketProvider` unconditionally at the root layout — zero
route/host gating. A customer on any portal screen still gets a red `destructive` toast, *"cannot
reconnect to logger"*, about 15 seconds in. No customer screen consumes the socket; all five
consumers are internal. Gate the **connection**, not the provider, or context consumers break.

**`main` is stale again already.** `stg` is **19 commits** ahead as of today, twelve days of internal
work accumulated since the 07/09 release. The next portal change repeats decision 29's problem, and
it will keep repeating until releases are cut on a cadence rather than when a portal ticket forces
one.

**The Security Group question was never answered.** Whether 1433 and 3389 are restricted to the office
or open to the internet is still unknown. IT replied that "the ports were opened"; the request was to
**restrict** them. A scan from inside the office cannot tell the two apart — both answer — so this
needs the inbound rules themselves or a scan from a foreign network. This is the only item on this
list with a security consequence.

**Two server steps were handed over as commands and never confirmed back.** Setting
`CustomerPortal__TrustedProxies__0` with a service restart — without it the rate limiter counts every
customer as one — and removing the temporary self-signed certificate with its now-redundant SNI
binding. Neither is verifiable from outside; both need one command on the box.

**`docs/PORTAL-DEPLOY-HANDOFF.md` and `scripts/Verify-PortalApi-Deploy.ps1`** were untracked for most
of this session and are the only record of what was done on the server. They have since been swept
into commits on `Eliran` by a parallel agent; confirm they are on a pushed branch before trusting
that.

**MBA-959 is a third done.** The lockfile overrides are merged (PR #116, `2e1d1cb`). `next` →
16.2.11 is not started — 26 high advisories, five of them App Router middleware bypasses, which means
the `portal.qcc.co.il` host restriction is currently defence in depth and not access control. `xlsx`
0.18.5 has **no patched release on npm at all** and needs a decision, not a bump.

**Three temporary git worktrees of the app repo** were left under the local scratch folder. One holds
a directory junction to the real `node_modules`; deleting that worktree recursively follows the
junction and destroys the working checkout's dependencies. Remove the junction with `rmdir` first.
