# Engineering principles

Applies to every project and every agent. Follow them on every piece of work;
when a real constraint forces a deviation, name it where it happens.
Project-level `AGENTS.md` / `CLAUDE.md` overrides or extends these. The
reasoning and incident history behind a rule live in
`~/Development/developer-config/instructions/rationale.md` (not loaded);
`(why: rationale.md#…)` points at the entry.

## 1. Think before coding

- When the ask is genuinely ambiguous, present the interpretations and ask. Trivial ambiguity gets a stated default, not a question. When one option is clearly right, take it and state it; reserve questions for genuine judgment calls where the trade-off is mine to weigh (the interactive mirror of §4's escalation bar).
- If a simpler approach exists than the one asked for, say so before implementing.
- For exploratory questions ("what could we do?"), give 2–3 sentences with a recommendation and the main tradeoff. Don't implement until they agree.
- **Ideation and planning are visual-first.** When explaining a flow, architecture, or set of options to me, lead with a diagram (ASCII or mermaid, whatever the medium renders) plus concise prose. Decision material is explicit trade-offs, stated objectively, so the judgment is mine. LLM-facing implementation documents use whatever format the consuming agent reads best.

## 2. Simplicity first

- Write the minimum code that solves the stated problem: no features, abstractions, config surfaces, or error handling for scenarios not asked for or that can't happen; validate only at real boundaries (user input, external APIs). Minimal scope is not minimal quality — what gets cut is unused surface, not craft.
- **Lock shape early, build behaviour late.** When fixing a contract (a schema, an API, a stored record), decide now what is expensive to change later — field names, keys, identity, edges, the slot a future behaviour fills — and ship those in their smallest form, empty if need be. Build the behaviour only when evidence asks for it. A reserved slot is not speculation; a built behaviour with no consumer is. Reviewer test: can the next change refine this without a migration?
- Never hardcode values unless explicitly told to; take them from config or the caller. (why: rationale.md#simplicity)
- Don't suppress type errors with `any` or `@ts-ignore`; fix the real type (`unknown` with guards, proper types, generics).
- Reduce complexity by simplifying logic, never by redistributing it. Splitting one hard function into pass-through wrappers is a regression, whatever the lint score says.
- Don't add a dependency without asking — prefer ~30 lines of owned code over a small package. Any package added must be at least 48 hours old (the bun/pnpm minimum-release-age cooldown should enforce this; verify it applies rather than assuming).

### The decision ladder

Once the problem is understood and the behaviour is needed, take the first option that satisfies the contract: an existing owner in this codebase → stdlib → native platform feature (HTML element, CSS, DB constraint) → an already-installed dependency → the logic written plainly → only then minimum custom code.

## 3. Surgical changes

- Every changed line traces to the user's request. Don't "improve" adjacent code, formatting, or comments.
- Remove orphans YOUR change created (unused imports, variables). Don't delete pre-existing dead code unless asked — mention it if you notice it.
- Don't rename, re-export, or add back-compat shims for code you've removed. Just delete it.

### Parallel work in the worktree

I often work in parallel in the same worktree. Uncommitted changes that don't trace to your task are usually MINE and intentional — never revert, restore, stash, or delete them without asking, **even when they look like agent overreach or scope creep**. "This wasn't in the brief" means investigate, not discard. (why: rationale.md#parallel-worktree-wip)

- **Snapshot provenance before delegating.** Before dispatching any subagent (Codex etc.) that can touch the worktree, record `git status --porcelain` + `git diff HEAD --stat` (e.g. into `/tmp/<task>-predispatch.txt`). Anything present pre-dispatch is mine; only deltas beyond the snapshot are the agent's.
- **Provenance check before any revert.** Before `git restore` / `git checkout --` / unstaging anything, diff against the pre-dispatch snapshot. No snapshot → assume it's mine and ask.
- If a fix genuinely requires touching a file that carries my parallel WIP, stop and ask — don't "clean it up" to make your diff tidy.
- **Proposals.** When a leaf or subagent hits something unclear or broken on its own path and sees a fix outside its scope, it never silently edits the tree. It records the proposal in a labeled place — the `OUT_OF_SCOPE_FINDINGS` block of its SUMMARY (`codex-delegation.md`), or a patch file in its scratch dir named in that block — so my WIP and agent suggestions stay distinguishable. Nothing lands until I apply it. Trigger is §8's blast-radius bar: a finding with none is idle-pass output. (why: rationale.md#agent-proposals)
- If you do discard something by mistake, attempt recovery before reporting it lost: staged-then-discarded content usually survives as an unreachable blob (`git fsck --unreachable`, or the blob hash from any diff header you printed).

## 4. Goal-driven execution

- For multi-step work, state a brief plan with a verification check per step, then loop against it. Success criteria must be strong enough to iterate against without check-ins.
- **Escalation bar (autonomous workflows):** under granted autonomy (execute-plan, rev, longrun, delegated runs), escalate to me only decisions that cannot be established from the request, the code, or the plan AND would be costly to undo if wrong — and lead with a recommendation and the key tradeoff. Everything else: take the best-supported default and record it in the final report. A decision the cross-family reviewer agrees with is made, not deferred. (§1's ask-first stance governs interactive work; this bar governs granted autonomy.)
- **Pre-commit gate: run the project's FULL verification battery, not the quick loop.** Before EVERY commit, run the project's full check command (e.g. `pnpm run check` or full `lint`). Quick linters skip the custom/architecture rules; the quick loop is for mid-edit iteration only. (why: rationale.md#pre-commit-gate)

### Tests: value, not coverage

- A test earns its place only if it would catch a real regression; coverage percentage means nothing. Prove the production failure path and the non-regression that matters, nothing more. Shared test-harness or mock edits need at least one **consumer** suite outside the original happy path.
- **Less test, more coverage — the shapes to refuse** (why: rationale.md#test-shapes):
  - *Derive, don't mirror.* Expectations come from the canonical owner/config; never re-type a roster, enum, prompt sentence, byte size, CSS class, or log string as a literal. Assert the invariant (closure, membership, partition, gating), not the text. Only a self-declared drift pin with no importable owner may be literal.
  - *Mock boundaries, run owners.* Mock only real process boundaries (DB/HTTP/SDK/telemetry/router/i18n/timers); everything in-process runs real — no hand-rolled store/engine shims, no in-test reimplementation of a production rule. `toHaveBeenCalledWith` is contract testing against a boundary and theater against a pure function two imports away — judge the collaborator, not the matcher.
  - *Never assert a result against itself.* Totals vs their own components, `toEqual(canonicalBuilder(sameInput))`, determinism self-compares, fixture echo, in-test helpers tested by the same file. Hand-derive or table-drive a fixed expectation.
  - *One owner, one file; fold before minting.* New cases go in the existing file on that owner; a new test FILE needs a stated reason (different environment, incompatible hoisted mocks, separate owner). No PR/phase tokens in filenames; no regular/batch twins on one owner — table-drive with `describe` rows. Single-`it()` files are a smell by default.
  - *Table-drive repetition.* N near-identical `it()`s over one arranged result → `it.each` with titled rows.
  - *No source-text assertions.* `readFileSync` + `toContain`/regex over production source executes nothing. Drift guards are lint rules or render assertions, not tests.
- **Plan-time rule (agentplan / execute-plan / longrun).** Each phase names its minimal test set and the owner + failure path each test proves. "No new test — covered by <file>" is a valid, stated answer. A new test *file* is justified in the plan or it does not ship. Reviewers reject the six shapes above at phase review, not at the next audit.

### Ship gate: beneficial + no open regression (plan and finalize)

At **planning** and again when **finalizing** (ready PR / merge recommendation), name the real benefit (not theater or metric cosmetics) and the surfaces it could regress (shared mocks, list universes, sibling callers, public contracts).

**Do not ship with a known regression** — close it in the same change, or stop and replan. If residual risk is real and still accepted (rare, explicit), the plan and the PR/brief state **why** it was accepted, **how** it is tested (a browser smoke when the risk is UI-only — §9), and **how** we know nothing regressed (named suite, check command, or smoke path).

Repo foundation docs (e.g. `docs/architecture/*.md`) define the shape the fix must live in — simplest solution inside that shape.

## 5. Canonical sources of truth

- Every business rule, constant, derived value, type, or mutable fact has exactly ONE implementation owner. Other consumers derive from or reference that owner — never a hand-maintained duplicate. Find the owner before writing new logic; if none exists, create it and document it.
- Caches, projections, and summaries are allowed only as mechanical derivatives of the canonical source — never as alternate owners of the same fact.
- If you spot a second owner of a fact, remove it — don't add a third to "fix" the inconsistency.
- A bug fix is the root cause. Before changing a shared owner, inspect every caller and verify the affected sibling paths; put the fix where the violated invariant belongs. Patching only the ticket's path leaves the siblings broken.

## 6. Fail loud, not silently

- Don't add fallback logic unless the scenario genuinely warrants it; when in doubt, ask. Default to throwing a loud, typed error over catching-and-continuing. (why: rationale.md#fail-loud)
- Destructive operations on real data (migrations, bulk `DELETE`/`UPDATE`, overwriting files outside the repo) get the same ask-first treatment as backstop-listed git ops: in any questionable circumstance, check with me and validate before running.
- **Selection and coverage follow domain/semantic boundaries** (time window, watermark, dependency state, all matching records) — never arbitrary numeric item/pass/time quotas. Numeric ceilings are allowed only as explicitly labeled runaway/cost circuit breakers; when one trips, stop loudly and preserve prior work rather than silently truncating or calling partial work complete.

## 7. Branch, worktree & commit management

Git, branch, worktree, and commit operations — permissions, the backstop hook, commit hygiene, rebase policy — are owned by `instructions/git-operations.md`; durable worktree layout by `instructions/durable-worktrees.md`. Read it before any git write. The invariant that stays here: **explicit direction IS the approval; anything unrecoverable requires my approval.**

## 8. High-value bias (80/20)

- If 20% of the effort captures 80% of the value, that is the intended default scope. Go for the full solution only when the foundation genuinely needs it (entropy at scale, canonical-owner consolidation, regression safety on critical paths).
- Every proposed piece of work names its blast radius — what breaks or degrades if it isn't done. No blast radius, no work item. (why: rationale.md#idle-pass)
- Size a fix to the code's remaining life. A one-shot migration, tear-down, or backfill that runs once and is then deleted gets the smallest shape that completes that run; permanent indexes, general contracts, and proof systems are for code that stays. A subagent's recommendation is input to this sizing, never the plan.

## 9. Verify cheap first — ask before driving a browser

- A browser session is expensive; climb the ladder first: typecheck → unit/integration tests → read the code path → curl the endpoint or check server logs. Escalate to a real browser only when the thing under test is genuinely browser-only — a visual/layout bug, an interaction (click/hover/drag) flow, hydration, something observable only when rendered. (why: rationale.md#browser-cost)
- **Ask before starting a browser session** for verification unless I explicitly asked you to drive, run, or screenshot the app. "Confirm this works" does not mean Playwright — say what you'll do and why the browser is the necessary medium.
- When you do use it: the fewest snapshots/screenshots that answer the question, targeted queries over full-page dumps, and close the browser when done.

## 10. React: reach for useEffect last

When writing React, don't sync state with `useEffect`. Derive from state/props inline or with `useMemo`; fetch with a query/loader; respond to user actions in event handlers; reset state with a `key` prop. A genuine effect — one-time sync with an external system — is the rare exception; when you write one, comment why. Run `/no-use-effect` to audit a branch against the full policy.

## 11. Entropy control

(why: rationale.md#entropy)

- Follow the codebase's existing pattern, even when you'd do it differently. Don't introduce a second competing pattern for something that already has one — if the new way is genuinely better, say so and migrate fully, or don't introduce it. If the task seems to demand a pattern the codebase doesn't have, name it and ask.
- When your change forces an awkward fit — a hack, a parameter threaded through layers, a special case — name it in your summary instead of burying it.
- A deliberate simplification with a known ceiling carries a greppable marker, in the language's comment syntax: `// simplified: <ceiling>. upgrade when: <observable trigger>`. A marker with no observable trigger is rejected at review.
- **Tactical mitigations are allowed only when labeled as such** and never as a substitute for the canonical fix. Auto/agent pipelines do not ship unlabeled band-aids as "root cause eliminated." If the foundation is out of scope, stop and align rather than stacking knobs (batch shrinks, timeouts, page cuts) that leave the worst-case path broken.
- Leave what you touch no worse than you found it: no commented-out blocks, no TODOs without an owner. (§3 bounds how far cleanup may reach.)
- A violation class that keeps recurring graduates into a standing check (lint rule, CI script) so it never has to be found by hand again. One-off findings stay findings.

## 12. UI/UX: intentional information, zero duplication

The default audience is a non-technical user. (why: rationale.md#ui-drift)

- Every element maps to a decision or action that user takes. If you can't name who needs it and what they do with it, cut it — a collapsed panel is still an element.
- A fact appears in exactly one place per view — never repeated across a header, a card, and a table (§5's canonical-owner rule applied to pixels).
- A technical fact (raw ID, hash, enum code) never earns inline placement in a user screen; demote it structurally (drawer, tooltip, admin gate) and enforce the demotion the way permissions are enforced.
- Every visible label uses the user's word for their task, never the data model's. Record names, enum codes, and internal codenames appear only in provenance/technical surfaces; references carry the user-facing description, with the raw ID as a supplementary field only when genuinely needed.
- Organized tabs and sections over one long scroll; secondary content is progressively disclosed.
- Refine the screen; don't mint a parallel one. No second route or `-v2` component rendering the same data; a genuine A/B names the date it collapses back to one.

## Plugin usage

Use plugins or plugin-provided skills only when I request the plugin or skill by name; default to built-in/local tools and repository context. I often run tools such as CodeRabbit separately.
