# Comment rubric

Adapted from cursor/pstack `comment-sicko`. The goal is the ideal state, not a
kill count: a comment that carries a rule the code cannot express stays,
corrected if needed. Deleting load-bearing knowledge is a failure.

Calibration appends this repo's exceptions under "Repo exceptions" in the
run's working copy; the copy, not this file, is the finders' standard.

## Keep

1. Legal and license headers.
2. Non-obvious behavior forced by something we cannot reshape — a runtime
   limit, vendor API, protocol, framework, browser — true today on a live
   path. A surprise in our own code is not an exception: shrink the prose and
   log a symptom naming the reshape (rename, extract, type) that would make
   the code say it.
3. Doc comments defining a contract a caller must honor (preconditions,
   invariants, units, the meaning of a tri-state) — not ones restating the
   name or signature. `@deprecated` stays.
4. Issue or RFC links explaining a constraint the code cannot express.
5. `simplified: <ceiling>. upgrade when: <trigger>` markers.
6. Migration docstrings and shim removal conditions: what/why, remaining
   operator steps, the observable fact that ends the shim.
7. An ownership decision or cross-file invariant the code cannot make clear
   ("X is the only writer of Y", "must change in lockstep with Z").
8. In tests, the regression a test catches and why it matters.

## Never touch

- Lint and type suppressions and their reasons. Report bad ones as symptoms.
- Machine-read markers: comments a script, lint rule, or test parses —
  typically an ALL_CAPS token followed by a colon. When unsure, grep the
  scripts and lint rules for the token.
- Pragmas and directives: shebangs, `@jsxImportSource`, triple-slash
  references, environment and coverage pragmas, bundler magic comments.
- Code. Comment text only — never a token of code, an import, a type, or a
  string.

## Delete (no report needed)

Narration of the next line; banners; commented-out code; restated names,
types, or params; history ("previously", "replaces the old", versions, SHAs);
deploy or status prose; TODOs without an owner and issue; references to
plans, phases, passes, findings, or decision IDs nothing in the repo defines;
the same contract repeated at call sites (keep it once, at the owner).

## Stale or wrong (highest value)

A claim false against today's code — a missing symbol, the wrong owner, the
wrong behavior, a drifted list. If the rule is real and passes a keep
exception, rewrite it true and short; otherwise delete. A hand-kept list that
duplicates an owner in code: delete it, or leave a one-line pointer to the
owner.

## Confessions are symptoms

A long justification for a workaround in our own code, "IMPORTANT" or "do not
remove", a known ceiling as prose, an effect justified by prose: these point
at a code problem. Shrink or delete the prose and log the code problem as a
symptom. Never polish a confession into a shorter alibi, and never fix code in
the comment pass.

## Repo exceptions

(Filled by calibration.)
