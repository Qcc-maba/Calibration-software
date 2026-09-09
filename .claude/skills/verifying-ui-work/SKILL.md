---
name: verifying-ui-work
description: Verify a change to the web app actually works before reporting it done - the npm run verify suite, walking every tab and dialog, and the false signals that make a working screen look broken or a broken one look fine. Use after any change to app/ screens, routes or data wiring.
---

# Verifying UI work before saying it is done

Screens were repeatedly reported as fixed and were not, and a dead dev server was repeatedly
misdiagnosed as a broken screen. The user's standing instruction: run a full check after **every**
task, covering both the code and the UI, and open **every tab and every popup** — a screen that loads
is not a screen that works.

## The suite

From the app checkout (outside OneDrive — Turbopack cannot resolve the pnpm symlinks there):

```
npm run verify
```

`scripts/verify.mjs`, roughly 37 checks in four sections:

| Section | What it proves |
|---|---|
| code | `tsc`, `eslint`, `vitest` |
| sources | no mock module imported by a customer screen, no hardcoded clock |
| http | every route answers, `/api/trpc` compiles |
| browser | signs in, walks every screen, every tab and every dialog; fails on placeholder text or a console error |

It reports **"the dev server stopped answering"** separately from "this screen is broken". Believe
that distinction — it exists because a dead dev server was blamed on screens more than once. A step
that cannot run reports instead of throwing, so one flaky interaction does not hide the other checks.

## False signals, in both directions

- **A screen's `innerText` says nothing about a form.** Inputs carry their content in `.value`. A
  profile screen that read as completely empty was fully populated.
- **A new route file 404s until the dev server restarts.** `/customer` and `/api/health/db` each
  "did not work" for this reason alone.
- **`loggerLink` logs only in dev, or when the result is an `Error`.** In production a tRPC failure
  reaches the browser as a bare 500 with the stack stripped — which is why `/api/health/db` exists.
- **A Playwright page in a fresh context has no session cookie**, and a dialog left open makes the
  body inert. Both produce "sign-out is broken" reports that are the harness, not the app.
- **Playwright's browsers**: the machine-level `PLAYWRIGHT_BROWSERS_PATH` points at a different
  build. Point it at the per-user `ms-playwright` cache or you get "Executable doesn't exist". Never
  set that variable machine-wide to fix one service — every Playwright on the box reads it.
- **`HTTP 200` on port 3000 proves nothing on a dev machine**: a `next dev` server answers on the
  same port. A dev build's HTML references `[turbopack]…hmr-client` chunks; a production one does not.
- **OTP rate limit (5 per 900s)** makes a repeated suite run fail with "שליחת הקוד נכשלה" for reasons
  that have nothing to do with the change under test.

When the dev server dies mid-run (Turbopack cache, memory), delete `.next` and start it **detached** —
a server started from a tool call dies with the call.

## No mocks behind a flag

Four mock modules were deleted outright rather than kept behind a switch. A mock that can be imported
eventually is, and a screen full of plausible fake data reads as working. A field with no schema
source renders an explicit empty state; it is never wired to something plausible.

## Reporting

Report what the run actually said. If a check failed, say so and paste the output; if a step was
skipped, say that. "Verified" means the suite passed, not that the page rendered once.
