# Handoff — deploying the customer portal to `portal.qcc.co.il`

> **For whoever picks this up next, including another Claude session.**
> Written 02/09/2026. Everything below was verified against the live systems on that date, not
> inferred. Where something is unverified it says so.
>
> Read `docs/PORTAL-DEPLOY-RUNBOOK.md` alongside this. That is the procedure; this is the state.

---

## 1. The goal, and the one sentence that matters

Put the customer portal in front of real customers at `portal.qcc.co.il`.

**The deploy splits in two, and only half of it is blocked.**

| Half | What it is | Blocked? |
| --- | --- | --- |
| **A — the API** | `CustomerPortalApi` running on `MbaCustWeb`, reachable at `portal-api.qcc.co.il` | **No.** Can be done today. No customer sees anything. |
| **B — the domain** | Connecting `portal.qcc.co.il` in Vercel | **Yes.** Three tickets. |

Do not conflate them. Phase A is safe and reversible; phase B is what customers experience.

---

## 2. Exact state, verified 02/09/2026

### The database — NOT the blocker

All seven portal objects exist on **both** `Calibrator` (STAGE) and `CalibratorProd` (PROD):

`GetPortalCustomerIds`, `GetCustomerDeviceList`, `GetCustomerDashboardData`,
`GetCustomerPortalContactByEmail`, `CreateCustomerPortalOtp`, `VerifyCustomerPortalOtp`,
`GetCustomerSupportData`, plus the `CustomerPortalOtp` and `CustomerPortalRequest` tables.

`VerifyCustomerPortalOtp` was compared definition-to-definition across environments: **identical**.
The differing `modify_date` is deployment timing, not a version gap.

> **Trap:** `GetPortalCustomerIds` is a `SQL_INLINE_TABLE_VALUED_FUNCTION`, not a procedure. A check
> that looks for it with `type='P'` reports it missing and sends you chasing a non-problem. This
> cost time once already.

### The service — built, tested, not yet installed on the target

* Package: `C:\tmp\portal-publish-20260901-145049` — 370 files, 119 MB, **self-contained**
  (`hostfxr.dll` present, so the server needs no .NET runtime).
* `scripts/Install-CustomerPortalApi-Service.ps1` now takes `-SkipPublish -PublishDir`, so the
  production host needs neither the source tree nor the SDK.
* `scripts/Verify-PortalApi-Deploy.ps1` runs the whole of stage A in one command.

### What is NOT done

Nothing has been installed on `MbaCustWeb` yet. Phase A has not started.

---

## 3. The three gates before `portal.qcc.co.il`

