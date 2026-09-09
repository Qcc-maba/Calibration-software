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

## Before touching a shared default branch

Committing is one decision; changing what everyone else sees is another. Present the measurements,
say which resolution you intend, and get the go-ahead.
