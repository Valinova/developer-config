// playwright-walk.mjs — shared runtime for scripted browser walks (agent-driven
// verification against a local dev server) from any harness — Claude, Codex, Pi,
// Grok, Hermes. Not the Playwright MCP: that one is the per-session `claude-pw`
// opt-in (SETUP.md "MCP servers load on demand"); this is for walks written as
// short Node scripts.
//
// Contract:
//   - Playwright comes from the machine's global pnpm install
//     (`pnpm add -g playwright@<pin> && playwright install chromium`, SETUP.md).
//     No repo ever adds it as a dependency for walks.
//   - Every artifact of a walk (profile, screenshots, logs, scripts) lives in one
//     dir outside any repo: `dir` (e.g. the session scratchpad), else $WALK_DIR,
//     else /tmp/walk-<task>/. Delete it when the walk ends.
//   - Headless by default. Headed only when the caller passes { headed: true }
//     or WALK_HEADED=1, i.e. when the user asked to watch.
//   - One persistent context per task, reused across scripts, so sign-in
//     cookies and app state survive between steps.
//
// Usage (from any script):
//   const { openWalk } = await import(pathToFileURL(`${os.homedir()}/Development/developer-config/always/scripts/lib/playwright-walk.mjs`).href)
//   (the repo clone path is the same on every machine; nothing links this file)
//   const walk = await openWalk({ task: 'ctxbd-smoke' })
//   await walk.page.goto('http://localhost:7777/sign-in')
//   await walk.shot('signin')            // -> /tmp/walk-ctxbd-smoke/signin.png
//   await walk.close()

import { execFileSync } from 'node:child_process'
import { mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

export function walkDir(task, base = process.env.WALK_DIR) {
  if (!/^[a-z0-9][a-z0-9-]*$/i.test(task)) throw new Error(`walk task must be a slug, got ${task}`)
  const dir = join(base || '/tmp', `walk-${task}`)
  mkdirSync(dir, { recursive: true })
  return dir
}

export function resolveGlobalPlaywright() {
  const listing = JSON.parse(
    // Run outside the caller's repo: a project packageManager pin makes pnpm print a
    // warning onto stdout ahead of the JSON.
    execFileSync('pnpm', ['ls', '-g', '--long', '--json', 'playwright'], { encoding: 'utf8', cwd: tmpdir() })
  )
  const pkg = listing?.[0]?.dependencies?.playwright
  if (!pkg?.path) {
    throw new Error('playwright is not installed globally; run the pinned install command in developer-config SETUP.md')
  }
  return join(pkg.path, 'index.mjs')
}

export async function openWalk({ task, dir: base, headed = process.env.WALK_HEADED === '1', viewport = { width: 1440, height: 900 } }) {
  const dir = walkDir(task, base)
  const { chromium } = await import(pathToFileURL(resolveGlobalPlaywright()).href)
  const context = await chromium.launchPersistentContext(join(dir, 'profile'), {
    headless: !headed,
    viewport,
    args: ['--password-store=basic']
  })
  const page = context.pages()[0] ?? (await context.newPage())
  return {
    dir,
    context,
    page,
    shot: (name) => page.screenshot({ path: join(dir, `${name}.png`), fullPage: false }),
    close: () => context.close()
  }
}
