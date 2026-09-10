# The certificate, and the binding rule that decides which one to buy

Read this before ordering a certificate. The rule below is why the obvious purchase is the wrong one.

## An IP:port binding beats SNI, so one certificate serves every name on the address

Measured on a server already hosting the company site, after adding a correctly-formed SNI binding
for a new hostname that was then never once presented:

```
netsh http show sslcert
  IP:port        <private-ip>:443          -> cert A     (the existing site's certificate)
  Hostname:port  <new-host>:443            -> cert B     (added for the new service)

openssl s_client -servername <new-host>    ->  cert A
openssl s_client -servername <existing>    ->  cert A
```

Confirmed by fingerprint, twice, and by the fact that the new hostname kept working over `-k` while
presenting the wrong name. **http.sys resolves an exact `IP:port` binding before it consults a
hostname (SNI) binding**, so while one exists on that address it answers for every name on it.

Two consequences, and both cost money or downtime if missed:

- **A per-hostname certificate bound by SNI will never be served.** It is bought, installed, and
  inert. This is the single most expensive thing on this page.
- **Whatever is bound to that `IP:port` must cover every hostname on it.** Binding a certificate that
  covers only the new service takes the existing site down for everyone.

So: **one certificate whose SAN lists every hostname on the address, bound to the `IP:port`.**

The alternative — deleting the `IP:port` binding and giving every host its own SNI binding — is the
better long-term shape and stays available. It was rejected here only because it means changing a
live binding on the company's public site during a launch, and the SAN reissue reached the same place
with no exposure.

## Getting the certificate

A **reissue** of the existing certificate with the new name added to its SAN is usually free, keeps
the expiry, and needs no new domain validation when the new name is a subdomain of one already
validated. That makes it same-day, which a new order is not.

1. **Generate the CSR on the server** (`certreq -new` with an `.inf` that lists every name in
   `2.5.29.17`). The private key then never travels. Read the existing certificate's subject first
   and match it — a DV certificate has only a CN, and inventing organisation fields triggers
   re-validation.
2. **Hand out the CSR, not a key.** A CSR is public and safe to e-mail. Whoever holds the CA account
   pastes it into the reissue form, confirms **all** the names appear, and returns the signed
   `.crt` — no PFX, no key material in either direction.
3. **Verify the SAN before installing.** `certutil -dump <file> | Select-String 'DNS Name'` must list
   every hostname. If the new one is missing, stop — installing it swaps one working certificate for
   another working certificate that still does not serve the new host.
4. `certreq -accept` the signed file, then confirm **`HasPrivateKey` is `True`**. If it is false the
   accept did not match a pending request, and binding it would break TLS for everything on the
   address.

## The rebind is the only moment the site is down

`netsh http delete sslcert` succeeds on its own, so a failure on the `add` that follows leaves the
address with **no certificate at all** — every site on it stops serving TLS.

```
netsh http delete sslcert ipport=<ip>:443
netsh http add    sslcert ipport=<ip>:443 certhash=<new-hash> appid='{<guid>}' certstorename=MY
```

- **Write the rollback out before you start** — the same `add` with the *old* hash and its original
  store name. Note the store: a certificate installed by `certreq -accept` lands in `MY`, while an
  existing one may be in `WebHosting`, and the wrong `certstorename` fails.
- **Never leave a placeholder inside that block.** A block beginning `$new = '<THUMBPRINT>'` was
  pasted verbatim; the `delete` succeeded, the `add` failed with *"The parameter is incorrect"*, and
  the company site served no TLS until the real hash was supplied. Derive the value in the block
  instead:

  ```powershell
  $new = (Get-ChildItem Cert:\LocalMachine\My | Where-Object SerialNumber -eq '<serial>').Thumbprint
  ```

- **Do not delete the old certificate from the store** until the new one is verified from outside. It
  is the rollback.

## Verifying, and cleaning up

Check every hostname on the address, not just the new one, and compare fingerprints — they should all
be the same certificate now:

```
openssl s_client -connect <ip>:443 -servername <each-host> | openssl x509 -noout -fingerprint -sha1
```

Then the new hostname must answer over HTTPS **without** `-k`, and every pre-existing site must still
return what it returned before.

Afterwards, remove any temporary self-signed certificate and its SNI binding. They are proven inert
by the rule at the top of this page, but leaving a certificate named after a production hostname in
the store is exactly what confuses the next person.
