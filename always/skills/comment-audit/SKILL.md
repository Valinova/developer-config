---
name: comment-audit
description: Repo-wide comment audit that brings every comment to the ideal state, treats bad comments as symptoms of code problems, and delivers a comment-only PR, a stacked code-fix PR, root-cause issues, and owner decisions. Use only when the user explicitly invokes "comment audit" or "comment-audit". Not for a diff's comments (code-simplifier covers those).
---

# Comment Audit

A calibration step, then one audit that ships two stacked PRs, each through
longrun's closing stages. Comments are the symptom; the value is the wrong
claims fixed and the code problems they expose.

```
calibrate ─► edit + verify per shard ─► sort ─┬─► PR 1  comments only
                                              ├─► PR 2  list A fixes, stacked on PR 1
                                              ├─► issues, one per root cause (list B)
                                              └─► owner decisions in PR 1 (list C)
```

Seats come from `model-selection.md` "Harness seats": finders and
implementers at the execute seat, verifiers at the cross-family reviewer
seat. Invoking this skill authorizes the commits, cross-family verification,
`rev`, push, both PRs, filing the issues, and babysit's pushes. Branch
authority follows `git-operations.md`. Shard count is a judgment sized to the
repo; invoking this skill is the check-in "Subagent fan-out" requires above
eight. Pace concurrency to the machine; finders and verifiers run no suites.

## Files

- `rubric.md`: the standard. Copy it into the run directory, which is
  `{RUN}` in the briefs and lives in the scratchpad.
- `briefs.md`: finder, verifier, sorter, and implementer templates.
- `comment-only.cjs`: the JS/TS guard. It parses with its own pinned
  TypeScript (`pnpm install --dir` this folder once; TypeScript 7 has no JS
  parser API). For another language, build the
  equivalent comparison on that language's parser before stage 2. With no
  guard there is no comment-only PR: the guard is what makes a PR this size
  mergeable without line review.

## Stages

1. **Calibrate (report-only).** A few read-only agents apply the rubric to a
   sample of distinct areas and report keep rates and symptoms. Grep for what
   reads comments: scripts, lint rules, and tests that slice source text.
   Append those markers and the repo's own conventions to the run's rubric
   under "Repo exceptions". If the sample shows mostly sound comments and few
   symptoms, report that and stop.
2. **Edit and verify.** Shard the files that carry comments by area, with no
   file in two shards. Per shard, as soon as its finder returns: run the
   guard on the shard, run the verifier, then run the guard again. Never edit
   a shard in parallel with its verification.
3. **Sort.** One sorter produces lists A, B, and C (`briefs.md`). Close what
   principles §1 lets you decide and record each call for the PR.
4. **PR 1: comments only.** Commit by area. The gate: the guard against the
   base shows no code change beyond named intentional fixes; then the repo's
   full check plus the full unit suite, which matters because tests that
   slice source text can anchor on deleted comments. Re-anchor such a test on
   code; do not restore the comment. Push, open the PR with list C and the
   decisions taken, and babysit. CodeRabbit skips PRs above 300 files; the
   guard and the verifiers are the review.
5. **PR 2: code fixes.** Implement list A in lanes with exclusive file
   ownership, one commit per concern, each independently green. Run `rev`,
   then the gate. Open the PR against PR 1's branch and babysit. CI may run
   only after it retargets to the default branch.
6. **Issues.** File list B. Comment on existing issues rather than
   duplicating them, and link the issues from both PRs.

When PR 1 squash-merges, rebase PR 2 with `git rebase --onto <default> <PR 1
tip>`. First check that the squash commit's tree equals PR 1's tip, then
retarget PR 2.

## Hazards from the first run

- Opus over-deletes and over-claims. Across about 900 files, verification
  restored about 140 load-bearing comments and corrected about 115 rewrites.
  The verify stage is the product, not a formality.
- A finder will reach for scripted or whole-file rewrites. The guard catches
  code damage; read the shard diff for collateral formatting.
- Recurring classes (plan tags in titles, decision IDs) become a proposed
  standing check under principles §11, named in PR 1.

## Report

PR links; issues filed; decisions taken; decisions open; verification
counts (restored, corrected, refuted symptoms); the guard result; each gate
run with its outcome.
