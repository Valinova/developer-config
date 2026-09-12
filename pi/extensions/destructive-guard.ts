/**
 * destructive-guard.ts — mechanical backstop for UNRECOVERABLE operations (Pi).
 *
 * Scope is deliberately narrow: only operations whose damage cannot be undone.
 *   - rm with recursive/force flags outside the OS temp root, sudo rm in any
 *     form, find -delete
 *   - git reset --hard          (destroys uncommitted work)
 *   - git clean -f              (deletes untracked files)
 *   - git push --force / -f / --force-with-lease / --force-if-includes
 *                               (rewrites remote history)
 *
 * Policy: bare force-push (including +refspec) is denied in every mode.
 * Every other match prompts EVERY time in the TUI. There is no "remember",
 * no allowlist, no bypass flag, no equivalent of Claude's bypassPermissions
 * inert mode. Outside the TUI (`pi -p`, json, rpc) matches are hard-BLOCKED —
 * an agent running non-interactively cannot obtain approval, so it cannot run
 * the command at all. Re-run interactively to approve.
 *
 * Deliberately NOT guarded (recoverable, or governed by principles.md §7
 * doctrine instead of mechanics):
 *   plain `rm <file>` (tracked files restore via git), rmdir,
 *   git reset --soft/--mixed, git clean -n, rebase / checkout / restore
 *   (their approval requirement remains in principles.md §7),
 *   normal git push, git branch -D (reflog).
 *
 * Simple absolute rm targets strictly inside os.tmpdir() are exempt because
 * their contents are disposable. The temp root itself, shell expansions,
 * mixed target sets, and paths resolving outside it still prompt.
 *
 * Detection is heuristic: commands are split on shell operators and the first
 * command token of each segment is classified. Quoted text mentioning e.g.
 * "rm -rf" can false-positive — a needless prompt is the intended failure
 * mode; a missed real command is not.
 */

