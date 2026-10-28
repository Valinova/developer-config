# Testing

Owns how tests are chosen, written, reviewed, and pruned in every repo;
`principles.md` §4 carries the always-loaded core and points here. Read this
file before writing, changing, reviewing, or deleting tests. Project-level
`AGENTS.md` / `CLAUDE.md` may name the repo's boundary harness and fixtures.
(why: rationale.md#test-strategy)

## PR proof and regression scenarios

Every delivery proves the two claims of `principles.md` §4 "Ship gate": the
benefit, and that the regression surfaces its plan named hold. Proof exercises the
goal through every owner and head the change touches (UI, assistant, MCP),
including the writes that constitute it; a walk that avoids those writes is not
proof. Focused tests or real-boundary probes may suffice; browser-visible
behaviour needs rendered browser proof, including when the change is in stores,
calculations or other indirect owners, and a changed assistant head or transport
needs a live model call. Obvious low-risk changes may explain why code inspection
suffices. Start with cheap checks; they do not replace proof of rendered outcomes.

The agent runs this proof itself by default, dev server, browser and dev
deployment included, in the repo-approved development environment ("Live proof"
below). It asks first only when proof would spend a metered budget (API tokens, a
billed review round) or reach outside that environment (production data, a real
third party, a shared account); the repo's hazard list is the standing boundary.

Proof is scoped by blast radius, not by revision. After a fix, re-prove only
the surfaces that fix can change; a fix that cannot alter rendered behaviour
(a comment, a test, a type) is covered by the gate alone. The
record names what the re-proof covered and what it reused from the earlier
proof of this branch.

Move incrementally toward a small maintained set of complete, real user
workflows with precise outcomes. Reuse existing coverage first. Every PR states
its scenario decision: reuse, extend, add, or no new scenario, with the reason.
Clear-cut scenario additions or modifications belong in their own commit and are
explicitly noted in the PR body with the gap they protect. When the need or scope
is unclear, ask before implementing; if the user is unavailable during an
autonomous run, record the proposal as a PR follow-up instead of adding speculative
coverage. A feature or PR does not automatically earn a permanent scenario; an
unprotected failure whose recurrence would cost something does. Keep
focused lower-level tests for distinct numerical edges, permissions, rollback and
other material failures a workflow does not catch.

Scenarios live in a repo-owned location linked from its `AGENTS.md` / `CLAUDE.md`.
Each states setup and synthetic fixtures, user actions, fixed observable outcomes,
when to run it, and cleanup. Use the repo's existing tools; neither a new framework
nor CI is required. Adding a dependency still needs approval. Commit the scenario
specification; ad hoc walk scripts stay ephemeral. Any committed executable
scenario or deterministic test code is type-checked, linted and run by the repo's
gate (`check`); this requires no new runner.

An agent may adapt navigation to the current UI, but cannot relax an assertion or
navigate/reload to repair stale output before asserting it. Record the actual SHA
(and uncommitted changes tested), environment, fixture, actions, expected and
observed results, and gaps in the PR or delivery evidence. Name every end-to-end
scenario and variant actually run with its outcome; a test count alone is not
evidence. Distinguish fresh runs, reused evidence and incomplete checks. A passing
walk proves
those outcomes on that revision and environment, never blanket absence of
regressions. Reuse completed evidence while the relevant contract, execution path,
fixture and environment remain unchanged, retaining the actual tested revision
rather than claiming a run on the new head. After a rebase or upstream change,
inspect impact and rerun only the smallest invalidated proof; a new SHA alone is
not a rerun trigger. Use judgment to run heavier end-to-end checks at meaningful
verification points when a change could reasonably affect their protected behavior,
not after every small edit or commit. Required automated gates remain separate.
Keep run ephemera outside the worktree per `principles.md` §9.

## Live proof and deterministic tests

Live proof uses only a repo-explicitly approved development environment, DB and
test credentials. Verify the selected secrets config (e.g. Doppler) and actual
target; a `dev` label alone is not authority. If an approved environment or required
credentials are missing, stop the dependent live proof, ask for setup, and record
the incomplete gap; never guess or call it verified. Scope side effects to test
data, make reruns safe, and perform the scenario's cleanup. Never include secrets in evidence. Production
and destructive-data authority remain governed by the repo and git/data rules.

Deterministic tests are hermetic: mock external network calls and use synthetic
credentials; never read or change a developer's credentials. The project's test
setup blocks unstubbed fetches and fails on every blocked attempt, even if caught.
Use explicit signals or controlled clocks for synchronization; runner timeouts are
hang guards. Before restoring mocks, finish running application work and cancel
or discard pending work so none reaches another test. This isolation rule does
not ban approved live proof.

## Authoring gate

Before adding or changing a test, answer all five; a missing answer means don't
write it yet:

1. **What behaviour or contract does it protect?** Name it in the user's or the
   API's terms, not the function's.
2. **How can it fail?** For new logic, list the failure modes *before* writing
   the code. Each one becomes a table row. An empty list means the code is
   wiring — no dedicated test.
3. **Why doesn't existing coverage already catch it?** Each contract has one
   primary test at its strongest boundary. Another layer needs its own
   distinct risk. Extend the existing table or file before minting a new one.
   Duplication counts across the branch, not per test: search the suite
   first. A test may pass through a scenario another test owns as setup; it
   doesn't assert it again.
4. **Does it need a production seam** (an export, flag, wrapper, or injection
   hook no production caller uses)? Then move the test to the real boundary.
5. **Has it been seen failing?** A test counts only after it fails for the
   intended reason: for a bug, on the pre-fix code; for new logic, either
   before the code exists or, when written after it, by breaking the code on
   purpose, watching it fail, and restoring it.

The answers are recorded where a reviewer finds them: the test title names
the behaviour; one comment per test or table names the regression and why
existing coverage misses it; the seen-failing evidence (the case, how failure
was induced, the failure observed) goes in the commit message or PR
description. A reviewer who can't find them treats the test as unjustified.

A test that would break under a behaviour-preserving refactor asserts
implementation. Rewrite it at the owning boundary before landing it.

A bug whose recurrence would cost something gets one regression test at the
owner boundary (not one per layer it crossed), unless existing coverage
already catches it; extend existing cases before adding another test.

A flake is fixed in the test or the code under test. Changing the test
harness's semantics needs a reproducer showing it differs from production; the
commit names the difference and links an upstream issue when one applies.
Ordinary isolation fixes (reset, teardown, cleanup) need no upstream defect.

## Shapes to refuse

(why: rationale.md#test-shapes)

- *Derive, don't mirror.* Fixture and config inputs come from the canonical owner/config; expected outcomes are computed independently of the code under test. Never re-type a roster, enum, prompt sentence, byte size, CSS class, or log string as a literal. Assert the invariant (closure, membership, partition, gating), not the text. Only a self-declared drift pin with no importable owner may be literal.
- *Mock boundaries, run owners.* Mock only real process boundaries (external DB/HTTP/SDK/telemetry/router/i18n/timers — never the application's own test DB when proving its server boundary); everything in-process runs real — no hand-rolled store/engine shims, no in-test reimplementation of a production rule, no mock that implements the behaviour being asserted, no fixture that pre-supplies the receipt, admission, or ordering the owner should produce, and no single positional mock (`mockResolvedValueOnce` chain) answering for several different APIs — key each mock to the function it stands in for. `toHaveBeenCalledWith` is contract testing against a boundary and theater against a pure function two imports away — judge the collaborator, not the matcher.
- *Never assert a result against itself.* Totals vs their own components, `toEqual(canonicalBuilder(sameInput))`, determinism self-compares, fixture echo, in-test helpers tested by the same file, expected values produced by the code under test, a capability or registry test that restates a declared flag instead of exercising what the flag promises. Hand-derive or table-drive a fixed expectation.
- *One owner, one file; fold before minting.* New cases go in the existing file on that owner; a new test FILE needs a stated reason (different environment, incompatible hoisted mocks, separate owner). No PR/phase tokens in filenames; no regular/batch twins on one owner — table-drive with `describe` rows. Single-`it()` files are a smell by default.
- *Table-drive repetition.* N near-identical `it()`s over one arranged result → `it.each` with titled rows.
- *No source-text assertions.* `readFileSync` + `toContain`/regex over production source executes nothing. Drift guards are lint rules or render assertions, not tests.
- *Don't pin values, bugs, clocks, or one-shots.* No test asserts a constant's or default's value; test what it bounds. A known bug gets `it.fails` with its issue ID; dropping its test instead needs a surviving guard or evidence the protection is unnecessary. No real elapsed-time wait decides pass/fail; fake timers for provider delays are fine. Code with one run of remaining life (a backfill, a pre-deploy shim) is checked by that run's read-back, not a permanent test (a destructive migration may add a cheap rehearsal test that retires with it); a compatibility test for stored legacy data names its retirement condition.
- *Honest negatives and names.* A negative control must fail for the guard it names, not an unrelated rejection. A test name must not promise more than its input exercises.

## Plan-time rule (agentplan / execute-plan / longrun)

Each phase names its minimal proof and test set, the owners, outcomes and failure
paths it proves, and its scenario decision under "PR proof and regression
scenarios". "No new test — covered by <file>" is a valid, stated answer. A new test
*file* is justified in the plan or it does not ship.
The orchestrator rejects the refused shapes and gate failures at its per-phase
diff check (`workflows/execute-plan.md` "Phase loop"), not at the next audit.

## Pruning existing tests

A broader sweep needs my request; no blanket deletion. Within a change, a proven
workflow may replace lower-level tests when it demonstrably catches the same
material failures, and its run triggers include changes to the protected owner.
A test is deleted only with its evidence recorded: what it can
actually detect, the stronger test that still covers it (or why none is
needed), and any test-only production seam the deletion lets you remove —
remove that seam in the same change.

Keep distinct protection for a public API, protocol, config-format
(a shape, not a default value), migration, storage, security, money, or
permission contract, even when it looks static or implementation-shaped; a
happy-path walk is not a replacement for its edge cases. A
retained test that fails on the baseline is a possible product bug: reproduce
it before touching it.
