# Engineering principles

Every project, every agent. Name any deviation a real constraint forces where
it happens. Project `AGENTS.md` / `CLAUDE.md` overrides or extends these.
`(why: rationale.md#…)` points at the reasoning in
`~/Development/developer-config/instructions/rationale.md` (not loaded).

## 1. Think before coding

- **My attention is scarce; spend it only where it changes the outcome.** Close decisions yourself: from the request, the code, or the plan; the simpler, more reliable architecture when both work; when two defensible options remain, the simpler one, or in complex work a cross-family review (never mandated; authorized per `dispatch-bootstrap.md` "External calls"), taking the one it agrees with. Bring me only a genuine trade-off, a conflict the sources cannot resolve, or a cost I own (money, people, an unrecoverable change): each option's trade-off in a line, your recommendation, what hinges on it. Trivial ambiguity or one clearly right option: take the default and say so; cheap, reversible edits are not decisions. (why: rationale.md#attention)
- If a simpler approach than the one asked for exists, say so before implementing.
- Exploratory questions ("what could we do?") get 2–3 sentences: a recommendation and the main trade-off. Don't implement until I agree.
- **Sketch first, then brief.** When explaining a flow, architecture, state, or set of options, lead with a sketch (ASCII or mermaid), then the fewest sentences that carry the trade-offs. A reply states the answer, the evidence, and any decision that is mine; it does not narrate your reasoning or restate the ask. Explanation I ask for is given in full. LLM-facing documents use whatever format their reader reads best.

## 2. Simplicity first

