# Engineering principles

Every project, every agent. Name any deviation a real constraint forces where
it happens. Project `AGENTS.md` / `CLAUDE.md` overrides or extends these.
`(why: rationale.md#…)` points at the reasoning in
`~/Development/developer-config/instructions/rationale.md` (not loaded).

## 1. Think before coding

- Genuinely ambiguous ask: present the interpretations and ask. Trivial ambiguity, or one clearly right option: take the default and say so. Questions are for trade-offs that are mine to weigh (§4's escalation bar is the autonomous mirror).
- If a simpler approach than the one asked for exists, say so before implementing.
- Exploratory questions ("what could we do?") get 2–3 sentences: a recommendation and the main trade-off. Don't implement until I agree.
- **Sketch first, then brief.** When explaining a flow, architecture, state, or set of options, lead with a sketch (ASCII or mermaid), then the fewest sentences that carry the trade-offs. A reply states the answer, the evidence, and any decision that is mine; it does not narrate your reasoning or restate the ask. Explanation I ask for is given in full. LLM-facing documents use whatever format their reader reads best.

## 2. Simplicity first

Your default as a coding agent is to add; ours is to subtract — a senior engineer's smallest change that solves the problem. Deletion is a result: before adding, ask what the change lets you remove, and for a code change report net lines. (why: rationale.md#subtract)

- **Design before changing.** For anything non-trivial, first name the smallest clear design in concepts (owners, states, decisions, failure paths) that meets the real requirement today, then make the change that moves toward it. The existing shape is evidence, not a requirement.
- Write the minimum code that solves the stated problem: no features, abstractions, config surfaces, or error handling for scenarios not asked for or that can't happen. Cut unused surface, not craft.
- **Decision ladder:** take the first option that satisfies the contract — an existing owner in this codebase → stdlib → native platform feature (HTML element, CSS, DB constraint) → an installed dependency → plain logic → only then minimum custom code.
- **Lock shape early, build behaviour late.** In a contract (schema, API, stored record), settle now only what is both expensive to change later (names, keys, identity, edges) and needed by this change. An empty slot for a future behaviour is still surface. Test: can the next change refine this without a migration?
- Never hardcode values unless told to; take them from config or the caller. (why: rationale.md#simplicity)
- Fix the real type (`unknown` with guards, proper types, generics); never suppress errors with `any` or `@ts-ignore`.
- Reduce complexity by simplifying logic, never by redistributing it. Pass-through wrappers are one example, whatever the lint score says.
- Ask before adding a dependency; prefer ~30 lines of owned code over a small package. A package must be at least 48 hours old — verify the bun/pnpm minimum-release-age cooldown applies.

## 3. Surgical changes

- Every changed line traces to the task or to a clear-cut fix. No bells and whistles; don't restyle or rework adjacent code. Remove orphans your change created; delete removed code outright — no renames, re-exports, or shims.
- **Simpler is in scope; bigger is a conversation.** A problem you notice that is clear-cut — one right answer, small, keeps or plainly corrects behaviour (a duplicate owner that agrees, dead code, an obvious bug) — gets fixed in this change, as its own commit, named in the PR. One that needs a choice (owners that disagree, a contract or behaviour change) or a real refactor gets raised right away with its location, blast radius (§8), and a proposed follow-up, and we plan it together; in an autonomous run it goes in the final report. Never fix silently.
- Delegated leaves report proposals in `SUMMARY.OUT_OF_SCOPE_FINDINGS`; `codex-delegation.md` owns the patch-file protocol. Out-of-scope proposals stay outside the worktree until I apply them. (why: rationale.md#agent-proposals)

### Parallel work in the worktree

I often work in parallel in the same worktree. Uncommitted changes that don't trace to your task are usually MINE and intentional — never revert, restore, stash, or delete them without asking, **even when they look like agent overreach or scope creep**. "Not in the brief" means investigate, not discard. (why: rationale.md#parallel-worktree-wip)

- **Snapshot before delegating.** Before dispatching any subagent that can touch the worktree, record `git status --porcelain` + `git diff HEAD --stat` (e.g. in `/tmp/<task>-predispatch.txt`). Everything pre-dispatch is mine; only deltas beyond it are the agent's.
- **Provenance check before any revert.** Before `git restore` / `git checkout --` / unstaging anything, diff against the snapshot. No snapshot → assume it's mine and ask.
- If a fix needs a file carrying my WIP, stop and ask — don't "clean it up" to tidy your diff.
- If you discard something by mistake, attempt recovery before reporting it lost: staged content usually survives as an unreachable blob (`git fsck --unreachable`, or the blob hash from a diff header you printed).

## 4. Goal-driven execution

- For multi-step work, state a brief plan with a verification check per step, then loop against it; success criteria strong enough to iterate without check-ins.
- **Escalation bar (autonomous workflows):** under granted autonomy (execute-plan, rev, longrun, delegated runs), escalate only decisions that cannot be established from the request, code, or plan AND would be costly to undo — with a recommendation and the key trade-off. Otherwise take the best-supported default and record it in the final report. A decision the cross-family reviewer agrees with is made.
- **Pre-commit gate:** before EVERY commit, run the project's FULL verification battery (e.g. `pnpm run check`), not the quick loop, which skips the custom/architecture rules. (why: rationale.md#pre-commit-gate)

### Tests: value, not coverage

`~/Development/developer-config/instructions/testing.md` owns test strategy — read it before writing, changing, reviewing, or deleting tests. Always in force:

- A test earns its place by catching a real regression that would cost something; coverage means nothing.
- Test stable boundaries: real server functions against a real test DB, mocking only external services. Unit-test pure logic with real failure modes; no dedicated wiring tests. UI defaults to browser walks; existing E2E suites follow `testing.md`.
- Shared harness or mock edits need a consumer suite outside the original happy path.
- Tests that break under behavior-preserving refactors or require seams no production caller uses must move to the real boundary before landing.
- **A test counts only after it is seen failing for the intended reason**: for a bug, on the pre-fix code; for new logic, before the code exists or by breaking it on purpose.

### Ship gate: beneficial + no open regression (plan and finalize)

At planning and finalizing, name the real benefit and surfaces the change could regress (shared mocks, list universes, sibling callers, public contracts).

**Never ship a known regression** — close it in the same change, or stop and replan.

Accepted residual risk is rare and explicit. The plan and PR or delivery brief name why it is accepted and the verification evidence: suite, check command, or smoke path (UI-only risk: §9).

The fix lives in the shape the repo's foundation docs define.

## 5. Canonical sources of truth

- An owner is the one place that *decides* a fact, rule, or mechanism (business rule, constant, derived value, type, mutable fact). Everything else derives from or references it. Find the owner before writing logic; create one if none exists, documenting only ownership decisions the code cannot make clear. Never create a second, and never reconcile two by adding a third.
- Not a second owner — one bullet per case, add new ones here:
  - A mechanical derivative (cache, projection, generated type, denormalized column) generated from the owner; stored copies are rebuilt or automatically checked for drift.
  - A transition with a named authoritative owner for each phase and a deadline for deleting the old implementation.
  - Similar code. Look-alike modules share an owner only when they share a rule that must change together; abstract for that, not for resemblance.
  - Client validation mirroring the server's, when both derive from the same schema.
- A bug fix is the root cause. Before changing a shared owner, inspect every caller and verify affected sibling paths. Fix where the violated invariant belongs, not only on the ticket's path.

## 6. Fail loud, not silently

A failure is visible and recorded. (why: rationale.md#fail-loud)

- Validate only at real boundaries (user input, external APIs). On failure, throw a loud, typed error rather than catch and continue. Inside a pipeline, record the failed state where its owner shows it and release what it holds. No fallback unless the scenario genuinely warrants it; when in doubt, ask.
- **Selection and coverage follow domain boundaries** (time window, watermark, dependency state, all matching records), never arbitrary item/pass/time quotas. A numeric ceiling is only an explicitly labeled runaway/cost circuit breaker; when it trips, stop loudly and keep prior work — never truncate silently or call partial work complete.
- Destructive operations on real data (migrations, bulk `DELETE`/`UPDATE`, overwriting files outside the repo): when in any doubt, ask me and validate before running.

## 7. Branch, worktree & commit management

`instructions/git-operations.md` owns git, branch, worktree, and commit operations (permissions, backstop hook, commit hygiene, rebase policy); `instructions/durable-worktrees.md` owns worktree layout. Read it before any git write. The invariant: **explicit direction IS the approval; anything unrecoverable requires my approval.**

## 8. High-value bias (80/20)

- If 20% of the effort captures 80% of the value, that is the default scope; go further only when the foundation needs it (entropy at scale, owner consolidation, regression safety on critical paths).
- Every proposed piece of work names its blast radius — what breaks or degrades if it isn't done. No blast radius, no work item. (why: rationale.md#idle-pass)
- Size a fix to the code's remaining life: a one-shot migration, tear-down, or backfill gets the smallest shape that completes its run; permanent indexes, general contracts, and proof systems are for code that stays. A subagent's recommendation informs this sizing; it is never the plan.

## 9. Verify cheap first — ask before driving a browser

- Climb the ladder: typecheck → tests → read the code path → curl the endpoint or read server logs. A browser is for what is only observable rendered — layout, interaction, hydration. (why: rationale.md#browser-cost)
- **Ask before starting a browser session for verification** unless I asked you to drive, run, or screenshot the app ("confirm this works" is not that); say why the browser is necessary. Take the fewest snapshots that answer the question, targeted queries over full-page dumps, and close it when done.
- **Run ephemera never land in the worktree.** Browser profiles, driver scripts, dev-server logs/pids, screenshots, and probe outputs go in the session scratchpad (or `/tmp/<task>/`), never in the repo, gitignored or not; delete them when the run ends. What's worth keeping goes in the report or memory, not a leftover folder. (why: rationale.md#run-ephemera)

## 10. React: reach for useEffect last

Don't sync state with `useEffect`. Derive from state/props inline or with `useMemo`; fetch with a query/loader; handle user actions in event handlers; reset state with a `key`. A genuine effect (one-time sync with an external system) gets a comment saying why. `/no-use-effect` audits a branch against the full policy.

## 11. Entropy control

(why: rationale.md#entropy)

- Follow the codebase's existing pattern, even when you'd do it differently. Never add a competing one: if yours is genuinely better, say so and migrate fully, or don't introduce it. If the task needs a pattern the codebase lacks, name it and ask.
- Name an awkward fit your change forces (a hack, a parameter threaded through layers, a special case) in your summary.
- A deliberate simplification with a known ceiling carries a greppable marker: `// simplified: <ceiling>. upgrade when: <observable trigger>` (in the language's comment syntax). No observable trigger, rejected at review.
- **A tactical mitigation is labeled as one** and never replaces or claims to be the root-cause fix. If the foundation is out of scope, stop and align rather than stack knobs (batch shrinks, timeouts, page cuts) that leave the worst case broken.
- Leave what you touch no worse: no commented-out blocks, no TODOs without an owner (§3 bounds how far cleanup reaches).
- A violation class that keeps recurring graduates into a standing check (lint rule, CI script); one-off findings stay findings.

## 12. UI/UX: intentional information, zero duplication

The default audience is a non-technical user. (why: rationale.md#ui-drift)

- Every element maps to a decision or action that user takes; if you can't name who needs it and why, cut it — a collapsed panel is still an element.
- A fact appears in exactly one place per view (§5 applied to pixels).
- Technical facts (raw IDs, hashes, enum codes) never sit inline in a user screen; demote them structurally (drawer, tooltip, admin gate), enforced like permissions.
- Labels use the user's word for their task, never the data model's. Record names, enum codes, and codenames appear only on provenance/technical surfaces; a reference carries the user-facing description, the raw ID only as a supplementary field when genuinely needed.
- Tabs and sections over one long scroll; secondary content is progressively disclosed.
- Refine the screen; don't mint a parallel one. No second route or `-v2` component for the same data; a genuine A/B names the date it collapses back to one.

## 13. Documentation: only what code cannot say

Code is the source of truth. A doc earns its place only if an agent with full read access to the code and no docs would otherwise make a wrong decision.

- A doc states a rule that must keep being observed (a decision procedure, a cross-file invariant, a hazard, a rejected alternative) or a north star the team is steering toward. Write the rule, not the instance.
- A doc never states what the code does: no inventories, walkthroughs, status, or history. Reusable runbooks and test procedures no script encodes are legitimate.
- One owner per fact; a doc that disagrees with the code is fixed toward the code.
- Plans are local and temporary: gitignored, never committed, folded into the owning doc at closeout only where they pass this bar.
- No backlog in a repo: work goes to the issue tracker; a located gap gets §11's `simplified:` marker.
- Adding prose means removing prose.

## Plugin usage

Use plugins or plugin-provided skills only when I request the plugin or skill by name; default to built-in/local tools and repository context. I often run tools such as CodeRabbit separately.
