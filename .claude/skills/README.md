# Project skills

Each subdirectory is one skill: a `SKILL.md` with `name` and `description` frontmatter, plus any
reference files it points at. The description is what decides whether a skill gets loaded, so it says
*when to use it*, not just what it covers.

| Skill | Use it when |
|---|---|
| [committing-work](committing-work/SKILL.md) | landing uncommitted changes, choosing where to push, deciding what must never be committed, or fighting the app repo's pre-commit hook |
| [diagnosing-a-station](diagnosing-a-station/SKILL.md) | a station is reported broken, blank or "no internet", or a logger stops recording, and you cannot sit at the machine |
| [merging-stale-branches](merging-stale-branches/SKILL.md) | a merge reports dozens of conflicts between branches that are really independent imports of the same code |
| [portal-data-path](portal-data-path/SKILL.md) | portal screens are empty, sign-in shows the wrong customer, mail does not arrive, or a Priority query is slow or comes back reversed |
| [shipping-a-station-installer](shipping-a-station-installer/SKILL.md) | building a new station version, or putting a build in front of an operator |
| [verifying-ui-work](verifying-ui-work/SKILL.md) | after any change to the web app's screens, routes or data wiring |

These are operational procedure. The durable facts live in `CLAUDE.md`, and the reasoning behind
each decision — including the approaches that were tried and rejected — lives in the per-session
files `docs/session<n>-decisions.md`, one per session and never appended to after the fact.
Read those first when the question is "why is it like this"; reach for a skill when the question is
"how do I do this without repeating the same day".
