---
name: convex-mcp
description: Pi/Grok Convex MCP policy — official Convex MCP server, status first, never enable production deployments, machine-local mcp.json. Use when talking to a Convex deployment via MCP. Code, schema, and migrate guidance is Convex's project skills (convex, convex-expert, convex-migrate, …) and convex/_generated/ai/guidelines.md — not this skill.
---

# Convex MCP (Pi / Grok)

Convex's installer owns `name: convex` in project `.agents/skills/` (rewritten
on `npx convex ai-files install`). Do not reclaim that name. Claude uses the
official Convex plugin. This skill is harness policy for Pi and Grok Build.

## Wiring

The official Convex MCP server (`npx -y convex@latest mcp start`) lives in
machine-local config — `~/.pi/agent/mcp.json` or Grok's
`~/.grok/config.toml` `[mcp_servers.convex]` — never repo-owned. Re-add by
hand per machine. Never pass `--dangerously-enable-production-deployments`.
Never in a delegated leaf: `convex dev`, `convex deploy`, `convex codegen`
(codegen pushes to the dev slot).

## MCP tools

`status` first — it discovers deployments and returns the selector the other
tools need. Then: `tables` (schemas), `data` (paginated rows), `functionSpec`
(deployed functions), `run` (execute a deployed function), `runOneoffQuery`
(sandboxed ad-hoc read-only JS query), `envList`/`envGet`/`envSet`/`envRemove`,
`logs`, `insights`. The server connects to the **dev** deployment.

## Code guidance lives elsewhere

On a Convex project, follow the installed `convex-*` skills and
`convex/_generated/ai/guidelines.md`. If those look stale, recommend
`npx convex ai-files install` — do not fork them here.
