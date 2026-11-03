# CodeRabbit

Read before requesting a second review, running the CLI, or handling a rate-limited PR review; `git-operations.md` points here.

- **CodeRabbit: PR review is primary, one round on the opening push.** Each repo's `.coderabbit.yaml` enforces it with `reviews.auto_review.auto_incremental_review: false`. A second review only when you judge the fixes critical: propose it, and run it on my yes. Do not require a CLI review before the first push or add a routine CLI pass at the end when PR review is available. For final review, the CLI is a fallback only when PR review is unavailable or limited; report the reason, reviewed scope and any uncovered scope. When PR review is rate limited, the PR decides: a complex one (an owner, a contract, money, auth, data writes, or a large diff) waits for the window, then `@coderabbitai review`; a moderate one gets one CLI pass; a simple one (a few lines, no behaviour change, gate green) gets neither. Ambiguous: ask me. Always `--deep` for a CLI review (without it the CLI runs a lighter policy):
  `coderabbit review --deep --committed --base origin/<default> --agent -c ~/Development/developer-config/coderabbit/tests.path-instructions.yaml AGENTS.md`.
  Triage findings as PR findings (why: rationale.md#coderabbit). A first push into an empty repo has no base to diff, so skip it and say so. No CLI: say so in the report.
