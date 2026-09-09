---
name: portal-data-path
description: Diagnose and change the customer portal's path to data - Vercel deployments, the SQL firewall, the e-mail identity chain, and reading Priority through the linked server. Use when portal screens are empty, sign-in shows the wrong customer, mail does not arrive, or a Priority query is slow or returns reversed text.
---

# The customer portal's path to its data

Two Vercel deployments: **`cal.qcc.co.il`** (prod, `CalibratorProd`) and **`stg.qcc.co.il`**
(staging, `Calibrator`). The screens are the Next.js app; the sign-in code is the separate net10
`Systems/CustomerPortalApi`.

## The functions do not run in the office

`X-Vercel-Id: fra1::iad1::…` reads *PoP that received the request* :: *region that executed it*.
`iad1` is **AWS us-east-1**, so the connection to SQL on 1433 leaves from Virginia. Any firewall or
Security-Group rule that allow-lists "our" addresses kills both sites while everything still looks
healthy from inside the office. That is exactly what happened on 2026-09-08.

## Diagnose in ten seconds, before touching code

```
curl https://stg.qcc.co.il/api/health/db
```

`/api/health/db` runs `SELECT 1` and returns `{database, ms, name, code}` — never the driver message,
never the connection string, because it is public. Read the **shape** of the failure:

| Symptom | Meaning |
|---|---|
| `{"database":"ok"}` under a second | the path is open — look at the code |
| timeout at almost exactly **10.0s** | Prisma's connect timeout: packets dropped — firewall / Security Group |
| immediate refusal | service down, or port closed at the OS |
| fast rejection | credentials |

Ten seconds of silence is never a wrong password; a wrong password is refused instantly. Vercel's
runtime logs are confirmation, not diagnosis — nobody without a Vercel login can run them, and the
health URL is what IT can be handed to verify a fix themselves.

Asking for firewall access: request **one `/32`** (via Vercel Secure Compute, a static egress IP).
Do not propose allow-listing "the Vercel ranges" — us-east-1 is hundreds of CIDR blocks against a
default 60-rule quota. `docs/IT-REQUEST-sql-firewall.md` is the written request.

## A login is an e-mail, and an e-mail is not one customer

Three procedures, in order:

1. `dbo.GetPortalCustomerIds` — every customer the address is a contact of. When it is attached to
   several, **the customer that actually has devices wins**. A contact left on a dead customer record
   was signing a real person into an empty portal under the wrong company name.
2. `dbo.CreateCustomerPortalOtp` — issues the code. Rate limit **5 per 900s**; a repeated test loop
   trips it and the screen then blames mail for something that is not mail.
3. `dbo.GetCustomerPortalContactByEmail` — the session's contact, and the name the mail is addressed to.

The development sign-in code is gated on the Development environment **and** a loopback caller. It
must **not** suppress sending the real mail — it did for a day, and the only symptom was "the mail
never arrives". Development tolerates a send *failure*; it never skips the send.

## Priority is read-only, and nothing is ever deleted

A contact that disappears from Priority is marked **inactive**, never removed.
`PHONEBOOK.INACTIVE` → `CustomerContacts.IsActive` through `stg.LoadCustomerContactsFromPriority` →
`stg.MergeCustomersContactsData`, and the portal procedures filter on it. Deleting rows to make a
screen behave is not an option, in either direction. The user's rule, verbatim:
*"שיביא אותם במצב INACTIVE זה בסדר. אסור להמחק מהפריוריטי."*

## Reading Priority through the linked server

- **Push the whole statement into `OPENQUERY`.** A join written with four-part names issues one
  remote call per row: 65 seconds for 1,361 invoices, versus 0.7–0.8s for the identical join inside
  `OPENQUERY`.
- **`dbo.fnUnreverseVisualText` is for display text, not identifiers.** Priority stores Hebrew in
  visual order, so names must be un-reversed — but running it over a *path* reverses the ASCII path
  too and nothing opens. Return the ASCII **directory** and pick the file inside it by size.
- Cross-server joins need an explicit **`COLLATE Hebrew_BIN`**, or they fail with
  `Cannot resolve the collation conflict between Latin1_General_100_CI_AI_SC and Hebrew_BIN`.
- Invoice numbers starting with **`K`** are receipts (קבלה) and correctly have no document. The type
  comes from `IVTYPES.IVDES`; `OTYPE = 'C'` filters to the customer side.
- Only a minority of invoices have an attachment at all — 156 of 1,361 for the customer this was
  built against. "No document" is usually the truth.

## Deploy to both, or say you did not

STAGE-only procedures are this codebase's most common "works here, missing there" bug.
`database/Compare-Schema.ps1` shows the drift. Address rows by their Priority key
(`CustomerIdFromSource` = `CUST`), never by an identity column — those differ between STAGE and PROD.
