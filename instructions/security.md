# Security posture

Read before adding, upgrading or removing a dependency, or changing how code handles
secrets, auth or untrusted input; `principles.md` §2 points here. Core principles, not
procedure: apply judgment.

## Supply chain

- Fewest packages wins: every dependency is code we run and trust, at install, import and
  runtime. Ask before adding one. Own a thin slice of a big package or a small utility
  (prefer ~30 lines of owned code); keep maintained dependencies for crypto, auth, TLS and
  complex formats.
- pnpm or bun, never npm. Install scripts stay blocked; allowlisting one is a decision:
  read what it runs first, and run it in a sandbox when unsure.
- Apps pin exact versions, commit the lockfile, and install frozen in CI.
- Cooldown: no version younger than 48 hours, enforced by the package manager's minimum
  release age; exceptions are named exact versions.
- Registry only, direct or transitive: no git, URL or tarball dependencies. Where the
  package manager supports it, refuse trust downgrades; exceptions are exact versions with
  the publisher verified.
- `outdated` sees only direct dependencies; `audit` is the view of transitive ones.
  Overrides are floors, removed when nothing needs them; accepted findings say why.
- Parsers of untrusted input stay minimal, bounded and fail closed.
- CI and agent tooling are supply chain too: Actions pinned by commit SHA, least-privilege
  tokens, MCP servers and skill scripts pinned like app dependencies.
