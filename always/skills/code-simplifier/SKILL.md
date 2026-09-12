---
name: code-simplifier
description: Reviews a diff for simplification — deletion, unification, and removal of speculative or defensive surface — while preserving behavior. Use when invoked by the rev/longrun workflows or when the user explicitly requests a code-simplification pass.
---

# Code Simplifier

Review the diff as a skeptical senior reviewer. The engineering principles are
the rubric — §2 simplicity, §3 surgical changes, §5 canonical sources, §6 fail
loud; this skill adds only the review lenses agent-written code systematically
needs. Never change behavior: every applied finding must keep the project's
full verification battery green.

Scope is the diff under review (plus pre-existing code it makes obsolete), not
the wider repo, unless explicitly directed otherwise.

Apply these lenses, in order of value:

1. **Delete first.** What can be removed — in the diff, or pre-existing code
   the diff obsoletes? A good pass often shrinks the branch net-negative.
2. **Unify.** Does new code reimplement something with an existing canonical
   owner (helper, validator, type, constant)? Reuse or extend the owner; never
   leave a second one standing.
3. **Remove speculative surface.** Unused parameters, single-caller config,
   exports nothing imports, generics with one instantiation, handling for
   states that cannot occur. Test: delete it — does anything break?
4. **Audit defensive code.** Swallowing try/catch, silent fallbacks, null
   checks against internal guarantees → replace with loud failure or delete.
5. **Simplify structure.** Guard clauses over nesting; inline pass-through
   indirection. Reduce complexity by simplifying logic, never by
   redistributing it — splitting one hard function into wrappers to lower a
   complexity score is a regression, not a finding.

## Finding grammar

One line per finding, then its disposition (below): `<path>:<line>: <tag>: <what>. <replacement>.`

| Tag | Fires on | Replacement |
|-----|----------|-------------|
| `delete:` | dead or speculative code | nothing |
| `reuse:` | logic the codebase already owns elsewhere | name the owner |
| `stdlib:` | a hand-rolled thing the stdlib ships | name the function |
| `native:` | a dependency doing what the platform already does | name the feature |
| `yagni:` | an abstraction with one implementation, config nobody sets, a layer with one caller — investigate; a boundary may still earn its place | the inlined form, or keep with reason |
| `shrink:` | the same logic in fewer lines | show the shorter form |

❌ "This deepClone helper might be more complex than necessary, have you considered…"
✅ `src/util/clone.ts:12-38: stdlib: 27-line recursive deepClone. structuredClone(value), same semantics for the plain-data inputs it receives.`

Also flag any `simplified:` marker (principles §11) that lacks an
`upgrade when:` trigger.

Give each finding a disposition, matching repo complexity gates where present:
**simplify** (apply it), **keep-with-reason** (the complexity is cohesive; say
why), or **escalate** (warrants an investigation brief, not an inline refactor).

"No findings — the diff is already minimal" is a first-class, successful
result. Do not manufacture findings.
