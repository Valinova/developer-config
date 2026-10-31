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
  read what it runs first, and run it in a sandbox when unsure. In bun that takes
  `trustedDependencies: []`; absent, bun runs scripts for its built-in trusted list.
- Apps pin exact versions, commit the lockfile, and install frozen in CI.
- Cooldown: no version younger than 48 hours, enforced by the package manager's minimum
  release age; exceptions are named exact versions.
- Registry only, direct or transitive: no git, URL or tarball dependencies. Refuse trust
  downgrades where supported; exceptions are exact versions with the publisher verified.
  bun refuses neither, so a bun repo fails its gate and root `postinstall` on any
  non-registry `bun.lock` entry, and the cooldown is its only trust-downgrade cover.
- `outdated` sees only direct dependencies; `audit` is the view of transitive ones.
  Overrides are floors, removed when nothing needs them; accepted findings say why.
- Parsers of untrusted input stay minimal, bounded and fail closed.
- CI and agent tooling are supply chain too: Actions pinned by commit SHA, least-privilege
  tokens, MCP servers and skill scripts pinned like app dependencies.

## Browser runtimes

Browser engine CVEs are frequent and severe; a page that exploits a stale engine
runs with the agent's host permissions.

- A browser that reaches anything beyond localhost drives the system Google Chrome
  (Playwright `channel: 'chrome'`, Hermes `AGENT_BROWSER_EXECUTABLE_PATH`), which
  its updater keeps patched. Never point it at a bundled Chromium.
- A bundled Chromium is for localhost tests only; it follows the project's
  Playwright version, bumped under the cooldown above.
- A stale copy is dangerous only when launched: `playwright uninstall` (global
  install) removes every Playwright browser no installed project still references.
- Audit on a Playwright bump or new machine: confirm each external-facing launcher
  resolves to system Chrome (`agent-browser doctor` with no fallback listed, Playwright
  MCP default, walk `channel: 'chrome'`, Hermes `AGENT_BROWSER_EXECUTABLE_PATH` where
  installed) and that Chrome's updater is current; delete stray Chromium outside
  Playwright's store (`~/.cache/puppeteer`, `~/.hermes/tools/chromium-*`, snap/apt
  `chromium`); then `playwright uninstall`.
