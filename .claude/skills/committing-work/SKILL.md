---
name: committing-work
description: Commit and push work in the Calibration-software and app repositories. Use when landing uncommitted changes, choosing a branch to push to, deciding what must never be committed, or getting a commit past the app repo's pre-commit hook.
---

# Committing work in these two repositories

There are two repositories with different rules. Getting this wrong puts work where nobody looks.

| | `Calibration-software` | `app/` (the web app) |
|---|---|---|
| Remote | `Qcc-maba/Calibration-software` | `Qcc-maba/app` |
| Work on | branch **`Eliran`** | a **`reference/*`** branch |
| Default branch | `master` — lags, treat `Eliran` as trunk | `main`; deployments come off `stg` |
| Pre-commit hook | none | `pnpm install` + `lint-staged` + `tsc --noEmit` |

`app/` is its own git repository cloned inside this one. Never commit it into the parent, and never
turn it into a submodule.

## Before you commit anything

1. `git status --porcelain` — the real list. VS Code's count expands directories and lies.
2. For every **new** file, ask what it is. Build output, runtime state and anything holding a
   credential is ignored, not committed. See `never-commit.md` in this skill directory.
3. Scan what you are about to stage for credentials:
   ```
   grep -rniE "password *[=:]|pwd=|apikey|token *[=:]" <paths> | grep -viE "<|\\$|Read-Host|env:"
   ```
4. **Validate config files by parsing them, not by reading them.** A duplicate key or a bad escape
   in an `appsettings.json` stops the service during configuration load, before any logging exists —
   the only symptom is a service that will not start.

## Uncommitted code is not finished code, and a shipped binary must come from the branch

Two things went wrong this way in one session, and both are cheap to prevent:

- Server code written in an earlier session was left uncommitted and **had never once been
  compiled**. It carried a syntax error (`CS0579`, a doc comment inserted between another method's
  attribute and its signature) that sat there for two days. If you write code you are not building,
  say so in those words — "written, never compiled" — and do not describe it as done.
- A Release build for an installer pulled in four *other* uncommitted files, so the artifact handed
  to an operator could not be rebuilt from any branch. After building anything you intend to give
  away, run `git status --porcelain` over the source it consumed and commit what it used.

## Check the numbers, not the file, after a whole-file rewrite

This repository lives in OneDrive, which can hand you a **stale, shorter copy** of a file you are
editing. A merge was built on a 219-line copy of `docs/decisions.md` whose real length was 1,331
lines. What caught it was `git diff --cached --numstat`: an edit that only adds must report **0
deletions**. `wc -l` will happily confirm the wrong number; the staged diff will not.

## Someone else may be committing the same tree while you work

This repository is edited by more than one agent session at a time. Staged work has been swept into
another session's commit, under a message about something else entirely — the files were correct, but
no commit in the log describes them, and `git status` came back clean before the commit was made.

Before reporting "committed", check `git log -3` and confirm a commit you recognise carries the work.
If it was swept in, say so and name the commits that carry it rather than claiming the commit as
yours. If you must be sure the work lands under its own message, commit it before starting the next
file rather than staging everything and committing at the end.

## Grouping

Group by intent, not by directory. A session that touched thirty files produces five or six commits.
Each message says **why**, with the measured numbers that justify it — not a restatement of the diff.
A single "wip" commit over the whole tree is not acceptable here.

End every commit message with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

## Front-end work goes to Dako

Changes under `app/` reach Dako as a Jira US plus a **`reference/*`** branch — never a `feature/*`
branch that someone could merge by mistake. Name the branch after **what is in it**, not after the
local branch it was committed on. Do not update a `reference/*` branch that has already been handed
over; make a new one.

## Getting past the app repo's hook

`lint-staged` reverts the entire commit when eslint fails. Do not reach for `--no-verify` — the hook
is the only thing keeping that repository lint-clean. Run `npx eslint <the files you added>` first;
it is far faster than driving the hook. The rules that bite new files are in `app-lint-traps.md`.

## Pushing

Push only when asked. Say plainly what is still unpushed and how far ahead it is. Pushing to a
shared default branch is a separate decision from committing — ask for it.
