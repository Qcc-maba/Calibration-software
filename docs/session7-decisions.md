# Decisions, and why — session 7

Written 2026-09-09. Numbering continues from session 6 (which ends at 86), so a decision number means
one thing across the whole handoff.

**This session's product decision is already filed as 41 in `session1-decisions.md`** — the packing
barcode scan being client-side, and `ValidateMABA` being cruft to delete. It was written into the
working `docs/decisions.md` on the `Eliran` branch and a parallel agent swept it into the per-session
split under its original number while this session was still running. That is the second time this
has happened (session 6 records the same thing for decisions 27–31), and re-filing it here would
duplicate an entry and break the rule that a number means one thing.

The same is true of this session's `CLAUDE.md` additions — the VCT runtime section covering transport
discovery, the re-entrancy-guarded device tick, the model-before-manufacturer identification rule, the
WebSocket parser's unstripped closing brace, the M-142's GPIB fault and the wizard's "already
assigned" business rule. All of it is on this branch already, at `CLAUDE.md` §"VCT runtime".

What follows is only what those do not contain: the two choices taken during this wrap-up, and an
in-flight list.

---

## 87. Extend `committing-work` rather than add a concurrency skill

**Context.** The whole of this session ran alongside another agent session editing and committing the
same working tree. The evidence was concrete: `docs/decisions.md` grew 429 → 851 → 1,019 → 1,330
lines between reads; HEAD moved five times in twenty minutes; a `git add` reporting 268 insertions
was followed minutes later by an empty `git diff --cached`; and an edit to `CLAUDE.md` was swept into
commit `b40a4b2` under a message about the order-attachments service.

**Chosen — edit `committing-work/SKILL.md` in place.** It already had a section called *"Someone else
may be committing the same tree while you work"*, written from a previous occurrence, and it was
correct. What it lacked was the three symptoms above and the edit strategy that actually survives:
append at the end of a file rather than restructure its middle. Those went into the existing section.
The mangled multi-line commit message (`git commit -m @'...'@`, PowerShell here-string syntax handed
to the Bash tool, subject shipping as `@ docs: ...`) went in as its own short section.

**Rejected — a new `working-alongside-another-session` skill.** It would have duplicated an existing
section that was already right, and split one procedure across two files that both load in the same
situation. The test applied: if a reader with the existing skill loaded would already have been
warned, the material belongs in that skill, not beside it.

**Rejected — putting it in `CLAUDE.md` instead.** `CLAUDE.md` is always loaded and is already 1,120
lines. This is operational procedure for one specific task, which is what a skill is for. The one
exception is the here-string trap, which is general to any multi-line string and not specific to
committing — that also went into `CLAUDE.md`'s existing "Small mechanical traps" list, as a sibling
to the heredoc bullet already there, and is the only `CLAUDE.md` change this session made.

**Rejected — a skill for building the handover artifact.** Most of this session's wall-clock time
went into a published handover document. It is a one-off deliverable about a tool, not a repeatable
procedure in this repository, and a skill describing it would never be the right thing to load.

## 88. On `Eliran`, leave `docs/decisions.md` numerically out of order

**Context.** The `Eliran` branch still carries the monolithic `docs/decisions.md` that this branch
replaced with the per-session split. A note was added to it saying its numbering was duplicated —
two `## 9.`, two `## 13.`, two `## 14.` — which was true when written at 12:50 and false by 12:53,
because the parallel session de-duplicated it in between. What remains is that the numbers are unique
but the *sections* run 1-26 → 32-40 → 27-31 → 42-49 → 41.

**Chosen — correct the note to describe the real state, and leave the order alone.** Commit
`24f0bb3`. The operational consequence is the part that matters and it is now written down: a new
entry cannot take "the number after the last heading on the page", because the last heading is 41 and
the highest number is 49. Check the highest number in the file.

**Rejected — reordering the sections in one pass.** It is a large mechanical rewrite of a file that
another session was actively writing, and the collision risk was real and immediate rather than
theoretical. Cross-references there are by number and not by position, so reordering is safe to do
later and loses nothing by waiting for the file to be quiet.

**Note for whoever picks this up:** this applies to `Eliran` only. There is no `docs/decisions.md` on
`ai/handoff` — the per-session files are the handoff record, and they are numbered in sequence.

---

## In flight

Carried forward and re-checked today where the check was cheap. Items already re-verified in session
6's in-flight list — the portal not being live, MBA-960, `main` going stale, the Security Group
question — are not repeated here and still stand.

**The `Eliran` branch is now fully pushed — this item is closed.** It was 36 commits ahead when
measured at 15:41, which is what the standing first item had said for over a week; by 16:05 it was
`0 0` against `origin/Eliran` at `cff61eb`, pushed by the parallel session while this handoff was
being written. Recorded rather than deleted because the sequence is the point: the claim was true
when written and false twenty minutes later, in the same file that tells you to re-check before you
ship. It was caught by re-measuring on the way back to the branch, not by remembering.

**A second agent session was committing to this tree throughout, and may still be.** HEAD last moved
at 13:52 (`cff61eb`, an installer startup-timing fix) and was stable across the twenty-minute window
before this branch switch. Anything read from that tree in a future session should be re-measured
rather than recalled; two facts in this file were already stale within three minutes of being
written.

**Two of the three logger-disconnect kinds remain unfixed.** Only the communication case is handled.
The *channels* case is the dangerous one: a disconnected channel returns a sentinel that is skipped
silently in the Hydra BL, so a calibration proceeds with fewer points than the operator asked for and
nothing on screen says so. The *power* case needs re-initialisation on reconnect, which does not
exist — rediscovery cannot help because the port is still held, so nothing looks like a new device.

**`correction.log` grows without bound** and reached 53 MB on the bench machine. Nothing rotates it.

**`ValidateMABA` is documented as cruft but has not been deleted.** Decision 41 settles what should
happen; the WebSocket round trip is still in the app and still turns every correct packing scan into
`Invalid` after its ten-second timeout. The ticket was rescoped to front-end only, so the deletion is
Oleksandr's, not a C# change.

**The `Eliran` `docs/decisions.md` section order is still 1-26 → 32-40 → 27-31 → 42-49 → 41**
(decision 88). Safe to reorder when the file is quiet; nobody has.
