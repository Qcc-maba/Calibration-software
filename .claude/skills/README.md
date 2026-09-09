# Project skills

Each subdirectory is one skill: a `SKILL.md` with `name` and `description` frontmatter, plus any
reference files it points at. The description is what decides whether a skill gets loaded, so it says
*when to use it*, not just what it covers.

| Skill | Use it when |
|---|---|
| [bringing-up-an-instrument](bringing-up-an-instrument/SKILL.md) | adding or verifying an instrument on the VCT server, or one that is connected but not identified, returns corrupted replies, or measures nothing |
| [changing-a-database](changing-a-database/SKILL.md) | a task needs a schema change, a new stored procedure or a one-off data fix on Calibrator/CalibratorProd |
| [committing-work](committing-work/SKILL.md) | landing uncommitted changes, choosing where to push, deciding what must never be committed, fighting the app repo's pre-commit hook, or work that seems to have vanished because another session is committing the same tree |
| [diagnosing-a-station](diagnosing-a-station/SKILL.md) | a station is reported broken, blank or "no internet", or a logger stops recording, and you cannot sit at the machine |
| [exposing-a-service-publicly](exposing-a-service-publicly/SKILL.md) | a service has to answer a public hostname over TLS, a reverse-proxy rule returns 404 or 500, or a new hostname is served the wrong certificate |
| [installing-a-windows-service](installing-a-windows-service/SKILL.md) | installing, moving or re-pointing one of the net10 services on a MABA server, or one starts and answers nothing, or installing one appears to break an unrelated project |
| [merging-stale-branches](merging-stale-branches/SKILL.md) | a merge reports dozens of conflicts between branches that are really independent imports of the same code |
| [portal-data-path](portal-data-path/SKILL.md) | portal screens are empty, sign-in shows the wrong customer, mail does not arrive, or a Priority query is slow or comes back reversed |
| [shipping-a-station-installer](shipping-a-station-installer/SKILL.md) | building a new station version, or putting a build in front of an operator |
| [verifying-ui-work](verifying-ui-work/SKILL.md) | after any change to the web app's screens, routes or data wiring |

These are operational procedure. The durable facts live in `CLAUDE.md`, and the reasoning behind
each decision — including the approaches that were tried and rejected — lives in the per-session
files `docs/session<n>-decisions.md`, one per session and never appended to after the fact.
Read those first when the question is "why is it like this"; reach for a skill when the question is
"how do I do this without repeating the same day".