Default to subtracting: the smallest change that solves the problem. Before adding, ask what the change lets you remove; for a code change report net lines. (why: rationale.md#subtract)

- **Design before changing.** For anything non-trivial, first name the smallest clear design in concepts (owners, states, decisions, failure paths) that meets the real requirement today, then make the change that moves toward it. The existing shape is evidence, not a requirement.
- Write the minimum code that solves the stated problem: no features, abstractions, or config surfaces for scenarios not asked for or that can't happen; error handling follows §6. Cut unused surface, not craft.
- **Decision ladder:** take the first option that satisfies the contract — an existing owner in this codebase → stdlib → native platform feature (HTML element, CSS, DB constraint) → an already-installed dependency → only then minimum custom code.
- **Lock shape early, build behaviour late.** In a contract (schema, API, stored record), settle now only what is both expensive to change later (names, keys, identity, edges) and needed by this change. An empty slot for a future behaviour is still surface. Test: can the next change refine this without a migration?
- Never hardcode a value the caller or existing config already owns. (why: rationale.md#simplicity)
- Fix the real type (`unknown` with guards, proper types, generics); never suppress errors with `any` or `@ts-ignore`.
- **Model the domain in types.** Variants are a discriminated union or state machine, never booleans that must stay in sync or a bag of optional fields; every switch over them is exhaustive, checked by the compiler or linter.
- Reduce complexity by simplifying logic, never by redistributing it. Pass-through wrappers are one example, whatever the lint score says.
- Ask before adding a dependency; prefer ~30 lines of owned code over a small package. The package version being added must be at least 48 hours old — verify the bun/pnpm minimum-release-age cooldown applies.

## 3. Surgical changes

- Every changed line traces to the task or to a clear-cut fix. No bells and whistles; don't restyle or rework adjacent code. Remove orphans your change created; delete removed code outright — no renames, re-exports, or shims.
- **Simpler is in scope; bigger is a conversation.** A problem you notice that is clear-cut — one right answer, small, keeps or plainly corrects behaviour (a duplicate owner that agrees, dead code, an obvious bug) — gets fixed in this change, as its own commit, named in the PR. One that needs a choice (owners that disagree, an intentional contract or behaviour change) or a refactor gets raised right away with its location, blast radius (§8), and a proposed follow-up, and we plan it together; in an autonomous run it goes in the final report. Never fix silently.
- **A refactor pins behaviour first and earns its keep.** Before structure moves, capture current behaviour with a characterisation test or equivalence harness; typecheck and lint are not a pin, and a one-run pin is not committed. If the diff does not lower reader load somewhere (fewer layers to trace, less state to hold), revert it.
- Delegated leaves report proposals in `SUMMARY.OUT_OF_SCOPE_FINDINGS`; `codex-delegation.md` owns the patch-file protocol. Out-of-scope proposals stay outside the worktree until I apply them. (why: rationale.md#agent-proposals)

- **Uncommitted changes that don't trace to your task are mine.** Never revert, restore, stash, or delete them without asking, even when they look like agent overreach; "not in the brief" means investigate. If a fix needs a file carrying my WIP, stop and ask. Snapshot, provenance, and recovery mechanics: `git-operations.md` "Parallel WIP". (why: rationale.md#parallel-worktree-wip)

## 4. Goal-driven execution

- For multi-step work, state a brief plan with a verification check per step, then loop against it; success criteria strong enough to iterate without check-ins.
- **Escalation bar (autonomous workflows):** under granted autonomy (execute-plan, rev, longrun, delegated runs), escalate only what §1's attention rule leaves open AND would be costly to undo — with a recommendation and the key trade-off. Otherwise take the best-supported default and record it in the final report. A decision the cross-family reviewer agrees with is made.
- **Pre-commit gate:** before EVERY commit, run the project's FULL verification battery, not the quick loop. (why: rationale.md#pre-commit-gate)

### Tests

`~/Development/developer-config/instructions/testing.md` owns test strategy (where tests live, what to mock, what to refuse) — read it before writing, changing, reviewing, or deleting tests. Two rules travel with every change:

- Follow [PR proof and regression scenarios](./testing.md#pr-proof-and-regression-scenarios) for dev proof and the PR scenario decision. A shared harness or mock edit needs a consumer suite outside the original happy path.
- **A test counts only after it is seen failing for the intended reason**: for a bug, on the pre-fix code; for new logic, before the code exists or by breaking it on purpose.

### Ship gate

Every delivery, a PR or a direct merge to main, ships only when it is clearly beneficial and non-regressing. At planning and finalizing, name the real benefit and the surfaces the change could regress (shared mocks, list universes, sibling callers, public contracts). Each named surface is proven, by fresh proof or by earlier proof the change cannot have invalidated (`testing.md`); re-proving what a minor change cannot touch is waste. Full confidence is rare, so a regression that escapes proof must still fail loudly (§6: a typed error, a Sentry event, a watched log) and be seen and recoverable, never silent. Loud failure is the net under proof, not a substitute for it. **Never ship a known regression**: close it in the same change, or stop and replan. Accepted residual risk is rare and explicit: the plan and the PR or delivery brief name why it is accepted and the verification evidence under [PR proof and regression scenarios](./testing.md#pr-proof-and-regression-scenarios).

## 5. Canonical sources of truth

- An owner is the one place that *decides* a fact, rule, or mechanism (business rule, constant, derived value, type, mutable fact). Everything else derives from or references it. Find the owner before writing logic; create one if none exists, documenting only ownership decisions the code cannot make clear. Never create a second, and never reconcile two by adding a third. Prefer the design where the locally right edit is globally right: derive hand-synced lists from one source or fail the build when they disagree, and enforce public module boundaries. (why: rationale.md#agent-contributor)
- Not a second owner — one bullet per case, add new ones here:
  - A mechanical derivative (cache, projection, generated type, denormalized column) generated from the owner; stored copies are rebuilt or automatically checked for drift.
  - A transition with a named authoritative owner for each phase and a deadline for deleting the old implementation.
  - Similar code. Look-alike modules share an owner only when they share a rule that must change together; abstract for that, not for resemblance.
- **A bug fix is the root cause.** Ask whether the state that triggered the symptom is legitimate. If it may occur, handling it where it broke is the fix; if it should never exist, a guard there hides the bug, so find what produced it (guards, retries, swallowed errors, and clamped values are the usual masks). When two fixes sharing one belief have failed the same gate, write the belief down and test it before a third. Before changing a shared owner, inspect every caller and verify affected sibling paths. Fix where the violated invariant belongs, not only on the ticket's path.

## 6. Fail loud, not silently

A failure is visible and recorded. Whether it stops the user or lets them proceed with the error logged is the repo's call; silent is never. (why: rationale.md#fail-loud)

- Validate only at real boundaries (user input, external APIs). On failure, throw a loud, typed error rather than catch and continue. Inside a pipeline, record the failed state where its owner shows it and release what it holds.
- **Speculative robustness is a scope decision.** Before adding a guard, retry, lock, or fallback for a failure nobody has observed (a race, a security edge case), check §8's observed bar, a contract the task requires, or convergence below. Otherwise never add it silently: state the concrete failure, its likelihood, and the code it costs, then ask (§1); under autonomy, decide and report (§4). Prefer the design that makes the state impossible (§2's ladder) over a guard that handles it.
- **Mutating steps converge.** Ask of every state-mutating operation: what if it runs twice, or the previous run crashed halfway? A retry of the same mutation converges, and what an interrupted run leaves behind (a lock, a temp file, a half-written record, a claimed job) is distinguishable from live work.
- **Selection and coverage follow domain boundaries** (time window, watermark, dependency state, all matching records), never arbitrary item/pass/time quotas. A numeric ceiling is only an explicitly labeled runaway/cost circuit breaker; when it trips, stop loudly and keep prior work — never truncate silently or call partial work complete.
- Destructive operations on real data (migrations, bulk `DELETE`/`UPDATE`, overwriting files outside the repo): when in any doubt, ask me and validate before running. Removing committed, tracked files is recoverable — use judgement; ask before removing what git can't restore (untracked or uncommitted work, paths outside a repo).

## 7. Branch, worktree & commit management

`instructions/git-operations.md` owns git, branch, worktree, and commit operations (permissions, backstop hook, commit hygiene, rebase policy); `instructions/durable-worktrees.md` owns worktree layout. Read `git-operations.md` before any git write or edit-capable dispatch; read `durable-worktrees.md` before creating or repurposing a durable worktree. The invariant: **explicit direction IS the approval; anything unrecoverable requires my approval.**

## 8. High-value bias (80/20)

- If 20% of the effort captures 80% of the value, that is the default scope; go further only when the foundation needs it (entropy at scale, owner consolidation, regression safety on critical paths).
- Every proposed piece of work names its blast radius — what breaks or degrades if it isn't done. No blast radius, no work item. (why: rationale.md#idle-pass)
- **An issue needs an observed, reachable, or deletes bar.** Observed means a user said it, Sentry fired, or a data count shows wrong output today. Reachable means a reasonable chance, even as a prod edge case, of wrong money, data, permissions, or a lost request; name the path and wrong outcome, no repro needed to file. Deletes names what goes. A rule the code does not yet meet, a smarter lint, a tighter type, a test rewrite, or low-likelihood "could happen if…" is never filed: it stays in the audit report, or becomes a `simplified:` marker at its one site. The body opens with `Bar: observed — <evidence>`, `Bar: reachable — <path> → <wrong outcome>`, or `Bar: deletes — <what>`, then blast radius in one sentence, a bucket (`priority:high` wrong output or lost request today, `priority:medium` reachable and contained, `needs-decision`; there is no `someday`), pointers verified against a named SHA, fix direction and size. An audit run files only what passes and reports how many findings it did not file. An issue I explicitly ask for opens with `Bar: directed — <my words, quoted>` instead; an agent never uses it on its own initiative. (why: rationale.md#issue-bar)
- **Fold by root, not by symptom.** Before filing, identify the root cause and its owner (§5). One issue per root; its body lists every symptom the fix settles as a checkable "done when" task-list line (`- [ ] …`), ticked when the slice that proves it lands. A symptom of an open root is a line there, never its own issue. Clear-cut cleanup is never filed: §3 says where it ships.
- Size a fix to the code's remaining life: a one-shot migration, tear-down, or backfill gets the smallest shape that completes its run; permanent indexes, general contracts, and proof systems are for code that stays. A subagent's recommendation informs this sizing; it is never the plan.

## 9. Verify cheap first — browser authority

- Climb the ladder: typecheck → tests → read the code path → curl the endpoint or
  read server logs. Browser-visible PR outcomes require rendered proof under
  `testing.md` "PR proof and regression scenarios", even when their calculations
  can also be checked below the UI. (why: rationale.md#browser-cost)
- **Browser authority:** a browser session in the repo-approved dev environment with test credentials needs no asking; it is spent like any other token. The ask triggers are [PR proof](./testing.md#pr-proof-and-regression-scenarios)'s: a metered budget, or anything outside that environment.
- **How to drive it:** the `browser-test` skill.
- **Run ephemera never land in the worktree.** Browser profiles, driver scripts, dev-server logs/pids, screenshots, and probe outputs go in the session scratchpad (or `/tmp/<task>/`), never in the repo, gitignored or not; delete them when the run ends. What's worth keeping goes in the report or memory, not a leftover folder. (why: rationale.md#run-ephemera)

## 10. React: reach for useEffect last

Don't sync state with `useEffect`. Derive from state/props inline or with `useMemo`; fetch with a query/loader; handle user actions in event handlers; reset state with a `key`. A genuine effect (sync with an external system) gets a comment saying why. `/no-use-effect` audits a branch against the full policy.

## 11. Entropy control

(why: rationale.md#entropy)

- Follow the repo's foundation docs and existing pattern, even when you'd do it differently. Never add a competing one: if yours is genuinely better, say so and migrate fully, or don't introduce it. If the task needs a pattern the codebase lacks, name it and resolve the choice under §1 (under autonomy, §4).
- Name an awkward fit your change forces (a hack, a parameter threaded through layers, a special case) in your summary.
- A deliberate simplification with a known ceiling carries a greppable marker: `// simplified: <ceiling>. upgrade when: <observable trigger>` (in the language's comment syntax). No observable trigger, rejected at review.
- **A tactical mitigation is labeled as one** and never replaces or claims to be the root-cause fix. If the foundation is out of scope, stop and align rather than stack knobs (batch shrinks, timeouts, page cuts) that leave the worst case broken.
- Leave what you touch no worse: no commented-out blocks, no TODOs without an owner (§3 bounds how far cleanup reaches).
- A comment survives only for a non-obvious *why* the code cannot show; no phase narration. A `do not remove`-style comment is a rule without an enforcer: give it the cheapest one that exists (type, test, or lint) and keep only the why.
- A violation class that keeps recurring graduates into a standing check (lint rule, CI script); one-off findings stay findings.

## 12. UI/UX: intentional information, zero duplication

The default audience is a non-technical user. (why: rationale.md#ui-drift)

- Every element maps to a decision or action that user takes; if you can't name who needs it and why, cut it — a collapsed panel is still an element.
- **No taglines, helper text, or secondary labels.** If a screen needs them to make sense, fix its grouping, task order, control names, or state display. Exception: one sentence stating an irreversible action's consequence, at the point of commit.
- A fact appears in exactly one place per view (§5 applied to pixels).
- Labels use the user's word for their task, never the data model's. Record names, raw IDs, hashes, enum codes, and codenames appear only on provenance or technical surfaces (drawer, tooltip, admin gate), never inline; a reference carries the user-facing description, the raw ID only as a supplementary field when genuinely needed. Enforced like permissions.
- Tabs and sections over one long scroll; secondary content is progressively disclosed.
- Refine the screen; don't mint a parallel one. No second route or `-v2` component for the same data; a genuine A/B names the date it collapses back to one.

## 13. Documentation: only what code cannot say

Code is the source of truth for what the system does. A doc earns its place only if an agent with full read access to the code and no docs would otherwise make a wrong decision.

- A doc states a rule that must keep being observed (a decision procedure, a cross-file invariant, a hazard, a rejected alternative) or a north star the team is steering toward. Write the rule, not the instance.
- A doc never states what the code does: no inventories, walkthroughs, status, or history. Reusable runbooks and test procedures no script encodes are legitimate.
- A doc that disagrees with the code: when the right side is clear-cut, repair the wrong one; otherwise raise it (§1) and reconcile.
- Plans are local and temporary: gitignored, never committed, folded into the owning doc at closeout only where they pass this bar.
- No backlog in a repo: file only what §8 admits; a located gap gets a `simplified:` marker only when §11 admits it.
- Adding prose means removing prose: before a new rule, try tightening an existing one.

## Plugin usage

Use plugins or plugin-provided skills only when I request the plugin or skill by name; default to built-in/local tools and repository context.
