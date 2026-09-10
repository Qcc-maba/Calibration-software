---
name: exposing-a-service-publicly
description: Put one of the net10 services behind IIS on a public hostname with TLS, on a MABA server - the two modules IIS does not ship with, the forwarded headers, and the binding rule that decides which certificate to buy. Use when a service has to become reachable from the internet, when a reverse-proxy rule answers 404 or 500, or when a new hostname is served the wrong certificate.
---

# Making an internal service reachable from the internet

This picks up where [installing-a-windows-service](../installing-a-windows-service/SKILL.md) stops.
That skill ends at "start it, then read `/health`". This one is the second half: the service speaks
plain HTTP on a high port and must answer the world on 443 under its own hostname.

**Do not start until the service answers `/health` locally on the box.** Everything below assumes the
service is healthy and the only question is the path to it. Diagnosing the two at once is how a
morning goes.

## The order that works

1. **DNS** — an `A` record for the new hostname at the server's public address. Confirm the record
   before anything else; `nslookup` from a machine outside the domain, because an internal resolver
   can answer for a name the world cannot see.
2. **The two modules IIS does not ship with.** URL Rewrite **first**, then Application Request
   Routing. They are **separate downloads, not Windows features** — `Install-WindowsFeature
   Web-Scripting-Tools` does not bring them and cheerfully reports `NoChangeNeeded`. Verify with
   `Get-WebGlobalModule`; you want two rows.
3. **Enable the proxy at server level.** `system.webServer/proxy` → `enabled`. This is the step that
   gets skipped, and skipping it makes every rewritten request return a bare 404 that reads like a
   broken rule.
4. **The site**, with an SNI binding (`-SslFlags 1`) on 443 and its own host header, and an app pool
   set to **No Managed Code**. A reverse-proxy site serves no .NET of its own.
5. **The rewrite rule and the forwarded headers** — see below.
6. **`TrustedProxies`** — see below.
7. **The certificate** — [certificate-and-binding.md](certificate-and-binding.md). Read it before
   ordering anything; the binding rule decides what to buy.

## Forwarded headers: one is free, one is not

ARR sends `X-Forwarded-For` on its own. `X-Forwarded-Proto` it does not — you set it in the rule:

```xml
<serverVariables><set name="HTTP_X_FORWARDED_PROTO" value="https" /></serverVariables>
```

**A server variable must be allow-listed before a site may set it, and the list is server-scope
only.** Adding it at site scope fails with *"This configuration section cannot be used at this path…
locked at a parent level"*, which reads like a permissions problem and is not:

```powershell
& "$env:windir\system32\inetsrv\appcmd.exe" --% set config /section:system.webServer/rewrite/allowedServerVariables /+"[name='HTTP_X_FORWARDED_PROTO']" /commit:apphost
```

The `--%` is required — without it PowerShell parses `/+` and the brackets as operators. And
`appcmd`'s *"Cannot add duplicate collection entry"* is a **success from a previous run**, not a
failure.

## `TrustedProxies`, or the rate limiter collapses

`CustomerPortalApi` only calls `UseForwardedHeaders` when `CustomerPortal:TrustedProxies` is
non-empty. Leave it `[]` behind a proxy and every caller looks like `127.0.0.1`: the per-caller rate
limit then counts all customers as one, and a single active customer locks out the rest. As a
machine-scope variable — `CustomerPortal__TrustedProxies__0` — then restart the service.

This is a silent failure. Nothing logs it and `/health` stays green.

## Read the status code — it names which step you missed

| Response | What it means |
|---|---|
| **404**, generic HTTP.SYS page | No site matches the host header, or the rewrite never fired — check the binding, then that ARR's proxy is enabled |
| **500** | The rule sets a server variable that is not allow-listed. Step 5. |
| **502** | IIS is proxying and cannot reach the service. Check the service is running and on the port the rule names. |
| **200 but the wrong body** | Another site or service answered. Do not treat 200 as identity. |
| TLS error, or the wrong certificate | The certificate question, not the proxy question — see the reference file. |

## Verify from outside, and know what your test proves

A check from inside the office proves the path works **from the office**. It cannot distinguish "open
to the internet" from "restricted to our address" — both answer. When the question is a firewall or a
Security Group, only the inbound rules themselves, or a scan from a foreign network, settle it. Say
which of the two you did.

Worth confirming explicitly after any exposure work:

- the new hostname answers over HTTPS **without** `-k` / `--insecure`
- the service's own high port is **closed** from outside
- an unauthenticated call to a guarded endpoint still returns 401
- **every other site on that address still works** — the certificate is shared, see the reference file
