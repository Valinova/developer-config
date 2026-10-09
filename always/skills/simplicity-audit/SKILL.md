---
name: simplicity-audit
description: Audits a target (PR, branch, feature, directory, or hotspot) against the smallest clear design the codebase would support today and returns a verdict, ranked findings, and a bounded first slice without modifying code. Use when the user explicitly invokes "simplicity audit" or asks for a senior-engineer design or simplicity audit of a named target. Not for diff-level cleanups (code-simplifier) or branch review (rev).
---

# Simplicity Audit

Audit only; change nothing until the user approves a slice. The engineering
principles and `instructions/testing.md` are the rubric; the target repo's own
guidance may override. This skill adds the question, the measure, and the
output shape — nothing the rubric already says.

## The question

> Knowing this codebase, what is the smallest clear design that meets the
> actual requirement today? How far is the current implementation from it,
> and does closing the gap pay back within the code's remaining life?

**The measure is concepts, not lines:** owners of each rule or mutable fact,
reachable states, independent decisions, failure paths, coordination points.
The verdict reports these counts current → proposed.

## Procedure

1. **Map.** Trace real entry points, callers, state transitions, side effects,
   and sibling paths — beyond the diff for a PR. Delegate the mapping where the
   harness supports it; judge from the brief. A broad hotspot gets mapped
   whole, then one slice is bounded for the rest of the audit.
2. **Contract.** Separate the required behavior and its invariants
   (permissions, data integrity, identity, lifecycle, concurrency, recovery,
   public contracts) from implementation choices and speculative needs.
   Existing code and tests are evidence, not justification. For a PR, mark
   each issue introduced or pre-existing.
3. **Counterfactual.** Climb the §2 decision ladder for each requirement,
   citing the similar working feature whose pattern fits. Count its concepts.
4. **Diff.** Each gap between current and counterfactual is a candidate. Ask:
   what real caller or failure makes it necessary; can the existing owner
   handle it; does the remedy reduce concepts or only move code? Complexity
   that protects a demonstrated invariant is a `keep` finding.
5. **Tests.** Apply the testing authoring gate. A test that asserts the
   contract is evidence for step 2; one that asserts internals or needs a
   production-unused seam is a finding. Name the surviving protection before
   recommending a deletion.
6. **Size.** Rank by consequence, maintenance burden, then blast radius (§8).
   Size the remedy to the code's remaining life; compare replacement with
   surgery only when evidence makes replacement plausible.

## Finding grammar

`<path>:<line>: <tag>: <what>. <evidence: caller, state, or failure>. <remedy>. <verify>.` — then **clear-cut**, **align** (needs the user's decision; give a default and the trade-off), or **keep** (name the invariant).

| Tag | Fires on |
|-----|----------|
| `second-owner:` | the same rule or fact decided in two places |
| `derived-state:` | stored data recomputable from its owner |
| `repair-cycle:` | mutate then fix up, instead of writing the right value once |
| `passthrough:` | a layer, wrapper, or orchestration step that adds no decision |
| `surface:` | config, flags, seams, or generics with no second production caller |
| `unreachable:` | recovery or compatibility paths with no reachable production state |
| `silent:` | failure swallowed or defaulted where a loud error belongs |
| `keep:` | complexity that protects a named invariant |

✅ `src/sync/service.ts:40-118: second-owner: retry policy duplicated from queue/retry.ts:12. Both callers (worker.ts:30, cron.ts:55) reach it via queue. Delete the copy; route through queue.retry. Existing queue retry tests cover both.` — clear-cut

## Report

1. **Verdict:** appropriately sized / locally overbuilt / needs architectural change, with concept counts current → proposed.
2. **Flow diagram,** current → proposed, small.
3. **Findings,** ranked, in the grammar.
4. **Tests:** retain, consolidate, move, delete, add — each with the regression it guards or the surviving protection.
5. **First slice:** the minimal plan and verification, and the `align` decisions it waits on.
6. **Inspected / unverified / residual risk.** If repo guidance encouraged the problem, propose an edit to its existing owner.

"Appropriately sized — no findings" is a first-class result. Never trade
stable identity, authorization, recovery, or honest errors for fewer concepts.
