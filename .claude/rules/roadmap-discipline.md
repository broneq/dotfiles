---
description: How to keep docs/ROADMAP.md honest - checkbox semantics, current-state corrections, decisions log
paths:
  - "docs/ROADMAP.md"
---

# Keeping the roadmap honest

`docs/ROADMAP.md` is the working state of this project, not a proposal written
once. Every change to the repository updates it in the **same commit** as the work.

There is no status tracking anywhere else. One file, one truth.

## Checkbox semantics

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done.

1. **Tick a checkbox only after its verification passed.** `[x]` means the phase's
   "Done when" criterion was actually run and observed, not that the code was
   written. Use `[~]` for started-but-unverified. A plan that claims more than the
   repository delivers is worse than no plan.
2. **Never mark a phase complete while any of its boxes are open.**

## Current state

"Current state" is a factual survey with real sizes, paths and counts, not a
description of what the repository intends.

3. **Correct it when you learn it is wrong.** Stale facts there cause bad
   decisions three phases later. Say plainly in the commit message that a fact was
   corrected, and what the new value is.

A fact belongs in exactly one place. If a number appears both here and in
`CLAUDE.md`, delete it from `CLAUDE.md` and leave the pointer.

## Decisions and open questions

4. **Append to the decisions log whenever a choice is made**, including choices to
   say no, and record the rationale, not just the outcome.
5. **Move an item from "Open questions" to the decisions log when it is settled**,
   rather than deleting it. The trail is the point.
