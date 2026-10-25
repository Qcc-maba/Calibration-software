# Systems/CustomerPortalApi — the portal's sign-in API

Claude Code loads this file when working under `Systems/CustomerPortalApi/`. The portal's screens are
the separate `app` repo (skill **`working-on-the-app-repo`**); this service sends the one-time sign-in
code. Installing it as a Windows service is the **`installing-a-windows-service`** skill. Putting it
behind IIS on a public hostname with TLS — URL Rewrite and ARR, forwarded headers, `TrustedProxies`,
and which certificate to buy — is **`exposing-a-service-publicly`**. The identity chain and the
portal's path to its data are **`portal-data-path`**.

**The development sign-in code lives in `CustomerAuthService`.** It is gated on the Development
environment **and** a loopback caller, and it must **not** suppress sending the real mail — it did for
one session, and the only visible symptom was "the mail never arrives". Development tolerates a send
*failure*; it never skips the send.

## Running it locally

The portal's own API (`Systems/CustomerPortalApi`, net10) is what sends the sign-in code:

```powershell
dotnet run --project Systems/CustomerPortalApi --urls http://localhost:5314
```

**Port 5312 is already taken** by the installed MabaInstructionAssistant service, hence 5314. Keep
`CUSTOMER_PORTAL_API_URL` in the app's env in step with whatever port you pick, and keep
`CUSTOMER_SESSION_SECRET` identical on both sides or the session cookie the API mints is rejected by
the app without any error that says so.

## The portal's own API in production — `MbaCustWeb`

The portal is two halves on two machines. The **screens** are the Vercel app. The **one-time-code
login** is `Systems/CustomerPortalApi` (net10), installed as the Windows service
`MabaCustomerPortalApi` on **`MbaCustWeb`** — which is also the production SQL host. Putting a
public-facing role on the production database server was approved deliberately (2026-08-31); it is
not an accident to be tidied away.

**It listens on 5312 there.** That is the port the *Instruction Assistant* occupies on a development
workstation, which is why the dev instructions above say 5314 — different machines, both correct.
The overlap is not harmless: a local dev instance of this API on 5312 answers `/health` with a JSON
body identical to production's, so a health check run in the wrong window looks like proof that the
server is fine. Confirm `hostname` first.

`scripts/Install-CustomerPortalApi-Service.ps1 -SkipPublish -PublishDir <dir>` installs from bits
published elsewhere — the default path runs `dotnet publish`, which would need source and the SDK on
a production SQL box. Publish `--self-contained` so the server needs no .NET runtime either.
`scripts/Verify-PortalApi-Deploy.ps1` is the gate: it must print **STAGE A PASSED**, and a `SKIP` is
not a pass. `docs/PORTAL-DEPLOY-RUNBOOK.md` is the procedure; the rest of this section is what the
runbook did not say and what cost the most time.

**The service must be built as a Windows service host, not a console web app.** Registered with
`sc.exe` and started, a plain `WebApplication` listens but never signals the SCM, so it dies with
**error 1053** after 30s and the logs show nothing wrong. It needs
`builder.Host.UseWindowsService(...)` plus `Microsoft.Extensions.Hosting.WindowsServices`, mirroring
`Systems/InstructionAssistant`.