import { existsSync, realpathSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, relative, resolve, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Hit = { rule: string; why: string; deny?: true };

const basename = (t: string) => t.split("/").pop() ?? t;
const TEMP_ROOT = realpathSync(tmpdir());
const SHELL_SYNTAX = /[\s*?\[\]{}$`'"\\<>|;&()]/;

function isInside(path: string, root: string): boolean {
	const fromRoot = relative(root, path);
	return fromRoot !== "" && fromRoot !== ".." && !fromRoot.startsWith(`..${sep}`) && !isAbsolute(fromRoot);
}

function nearestExistingAncestor(path: string): string {
	let candidate = path;
	while (!existsSync(candidate)) {
		const parent = dirname(candidate);
		if (parent === candidate) return candidate;
		candidate = parent;
	}
	return candidate;
}

function isSafeTempTarget(target: string): boolean {
	if (!isAbsolute(target) || SHELL_SYNTAX.test(target) || target.split(/[\\/]/).includes("..")) return false;

	const resolved = resolve(target);
	if (!isInside(resolved, resolve(tmpdir()))) return false;

	const existingAncestor = nearestExistingAncestor(resolved);
	try {
		const realAncestor = realpathSync(existingAncestor);
		return realAncestor === TEMP_ROOT || isInside(realAncestor, TEMP_ROOT);
	} catch {
		return false;
	}
}

function onlySafeTempTargets(args: string[]): boolean {
	const separator = args.indexOf("--");
	const targets = separator === -1
		? args.filter((arg) => !arg.startsWith("-"))
		: [...args.slice(0, separator).filter((arg) => !arg.startsWith("-")), ...args.slice(separator + 1)];
	return targets.length > 0 && targets.every(isSafeTempTarget);
}

export function analyze(command: string): Hit[] {
	const hits: Hit[] = [];
	const segments = command
		.split(/&&|\|\||[;|\n]/)
		.map((s) => s.trim())
		.filter(Boolean);

	for (const seg of segments) {
		const t = seg.split(/\s+/).filter(Boolean);

		// Skip prefixes: sudo (note it), env assignments, command/builtin/time/nice.
		let i = 0;
		let sudo = false;
		while (i < t.length) {
			const b = basename(t[i]);
			if (b === "sudo") {
				sudo = true;
				i++;
				continue;
			}
			if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(t[i])) {
				i++;
				continue;
			}
			if (b === "command" || b === "builtin" || b === "time" || b === "nice") {
				i++;
				continue;
			}
			break;
		}
		if (i >= t.length) continue;

		const cmd = basename(t[i]);
		const rest = t.slice(i + 1);

		if (cmd === "rm") {
			const flags = rest.filter((x) => x.startsWith("-"));
			const recursive = flags.some((f) => /^--recursive$/.test(f) || /^-[a-zA-Z]*[rR]/.test(f));
			const force = flags.some((f) => /^--force$/.test(f) || /^-[a-zA-Z]*f/.test(f));
			const safeTempRemoval = !sudo && (recursive || force) && onlySafeTempTargets(rest);
			if (sudo) hits.push({ rule: "sudo rm", why: "privileged delete — can destroy anything, unrecoverable" });
			else if (safeTempRemoval) continue;
			else if (recursive) hits.push({ rule: "recursive rm", why: "deletes entire trees, unrecoverable" });
			else if (force) hits.push({ rule: "forced rm", why: "forced delete — unrecoverable for untracked files" });
			continue;
		}

		if (cmd === "find") {
			if (rest.includes("-delete")) hits.push({ rule: "find -delete", why: "bulk delete, unrecoverable" });
			continue;
		}

		if (cmd === "git") {
			// Find the subcommand, skipping global opts (-C <path>, -c <k=v>, --git-dir=…).
			let sub: string | undefined;
			const afterGit: string[] = [];
			for (let k = 0; k < rest.length; k++) {
				const x = rest[k];
				if (!sub) {
					if (x === "-C" || x === "-c") {
						k++; // skip the option's value
						continue;
					}
					if (x.startsWith("-")) continue;
					sub = x;
					continue;
				}
				afterGit.push(x);
			}

			if (sub === "push") {
				const bareForce = afterGit.some((x) => x === "--force" || /^-[a-zA-Z]*f[a-zA-Z]*$/.test(x) || x.startsWith("+"));
				const lease = afterGit.some((x) => x.startsWith("--force-with-lease") || x.startsWith("--force-if-includes"));
				if (bareForce)
					hits.push({ rule: "git push --force", why: "can silently clobber others' commits on the remote — use --force-with-lease", deny: true });
				else if (lease)
					hits.push({ rule: "git push --force-with-lease", why: "rewrites remote history" });
			}
			if (sub === "reset" && afterGit.includes("--hard")) {
				hits.push({ rule: "git reset --hard", why: "destroys uncommitted changes, unrecoverable" });
			}
			if (sub === "clean") {
				const hasF = afterGit.some((x) => x === "--force" || (/^-[a-zA-Z]*f/.test(x) && !x.startsWith("--")));
				if (hasF) hits.push({ rule: "git clean -f", why: "deletes untracked files, unrecoverable" });
			}
		}
	}

	// Dedup by rule.
	const seen = new Set<string>();
	return hits.filter((h) => (seen.has(h.rule) ? false : (seen.add(h.rule), true)));
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.hasUI) ctx.ui.notify("destructive-guard: active (unrecoverable ops require approval)", "info");
	});

	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName !== "bash") return;

		const input = event.input as { command?: unknown };
		const command = typeof input.command === "string" ? input.command : "";
		const hits = analyze(command);
		if (hits.length === 0) return;

		const summary = hits.map((h) => `${h.rule} — ${h.why}`).join("\n");
		const shown = command.length > 300 ? `${command.slice(0, 300)}…` : command;

		if (hits.some((hit) => hit.deny)) {
			return { block: true, reason: `destructive-guard blocked: ${summary}\nCommand: ${shown}` };
		}

		// No UI → no way to obtain explicit approval → hard block.
		if (ctx.mode !== "tui") {
			return {
				block: true,
				reason: `destructive-guard blocked (non-interactive, no approval possible): ${summary}\nCommand: ${shown}\nRe-run in an interactive pi session to approve.`,
			};
		}

		const ok = await ctx.ui.confirm(
			`⚠ ${hits.map((h) => h.rule).join(" + ")}`,
			`${summary}\n\n$ ${shown}\n\nThis cannot be undone. Allow?`,
		);
		if (!ok) {
			ctx.ui.notify(`Blocked: ${hits[0].rule}`, "info");
			return { block: true, reason: `destructive-guard: user declined (${summary})` };
		}
		ctx.ui.notify(`Approved: ${hits[0].rule}`, "warning");
	});
}
