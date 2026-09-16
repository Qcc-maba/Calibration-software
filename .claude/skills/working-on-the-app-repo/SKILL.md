---
name: working-on-the-app-repo
description: Work on the web app and customer portal, which live in the separate Qcc-maba/app repository - where it is checked out, its stg and main branches and why merging them is a release, its commands, running the portal's sign-in API beside it, and the Next.js traps specific to it. Use when a task touches the app repo, a portal or internal screen, Next.js, tRPC, Vercel, or the stg/main branches.
---

# Working on the app repository

The web app **and** the customer portal are one Next.js App Router + tRPC + Prisma application over
SQL Server, in their **own** git repository, `Qcc-maba/app`. It is not part of `Calibration-software`
and not a submodule of it.

## Where it is

On the current workstation it is cloned **beside** this repo, as `GIT_ROOT\app`. If it is ever cloned
inside `Calibration-software`, `/app/` is gitignored there so it is not committed into the parent —
never commit it into the parent and never turn it into a submodule.

**It will not run from inside OneDrive** — Turbopack cannot resolve the pnpm symlinks there — so the
working copy must live in a plain local folder. Every command below is run in that checkout.

A nested `CLAUDE.md` in `Calibration-software` never loads for work in this repo, which is why this
knowledge is a skill.

## Branches, and why merging them is a release

The working branch is **`stg`**, which builds `stg.qcc.co.il`. **`main`** is Vercel's Production
branch and what `cal.qcc.co.il` deploys. (`origin/HEAD` points at `main` — there is no `master` in
that repo.)

**`main` lags `stg` by months, and that makes every release an all-or-nothing one.** Merging `stg` →
`main` ships everything on `stg` at once — it is a release of the whole internal system, not a
portal deploy, and it should be announced as one. Attaching a customer domain to a *branch*
deployment is not an escape hatch: a branch build is `VERCEL_ENV=preview`, which `env.js` resolves to
`REMOTE_DATABASE_URL_STAGE`, so the portal would serve customers STAGE data.

The **`merging-stale-branches`** skill has the measured history, how that merge was done, and the
rejected alternatives. When resolving its conflicts, read `src/env.js` before taking a side: the
database-URL resolution was identical on both sides and the conflict there was whitespace only.

## Commands

```powershell
npm run dev            # Next dev server on http://localhost:3000
npm run verify         # the regression suite - run this after every task
npm run build          # production build
```

`npm run verify` is the "did I break anything" gate. What it checks, the false signals in both
directions, and how to read a failure are the **`verifying-ui-work`** skill — run it after every
change.

## The portal's sign-in API, beside it

The one-time sign-in code is sent by `Systems/CustomerPortalApi` (net10) in `Calibration-software`,
not by this app. Locally:

```powershell
dotnet run --project Systems/CustomerPortalApi --urls http://localhost:5314
```

**Port 5312 is already taken** by the installed MabaInstructionAssistant service, hence 5314. Keep
`CUSTOMER_PORTAL_API_URL` in the app's env in step with whatever port you pick, and keep
`CUSTOMER_SESSION_SECRET` identical on both sides or the session cookie the API mints is rejected by
the app without any error that says so.

Where the functions run, the SQL firewall, the e-mail identity chain and reading Priority through the
linked server are the **`portal-data-path`** skill.

## Traps specific to this app

- **The root error boundaries answer for both audiences.** A URL matching no route reaches the
  **root** `app/not-found.tsx`, never a segment-level one. Because that root boundary answers for
  **both audiences**, anything rendered there has to read the `host` to know whether it is talking to
  a customer or to a coordinator. `cal.qcc.co.il` showing "back to portal" walks an internal user out
  of the system they were using.
- **Playwright is borrowed, not installed here.** On the machine this was first written on it came
  from a sibling `maba2000-web/frontend` checkout, which does not exist on every machine — check before
  relying on it. The machine-level `PLAYWRIGHT_BROWSERS_PATH` there pointed at a *different* build:
  point it at the per-user `ms-playwright` cache or you get "Executable doesn't exist".
- The pre-commit hook and the lint rules that reject new files are in the **`committing-work`** skill
  and its `app-lint-traps.md`.

## Who owns the work

Front-end work in this repo normally belongs to **Dako**, and is handed over as a Jira US plus a
`reference/*` branch — never a `feature/*` branch that could be merged by mistake. When you are asked
for a direct fix instead, treat that as covering that request, not as a standing licence. **Dako owns the
customer portal only**: "Dako אחראית רק על פורטל הלקוחות. אם זה לא קשור לפורטל תעביר לאולקסנדר."
Anything that is not portal work is routed to **Oleksandr**. Tickets for both are written in English,
unlike the Hebrew-first `Calibration-software`. The **`committing-work`** skill has what a
`reference/*` branch must pass before it is handed over.
