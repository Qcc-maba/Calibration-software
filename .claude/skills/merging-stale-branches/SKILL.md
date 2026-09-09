---
name: merging-stale-branches
description: Merge a long-diverged branch into a default branch that has gone stale. Use when a merge reports dozens of conflicts between two branches that are really independent imports of the same code, or when asked to bring master/main level with the branch where the work actually happens.
---

# Merging into a branch that stopped moving

`master` here sat untouched from 2025-04-07 while `Eliran` accumulated 186 commits. A branch that
stale is usually not "behind" in the ordinary sense — it is a **different import of the same code**,
so an ordinary merge reports conflicts in files nobody has edited in years. On this repository that
was **91 conflicting paths**.

Resolving those one by one is the wrong instinct. Measure first, then decide once.

## Measure before you merge

```bash
# how far apart, in commits
git rev-list --left-right --count origin/master...origin/Eliran

# what the merge would actually do, without touching anything
git merge-tree --write-tree --messages origin/master origin/Eliran > /tmp/mt.txt; echo $?
awk 'NR>1 && NF>=4 {print $NF}' /tmp/mt.txt | sort -u | wc -l    # conflicting paths

# what the stale branch has that the working branch does not
comm -13 <(git ls-tree -r --name-only origin/Eliran | sort) \
         <(git ls-tree -r --name-only origin/master | sort)
```

Then group that last list by top-level directory and **check whether each one was relocated rather
than lost**. On this repo every legacy tool that appeared "only on master" (`Try`, `Convert`,
`Convertor`, `DeviationCalculation`, `MasterCalibration`, `Modbus`, `CSV writer`, `XML Convert`,
`SaveDeviationValuesForMaster`, `VpnConsoleApp`) was sitting on `Eliran` under `archive/`. The rest
were systems deliberately deleted — `XCI-Group`, `VCT.DIGI`, `AccountSystem`, `OnlineSystem`,
`MultiFrameSystem`, `CommonWebAPI`, `DigiMonitor`.

If the working branch turns out to be a **superset**, the merge has exactly one correct resolution
and it is not per-file.

## Take the whole tree, keep both histories

Build the merge commit with plumbing. Nothing is checked out, the working tree never moves, and no
900-file churn hits OneDrive:

```bash
TREE=$(git rev-parse origin/Eliran^{tree})
COMMIT=$(git commit-tree "$TREE" -p origin/master -p origin/Eliran -m "…why…")
```

Verify the commit **before** pushing:

```bash
git diff --stat "$COMMIT" origin/Eliran          # empty = tree identical
git merge-base --is-ancestor origin/master "$COMMIT" && echo fast-forward-safe
git ls-tree -r --name-only "$COMMIT" -- Systems/XCI-Group | wc -l   # 0 = stayed deleted
git push origin "$COMMIT":refs/heads/master
```

The push is a fast-forward, so no force and no rewritten history. Afterwards update the local ref
(`git update-ref refs/heads/master <commit>`) or just fetch — the local branch is otherwise left
behind and looks alarming in the editor.

## What not to do

- **Do not resolve the conflicts individually.** Hours of work whose only correct answer is "take the
  working branch's side", and every slip resurrects a directory that was deliberately deleted.
- **Do not `push --force`.** Same resulting tree, but it discards the stale branch's commits and moves
  the base of every branch cut from it.
- **Do not `-X ours` / `-X theirs` blind.** They resolve *conflicting hunks*, not whole-file adds and
  deletes, so the result is neither branch's tree.
- Repointing the GitHub default branch instead is cheap but leaves the repository confusing forever.

## In the app repo, this merge is a production deploy

The same operation in `app/` is not a tidy-up. **Vercel's Production branch there is `main`**, so the
merge *is* the release — the moment it lands, `cal.qcc.co.il` rebuilds from it. Verified: a route
that existed only on `stg` went 404 → 200 on the production host within minutes of the push.

Measured on 2026-09-07: `main` was **205 commits and 639 files** behind `stg`, its previous commit
from 10/08. So there was no way to ship one portal fix without shipping four months of
calibration-wizard, coordinator-orders and packing work in the same minute. Say that out loud before
pushing — "this is a release of the whole internal system", not "I merged a branch" — and have
someone ready to smoke-test the internal screens afterwards.

The stale-branch heuristic above still held, and the scale was different from the `master`/`Eliran`
case: **4 conflicting paths, not 91**, because both branches were live rather than independent
imports. Three resolved to `stg` mechanically; one was a genuine semantic difference (which source
column a field maps to) and needed a decision rather than a side. When the conflict count is small,
read each one — the "take the working branch's side" shortcut is for the 91-path shape.

**Rejected: pointing the customer domain at a `stg` branch deployment** to decouple the two releases.
It looks like the clean answer and it is a trap: a branch build runs as `VERCEL_ENV=preview`, which
`env.js` resolves to `REMOTE_DATABASE_URL_STAGE`, so the site would have served customers **staging
data**. Check what environment a deployment reports before treating it as production-equivalent.

**Rejected: cherry-picking the portal commits onto `main`.** The portal work sits on shared
`src/server` and `src/lib` changes; the subset does not stand alone.

One more thing that surprised: GitHub printed `Changes must be made through a pull request` and the
push **succeeded anyway** — an admin bypass. A protection warning is not proof the protection held;
read the ref-update line.

## Before touching a shared default branch

Committing is one decision; changing what everyone else sees is another. Present the measurements,
say which resolution you intend, and get the go-ahead.
