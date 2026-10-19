---
name: browser-test
description: How to check a web app in a real browser efficiently — verifying a feature you built, walking a flow, reading rendered values, or taking a layout screenshot. Use whenever a change needs a browser to confirm, or when the user explicitly invokes "browser test".
---

# Browser test

Cheaper checks come first; browser authority is in `principles.md` §9.
[Testing policy](../../../instructions/testing.md#pr-proof-and-regression-scenarios)
owns scenario selection, fixed outcomes and proof evidence: browser-visible PR
outcomes need rendered proof even when calculations can be checked below the UI.
Do the walk yourself; delegate it only when it is long enough to bury your context.

## What you need

- The app running locally, and its URL. Start the dev server yourself only when nothing serves it, and stop what you started.
- A test login from the repo's env, named in its `AGENTS.md`. If signing in would need the user's hands (no test credentials, MFA, captcha), stop and say the repo is missing an agent login path; don't work around it.
- `agent-browser` and global `playwright`, installed by developer-config. Read `agent-browser skills get core` once per session for command syntax; it matches the installed version.
- One scratch dir outside the repo for snapshots, state files, screenshots and scripts. Delete it when done.

## How

1. **Headless, one named session per task** (`--session <task>`), never the default session: parallel agents on the default session silently take over each other's browser.
2. **Sign in from env vars** (`"$TEST_EMAIL"`), never a typed literal, and never print a secret. Keep the session alive for the whole task instead of reloading saved state: a state file only applies when the session starts.
3. **Snapshot to a file, grep it.** `snapshot -i > "$scratch/snap.txt"`, then grep for the element or value you need. Never read a full page snapshot inline.
4. **Re-snapshot after every page change.** Refs go stale when lists or tables re-render; take a fresh snapshot instead of retrying a ref. If a click is refused because something covers the target (a panel, a toast, a floating button), dismiss the cover; never force the click.
5. **Read values, not pixels.** Assert on text, counts and statuses from the snapshot. Screenshot only for layout, with the viewport set explicitly (desktop, and 390 px wide for mobile).
6. **Script the rerun.** When the same flow will run again (a fix → recheck loop), needs loops or assertions, or must run beside another browser, turn the walk into a short Node script over `~/Development/developer-config/always/scripts/lib/playwright-walk.mjs`. A rerun is then one call.
7. **Playwright MCP is the last resort:** only when the harness has no shell, or the user wants to watch a headed browser (`claude-pw-headed`).

## Data

Read and navigate by default. Submit, approve or delete only when that write is what you are testing and the repo's guidance says the environment is safe for it; repo hazards (such as a dev deployment wired to a real external system) override this skill.

## Finish

Close the session, stop every process you started (by PID, never by pattern), and delete the scratch dir. If running the app modified tracked files, report them; don't restore files you can't prove you changed. Report proof under the testing policy, including any console errors.
