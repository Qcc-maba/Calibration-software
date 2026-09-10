---
name: committing-work
description: Commit and push work in the Calibration-software and app repositories. Use when landing uncommitted changes, choosing a branch to push to, deciding what must never be committed, or getting a commit past the app repo's pre-commit hook. Also use when work seems to have vanished - a staged diff that came back empty, a file changing under you, or a commit you did not make carrying your changes - because another agent session edits this tree at the same time.
---

# Committing work in these two repositories

There are two repositories with different rules. Getting this wrong puts work where nobody looks.

| | `Calibration-software` | `app/` (the web app) |
|---|---|---|
| Remote | `Qcc-maba/Calibration-software` | `Qcc-maba/app` |
| Work on | branch **`Eliran`** | a **`reference/*`** branch |
| Default branch | `master` — lags, treat `Eliran` as trunk | `main` — **and it is Vercel's Production branch** |
| Pre-commit hook | none | `pnpm install` + `lint-staged` + `tsc --noEmit` |

`app/` is its own git repository cloned inside this one. Never commit it into the parent, and never
turn it into a submodule.

**Pushing to `main` in the app repo deploys to `cal.qcc.co.il`.** `stg` builds `stg.qcc.co.il`;
production comes off `main`. Merging one into the other is a release, not a branch tidy-up — see
[merging-stale-branches](../merging-stale-branches/SKILL.md).

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

Three further symptoms of the same thing, all measured in one session:

- **A staged diff can evaporate between two commands.** `git add` on two files reported 268
  insertions; minutes later `git diff --cached` on the same paths returned *nothing*, because the
  other session had committed them in between and the index now matched HEAD. An empty staged diff
  after a successful `git add` means HEAD moved — check `git log` before re-editing anything.
- **Append; do not restructure.** An edit appended to the end of a file survived five HEAD moves in
  twenty minutes. A structural insert into the middle of the same file would have collided with
  every one of them. When a file may be held by another session, add at the end and leave reordering
  to whoever finds the file quiet.
- **The tool warning is the signal.** "the file had been modified on disk since you last read it",
  on an edit that still applied cleanly, means exactly this situation. Do not re-read and re-apply —
  confirm your own section is present by name (`grep -c`) and move on.

Two ways to be wrong about it. Reading a file once and trusting the line count later: one file went
429 → 851 → 1,019 → 1,330 lines inside a single session. And shipping a claim about a shared file
that has since stopped being true — a note added at 12:50 saying the section numbering was duplicated
was false by 12:53, because a parallel session had de-duplicated it. Re-check before you ship.

## Multi-line commit messages: the Bash tool is not PowerShell

`git commit -m @'...'@` is PowerShell here-string syntax. The Bash tool does not parse it, so the `@`
and the newline become part of the message and the subject ships as `@ docs: ...`. Use a real
heredoc — `git commit -F - <<'MSG'` — for anything multi-line. Amending an unpushed commit to fix a
mangled subject is the right call and is not the "prefer a new commit over amending" case.

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

**Dako owns the customer portal only.** Anything that is not portal work goes to Oleksandr. Tickets
for both are written in English, unlike this Hebrew-first repo.

**A `reference/*` branch is a deliverable, not a sketch.** Before pushing one, it must at minimum
pass `npx tsc --noEmit` and `npx eslint <the files you added>`, and the behaviour it claims should be
exercised against a running app. The MBA-930 attachments branch was handed over without a typecheck
and is on the in-flight list as a defect passed to someone else. Note that the repo's eslint requires
a `@returns` tag on any JSDoc block, so adding a comment to a file that previously had none can fail
a lint that passed before.

## Getting past the app repo's hook

`lint-staged` reverts the entire commit when eslint fails. Do not reach for `--no-verify` — the hook
is the only thing keeping that repository lint-clean. Run `npx eslint <the files you added>` first;
it is far faster than driving the hook. The rules that bite new files are in `app-lint-traps.md`.

## Pushing

Push only when asked. Say plainly what is still unpushed and how far ahead it is. Pushing to a
shared default branch is a separate decision from committing — ask for it.
