# Verifier brief

You did not write this candidate. Try to refute it from repository source.
Adapted from the candidate-verifier prompt in Cloudflare's security-audit
skill. One verifier, one candidate; never show a verifier another verifier's
conclusion.

## Hard limits

The hunter brief's limits apply. Reading installed package source is allowed
and encouraged when a library's behaviour is decisive.

## Steps

1. Read the candidate in the hunter's result file. Treat it as a claim.
2. Re-read every cited location. Confirm the first step is an entry point the
   named principal can really reach and the last is the claimed effect.
3. Reconstruct the strongest control on the path: identity, authorization,
   validation, lifecycle, framework or library behaviour, a second layer
   elsewhere (a transition guard, a later review step, a role check in a shared
   owner). Look for the control the hunter missed: read callers, siblings, and
   the owning doc.
4. Check whether the repo's docs declare the behaviour intended, and whether
   an intended path already lets the same principal cause the same result (the
   candidate then adds nothing: reject it and keep any residual as hardening).
   A documented decision is not a vulnerability: cite the line. Two documented rulings that
   disagree, or an undocumented behaviour that moves money or authority, is
   `needs-decision`.
5. Decide `confirmed`, `needs-check`, `needs-decision`, or `rejected`, per the
   skill's state table. Severity and likelihood match only what the evidence
   shows. `needs-check` names one fact and one check, and is never a parking
   place for a speculative idea.
6. Test the proposed fix as hard as the claim: is it complete at that owner,
   does a helper already exist, is deleting the hazard simpler than guarding it?
7. Mark each step `[read]` or `[inferred]`. Do not confirm on an inferred
   decisive step.

## Result file

```
# Verifier <id>: <fingerprint>
- decision, severity (confirmed only), confidence 1-10:
- principal and preconditions:
- trace (corrected):
- controls found on the path, and whether each stops it:
- documented intent (doc `path:line`), if any:
- concrete result and blast radius:
- what the hunter got wrong or overstated:
- outside fact and owner check (needs-check only):
- fix: owner, invariant, rough size, clear-cut or needs a decision (options in a
  line each)
- regression test: what it asserts and which existing suite it extends
```

Return only a compact summary: decision, severity, confidence, the one fact
that decided it, the fix in a sentence, and the result-file path.
