---
name: ci-speed
description: Makes a repo's CI and test suite faster and lighter without making them less truthful. Audits where the time goes from real runs, then ships the levers that pay, one small PR each with before and after numbers. Use when the user explicitly invokes "ci speed" or asks to speed up, slim down or audit a repo's CI or test runs. Not for changing when checks run or which are required, and not a flake hunt on its own (the repo's test audit owns that).
---

# CI speed

Faster, never less truthful: no retries, no wider timeouts, no skipped tests, no
selection that can hide a real change. When checks run and which are required
stay as they are unless the user asks. Measuring and local runs need no asking;
commits, pushes and PRs follow `git-operations.md`.

```
measure real runs ──► biggest bucket ──► one lever, one PR ──► measure again in CI
waiting | setup | running               reject on numbers        before and after in the PR
```

## Rules

- **Numbers decide.** A lever ships with before and after from real CI runs,
  and is dropped the same way. Local timings choose what to try; they are not
  the result (CI starts with cold caches).
- **Compare summed job time as well as wall time.** A shard buys wall time and
  pays a setup; the sum is the bill.
- **Read one job's log end to end before trusting step names.** The cost is
  often inside a step: an install that re-verifies the lockfile, a cache that
  misses on every pull request.
- **Replay a selection scheme before adopting it.** Run "only what the diff
  reaches" over the last 100 merged PRs and report the median share of test
  files still run, plus every input it cannot see (SQL, config, scripts). A
  connected import graph makes it pay little.
- **Run the repo's gate again after committing.** Guards that compare commits
  (a test-size ratchet, a changed-files check) see nothing while the change is
  uncommitted.
- **Bring the user only what is theirs:** a bigger bill (runners, shards), a
  tool swap, required checks or a merge queue, and any repo rule the lever
  breaks. Lead the PR with the last one.

## 1. Measure

`node run-timings.mjs "<workflow>" 150` from the repo root (needs `gh`): per
job, time waiting for a runner and every step at p50 and p95; per run, wall
time and summed job time. Sort steps into setup and real work yourself. Pull
failing tests from recent failed runs too (`gh run view <id> --log-failed`): a
test that fails on several unrelated branches the same day is a flake or a
broken base, and either changes what "faster" is worth.

## 2. Setup levers

- A pull request restores caches only from its own branch or the base branch.
  A workflow that never runs on the base branch never seeds them: add one that
  does, triggered by the files the cache keys hash.
- Cache what the package manager recomputes per job, keyed on every input it
  reads, and prove the key: change one input and watch it recompute.
- One shared setup action, so jobs cannot drift apart.
- Rebalance the shard matrix from measured step times before adding shards.

## 3. Test levers (Vitest)

Read the `Duration` line first. When import time dominates, every file is
reloading the same packages, and the lever is sharing a worker between files
(`isolate: false`), not selection and not stubbing the heavy packages (stubs
break files that mock them and are a hand-kept copy).

A process per file hides everything a file leaves behind. To share workers:

1. **Census, before changing anything.** `vitest/leaks.sh census` runs the
   suite as it is today and lists what each file leaves: pending timers, work
   still running, and worker state (fake timers, environment variables,
   replaced globals, storage, DOM). Each class with files in it is one reset.
2. **One boundary setup file, first in `setupFiles`,** that gives a file what a
   new process gave it: reset modules, restore each class the census found,
   discard pending timers at file end, register DOM cleanup per test. Fix
   classes there, never file by file. A leftover the boundary cannot stop is
   async work a test started and did not await; fix that in the test or in the
   production code that floats the promise.
3. **Sweep.** `vitest/leaks.sh sweep <seeds>` runs every shard under shuffled
   file order. Also sweep the unsharded suite the way developers run it
   (`LEAKS_SHARDS=1`, their worker count); it finds failures shards do not.
4. **Bisect what fails.** `vitest/leaks.sh bisect <run>` gives the shortest
   chain of earlier files that breaks the failing file. A file that fails with
   no chain, or alone, has a race the repo already had: slow per-file start-up
   was winning it. Confirm by perturbing the old mode, then fix the test; say
   so in the PR.
5. **Proof bar:** 20 clean shuffled runs per shard and 8 of the unsharded
   suite, on the final code, then the first CI run. An unexplained failure is
   reported with its rate, never retried away.
6. **Memory.** Sample peak resident memory summed over the Vitest process tree
   in both modes, and at fewer workers: sharing can match the old speed with
   fewer workers and less memory. Count worker processes too; Vitest replaces
   a worker when consecutive files need different environments, so the saving
   is smaller than files divided by workers suggests.

## 4. Test problems the runs turn up

Test levers go best after the repo's test audit, when it has one: fewer tests
to move and fewer leftovers. Setup levers do not wait for it. This skill never
runs that audit and never hunts for test problems; it handles only what its
own runs surface, judged by the repo's test rules and `instructions/testing.md`:

- **Blocks the lever, or is clear-cut and test-only:** fixed in the same PR,
  one commit per fix, naming the failure it was seen causing (`principles.md`
  §3).
- **Needs a choice, touches production code, or is a class too wide for one
  pass:** an issue when it passes `instructions/issues.md`, otherwise a line
  in the report suggesting the test audit. Production changes never ride in a
  speed PR; its numbers must belong to the lever.
- **Never seen to cause anything:** the report only.

## Files

- `run-timings.mjs`: the CI audit in step 1.
- `vitest/leaks.sh`: `census`, `sweep`, `replay`, `bisect`; usage in its header.
  It loads the repo's own config through `vitest/leaks.config.mts` and needs
  nothing installed beyond the repo's Vitest. Written against Vitest 5.1; when
  a reporter or sequencer hook has moved in another major, fix the tool.
- Output goes to `/tmp/ci-speed-<repo>`, never the worktree.

## Report

End with CI wall time and summed job time before and after, peak memory before
and after, what was rejected and the number that rejected it, and the list of
decisions that are the user's, each with its cost.
