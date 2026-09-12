/**
 * bash-timeout-guard.ts — cap hung bash tool calls so they cannot block the
 * agent forever (Pi).
 *
 * Pi's bash timeout is seconds, optional, and has no default
 * (`dist/core/tools/bash.js`). Models routinely pass millisecond values
 * (15000, 45000) which become multi-hour waits. A timed-out bash call returns
 * a tool error and the agent loop continues; prompt text cannot interrupt a
 * blocked tool.
 *
 * Scope is a silent in-place rewrite of `event.input.timeout` on bash
 * `tool_call`. It never blocks the call and does not notify on session start.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const DEFAULT_SHORT_SECONDS = 30;
const DEFAULT_LONG_SECONDS = 300;
const MIN_SECONDS = 1;
const MAX_SECONDS = 600;
// 1000–4999 reads as an intended-seconds ask (e.g. a 1200s build) and clamps
// to MAX instead of dividing into a near-instant timeout; real ms mistakes
// observed in the wild (15000, 45000) sit well above this.
const MILLISECOND_THRESHOLD = 5000;
const LONG_JOB = /\b(?:pnpm|npm|yarn|bun|turbo|cargo|pytest|vitest|playwright|tsc|typecheck)\b/;

export function resolveBashTimeout(
	timeout: number | undefined,
	command: string,
): number {
	let seconds =
		timeout === undefined || !Number.isFinite(timeout) || timeout <= 0
			? LONG_JOB.test(command)
				? DEFAULT_LONG_SECONDS
				: DEFAULT_SHORT_SECONDS
			: timeout;

	if (seconds >= MILLISECOND_THRESHOLD) seconds = seconds / 1000;

	if (seconds < MIN_SECONDS) return MIN_SECONDS;
	if (seconds > MAX_SECONDS) return MAX_SECONDS;
	return seconds;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event) => {
		if (event.toolName !== "bash") return;

		const input = event.input as { command?: unknown; timeout?: unknown };
		const command = typeof input.command === "string" ? input.command : "";
		const timeout = typeof input.timeout === "number" ? input.timeout : undefined;
		input.timeout = resolveBashTimeout(timeout, command);
	});
}
