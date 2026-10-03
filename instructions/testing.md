# Testing

Owns how tests are chosen, written, reviewed, and pruned in every repo;
`principles.md` §4 carries the always-loaded core and points here. Read this
file before writing, changing, reviewing, or deleting tests. Project-level
`AGENTS.md` / `CLAUDE.md` may name the repo's boundary harness and fixtures.
(why: rationale.md#test-strategy)

## Where tests live: the stable boundary

Our UIs change constantly; business rules change rarely. Test the stable
layer, not the churning one.

| Layer | Default | What belongs there |
|---|---|---|
| **Server boundary** (queries, mutations, API handlers against a real test DB) | **The main investment.** | Every business rule, permission, status transition, and money outcome, called through the public function, with only external services mocked. |
| **Pure logic** (tax, FX, rounding, proration, dates, parsers, state machines) | Unit tests, table-driven. | Only code that would still be hard to get right with every dependency removed. |
| **Wiring** (pass-throughs, hooks calling a query, glue helpers, component internals) | **No dedicated test.** | The server-boundary test already runs it. |
| **UI** | No scripted E2E suite by default. | A browser walk (§9) when the UI itself is the risk, leaving a replayable record (below). |

A repo that already has a scripted E2E suite keeps it; a suite that nothing
runs (neither `check` nor CI) is decoration. Adding an E2E framework to a repo
is a dependency decision — ask first.

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

**Tests are hermetic.** Mock external network calls and use synthetic
credentials; never read or change a developer's credentials. The project's test
setup blocks unstubbed fetches and fails on every blocked attempt, even if
caught. Use explicit signals or controlled clocks for synchronization; runner
timeouts are hang guards. Before restoring mocks, finish running application
work and cancel or discard pending work so none reaches another test.

## Shapes to refuse

(why: rationale.md#test-shapes)

- *Derive, don't mirror.* Fixture and config inputs come from the canonical owner/config; expected outcomes are computed independently of the code under test. Never re-type a roster, enum, prompt sentence, byte size, CSS class, or log string as a literal. Assert the invariant (closure, membership, partition, gating), not the text. Only a self-declared drift pin with no importable owner may be literal.
- *Mock boundaries, run owners.* Mock only real process boundaries (external DB/HTTP/SDK/telemetry/router/i18n/timers — never the application's own test DB, which the server-boundary row runs real); everything in-process runs real — no hand-rolled store/engine shims, no in-test reimplementation of a production rule, no mock that implements the behaviour being asserted, no fixture that pre-supplies the receipt, admission, or ordering the owner should produce, and no single positional mock (`mockResolvedValueOnce` chain) answering for several different APIs — key each mock to the function it stands in for. `toHaveBeenCalledWith` is contract testing against a boundary and theater against a pure function two imports away — judge the collaborator, not the matcher.
- *Never assert a result against itself.* Totals vs their own components, `toEqual(canonicalBuilder(sameInput))`, determinism self-compares, fixture echo, in-test helpers tested by the same file, expected values produced by the code under test, a capability or registry test that restates a declared flag instead of exercising what the flag promises. Hand-derive or table-drive a fixed expectation.
- *One owner, one file; fold before minting.* New cases go in the existing file on that owner; a new test FILE needs a stated reason (different environment, incompatible hoisted mocks, separate owner). No PR/phase tokens in filenames; no regular/batch twins on one owner — table-drive with `describe` rows. Single-`it()` files are a smell by default.
- *Table-drive repetition.* N near-identical `it()`s over one arranged result → `it.each` with titled rows.
- *No source-text assertions.* `readFileSync` + `toContain`/regex over production source executes nothing. Drift guards are lint rules or render assertions, not tests.
- *Don't pin values, bugs, clocks, or one-shots.* No test asserts a constant's or default's value; test what it bounds. A known bug gets `it.fails` with its issue ID; dropping its test instead needs a surviving guard or evidence the protection is unnecessary. No real elapsed-time wait decides pass/fail; fake timers for provider delays are fine. Code with one run of remaining life (a backfill, a pre-deploy shim) is checked by that run's read-back, not a permanent test (a destructive migration may add a cheap rehearsal test that retires with it); a compatibility test for stored legacy data names its retirement condition.
- *Honest negatives and names.* A negative control must fail for the guard it names, not an unrelated rejection. A test name must not promise more than its input exercises.

## Replayable walk records

An agent browser walk proves a flow once. When it proves a critical flow, it
leaves a record the next agent can re-run and compare instead of re-exploring:
the fixture or seed used, the steps, and the observable expected outcome
(values, statuses, rows). The record goes in the report, or in the repo's
existing walk/fixture location when the repo has one — never as a run
leftover in the worktree (§9 run ephemera).

## Plan-time rule (agentplan / execute-plan / longrun)

Each phase names its minimal test set, and for each test the owner and the
failure path it proves. "No new test — covered by <file>" is a valid, stated
answer. A new test *file* is justified in the plan or it does not ship.
Reviewers reject the refused shapes and gate failures at phase review, not at
the next audit.

## Pruning existing tests

Only when I ask for a sweep. One repo or subsystem per PR; no blanket
deletion. A test is deleted only with its evidence recorded: what it can
actually detect, the stronger test that still covers it (or why none is
needed), and any test-only production seam the deletion lets you remove —
remove that seam in the same change.

Keep a test that independently guards a public API, protocol, config-format
(a shape, not a default value), migration, storage, security, money, or
permission contract, even when it looks static or implementation-shaped. A
retained test that fails on the baseline is a possible product bug: reproduce
it before touching it.