| Ticket | Without it | Status 02/09 |
| --- | --- | --- |
| [MBA-937](https://calibration-maba.atlassian.net/browse/MBA-937) | **Nobody can log in.** The app never sends `X-Portal-Api-Key`; every login returns 401 | In Testing |
| [MBA-938](https://calibration-maba.atlassian.net/browse/MBA-938) | The domain also serves the internal screens — work assignment, calibration wizard, packing | In Testing |
| [MBA-946](https://calibration-maba.atlassian.net/browse/MBA-946) | A bad cookie causes a redirect loop, which reads to a customer as a broken site | In Progress |

**MBA-937 is absolute.** The service refuses to start on a public binding without a `ProxyApiKey`
(`Auth/ExposureGuard.cs`), and the key must not be left empty: `request-otp` answers differently for
a registered and an unregistered address, so an open service lets anyone walk a list of e-mails and
learn which belong to MABA customers. There is no "go live without the key" option.

### Second gate — a working portal showing wrong data

These do not break the portal; they make it lie. Decide deliberately, do not discover later.

| Ticket | What the customer sees |
| --- | --- |
| [MBA-949](https://calibration-maba.atlassian.net/browse/MBA-949) | The device list is **hardcoded mock rows**; `GetCustomerDeviceList` is never called |
| [MBA-934](https://calibration-maba.atlassian.net/browse/MBA-934) | The remaining mock data still not wired to real SPs |
| [MBA-943](https://calibration-maba.atlassian.net/browse/MBA-943) | 181 contacts see an empty portal — one address can serve several customers, the SP resolves one |
| [MBA-936](https://calibration-maba.atlassian.net/browse/MBA-936) | A contact serving several customers only ever sees one |

A portal showing a customer invented data is worse than a portal that has not launched.

The other ~35 open portal tickets are features — pagination, popups, bulk actions, search. **None
of them block.**

---

## 4. The three secrets — none of them exist yet as production values

| Value | On `MbaCustWeb` | In Vercel |
| --- | --- | --- |
| ProxyApiKey | `CustomerPortal__ProxyApiKey` | `CUSTOMER_PORTAL_API_KEY` |
| SessionSecret | `CustomerPortal__SessionSecret` | `CUSTOMER_SESSION_SECRET` |
| OtpPepper | `CustomerPortal__OtpPepper` | — server only |

Verified in `app/.env`: `CUSTOMER_SESSION_SECRET` exists but its value **differs** from the one in
`Systems/CustomerPortalApi/appsettings.Development.json` (compared by hash; neither value was
printed). Those are two independent development values. **Neither should be promoted** — generate
fresh production values.

* **ProxyApiKey and SessionSecret must be byte-identical on both sides.** A mismatched
  SessionSecret means the customer logs in and is thrown straight out with no intelligible error.
* **OtpPepper is set once, forever.** Changing it invalidates every code already mailed and unused.
* `ORDER_APPROVAL_PEPPER` in `.env.example` is a **different thing** — order approval, not OTP.
  Do not reuse it.

The database password and SMTP password come from `app/.env`
(`REMOTE_DATABASE_URL_PROD`, `SMTP_PASSWORD`).

---

## 5. Traps already hit — do not rediscover these

1. **`\\tsclient\` only exists inside the RDP session.** Running the copy commands in the local
   terminal fails with "path does not exist". Check with `hostname` — it must say `MbaCustWeb`.
   And drive redirection has to be ticked *before* connecting (Local Resources → More).
2. **The installer used to run `dotnet publish`**, requiring source and SDK on a production SQL
   host. Use `-SkipPublish -PublishDir`.
3. **`appsettings.Development.json` used to ship in the publish output** carrying five live
   secrets. Fixed in the csproj on 01/09. If you ever build a package by other means, check for it.
4. **A password was pasted into a PowerShell prompt** on 02/09 and is in `ConsoleHost_history.txt`.
   If that has not been rotated, rotate it.
5. **`sc.exe` cannot take a service password on the command line** reliably — it fails with 1639
   when the password holds a character PowerShell parses. Use `New-Service -Credential`. A domain
   account also needs "Log on as a service" or it fails to start with 1069.
6. **1433 and 3389 both answer from the MABA network.** Nobody has checked the EC2 Security Group
   to see whether those rules are IP-restricted or `0.0.0.0/0`. **Do this before go-live**, not
   after — this is the host that is about to serve customers.

---

## 6. What to do next, in order

### Phase A — today, safe

1. RDP to `51.17.121.203` with drive redirection on. Confirm `hostname` → `MbaCustWeb`.
2. Copy the package and the two scripts (see runbook §1.5).
3. Generate the three production secrets and write them down before starting.
4. Run `Install-CustomerPortalApi-Service.ps1 -SkipPublish -PublishDir C:\portal-publish -Bind any …`
5. Set `CustomerPortal__SessionSecret` and `CustomerPortal__OtpPepper` as machine variables, restart.
6. Run `Verify-PortalApi-Deploy.ps1 -ApiKey <key> -RealEmail <a real customer contact>`.
   **It must print STAGE A PASSED.** Skipped checks are not passes.
7. IIS reverse proxy for HTTPS, `TrustedProxies: ["127.0.0.1"]`, DNS for `portal-api.qcc.co.il`.
   Only 443 in the Security Group — never 5312.

### Gate

MBA-937, MBA-938 and MBA-946 closed and deployed. A decision recorded on MBA-949 and MBA-934.

### Phase B

Runbook §5 (Vercel), then test stages B and C **in full**. Exit criterion is in the runbook: stages
A–C complete, plus E2 (a junk session cookie must not produce a redirect loop).

---

## 7. Ground rules for whoever continues

* **Do not modify `app/`.** Front-end work goes to Dako or Oleksandr as a Jira ticket. The local
  checkout at `C:\tmp\maba-app` is stale — last commit 02/06/2026 — and predates the portal work
  entirely. Do not draw conclusions from it.
* **Verify against the live systems, do not infer.** Two false alarms were raised in this work by
  reasoning from names instead of querying: the TVF above, and a `modify_date` gap that turned out
  to be identical definitions. Both cost time. Query first.
* **Never print a secret**, including into a Jira comment or a terminal the user will paste back.
  Compare by hash when you need to know whether two values match.
* **A skipped check is not a passing check.** The verification script reports SKIP separately for
  exactly this reason.
