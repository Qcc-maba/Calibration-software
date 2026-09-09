---
name: installing-a-windows-service
description: Install or repair one of the net10 services (InstructionAssistant, CustomerPortalApi, OrderAttachments) as a Windows Service on the MABA servers - how to configure it without breaking the services beside it, and the four failures that each look like something else. Use when installing, moving or re-pointing one of these services, when one starts and then answers nothing, or when installing one appears to break an unrelated project.
---

# Installing a net10 service on these machines

Three of these run **on the same box**. That single fact causes the worst class of bug in this
repository: a service that works perfectly until another one is installed, then breaks the *other*
one, silently, at a distance. Everything below exists because that happened twice.

## The rule: one service, one configuration key

**A setting that configures one service must not be reachable by another.** If the only way to set it
is a machine-wide environment variable, set it in-process instead — in `Program.cs`, before the host
is built.

Two variables have already done this damage, and neither failure names the service that caused it:

| Variable | Read by | What it did |
|---|---|---|
| `ASPNETCORE_URLS` | every ASP.NET process on the box | Each installer set it, so whichever ran last repointed the other service. Two ended up on 5312; one won the port and answered `/health` for requests meant for the other, which was crash-looping on `address already in use`. |
| `PLAYWRIGHT_BROWSERS_PATH` | every Playwright on the box | Set machine-wide so a service account could find Chromium, it also redirected the *frontend's* Playwright — a different project, a different pinned build — which then could not launch at all. |

A health check that passes because the **wrong service answered it** is the reason this rule is
absolute rather than a preference. Port discipline is not the fix: agreeing who owns which port does
not help when the mechanism lets either installer overwrite the other's setting.

## Current allocation — verify it, do not trust it

| Service | Port | Reads its URL from |
|---|---|---|
| `MabaInstructionAssistant` | 5312 *on the dev workstation* | its own key |
| `MabaOrderAttachments` | 5313 | `OrderAttachments__Urls` |
| `MabaCustomerPortalApi` | **5312 on `MbaCustWeb`**, 5314 in dev | its own key |

**The same number means different services on different machines**, which is worse than a collision
because nothing conflicts and nothing errors. On the dev workstation 5312 is the Instruction
Assistant; on `MbaCustWeb` it is the portal API, and the Instruction Assistant is not installed there.

That produced the trap worth remembering: a **local** portal-API instance on 5312 answers `/health`
with a body **byte-identical** to production's, so a health check run in the wrong window is
indistinguishable from proof that the server is fine. Two full rounds of server commands were run on
a workstation before anyone noticed — they failed with `Get-WebBinding is not recognized`, the correct
answer for a machine with no IIS. Run `hostname` first, every time, and believe it over the prompt.

```powershell
Get-NetTCPConnection -State Listen -OwningProcess <pid>
```

Check with that, not with a source comment. The header comment in `Systems/OrderAttachments/Program.cs`
names CustomerPortalApi as the service it collided with on 5312; the port is the Instruction
Assistant's. A comment written during an outage records what someone believed at the time.

## Order of work

1. Pick a free port and give the service **its own** configuration key for it.
2. Set every secret at **`Machine`** scope. A `LocalSystem` service does not read a user-scope
   variable, and the symptom is a null connection string at startup — not a permission error.
3. Grant the account **"Log on as a service"** (`SeServiceLogonRight`, via `secedit`) *before*
   creating the service.
4. Create it with `New-Service -Credential`.
5. Start it, then read `/health` — not the service status. `Running` only means the process did not
   exit.

`scripts/Install-OrderAttachments-Service.ps1` is the reference implementation; it does all five and
reads its connection string from the app's env file rather than taking one on the command line.

## A health endpoint reports what it can reach, not that it started

Every field on `/health` is something that has silently broken a service here: an account that cannot
see a share, a browser installed under a developer's profile, a missing connection string, an
unwritable cache directory. Report each one, and report the **identity the service is running as** —
that is the field that explains most of the others.

`libreOfficeInstalled: false` on the attachments service is the current live example: the service is
up, healthy and converting everything except Office documents, which fail with a 422.

## The four failures and what they actually mean

See [failure-codes.md](failure-codes.md). Each of them was diagnosed as something else first.

## Handing commands to someone else

`\\tsclient\...` exists **only inside an RDP session**. A command that uses it, handed to someone to
"run on the server", fails on their own machine with a path error that looks like a permissions
problem. Use a UNC path to a real share, or copy through one.

**Hand a multi-step block over as something that cannot be half-run.** Never leave a `<PLACEHOLDER>`
inside a block whose later lines are destructive — one beginning `$new = '<THUMBPRINT>'` was pasted
verbatim, the `netsh … delete` succeeded and the `add` did not, and a public site served no TLS until
the real value arrived. Derive the value inside the block instead, so there is nothing left to
substitute by hand.

## Once it is healthy, if it has to face the internet

Stop here if the service only serves the machine or the LAN. If it must answer a public hostname over
TLS, that is a separate procedure with its own failure modes —
[exposing-a-service-publicly](../exposing-a-service-publicly/SKILL.md). Do not begin it until
`/health` passes locally: diagnosing the service and the path to it at the same time is how a morning
disappears.
