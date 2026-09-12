import assert from "node:assert/strict";
import { tmpdir } from "node:os";
import { join } from "node:path";
import installGuard, { analyze } from "../extensions/destructive-guard";

const tempTarget = join(tmpdir(), "pi-owned-verification");

assert.equal(analyze(`rm -rf ${tempTarget}`).length, 0, "simple recursive temp removal should pass");
assert.equal(
	analyze(`rm --recursive --force ${tempTarget}`).length,
	0,
	"long-form recursive temp removal should pass",
);

assert.equal(analyze(`rm -rf ${tmpdir()}`).length, 1, "temp root itself must stay guarded");
assert.equal(analyze(`rm -rf ${tmpdir()}/*`).length, 1, "temp globs must stay guarded");
assert.equal(analyze("rm -rf $TMPDIR/example").length, 1, "unresolved variables must stay guarded");
assert.equal(analyze(`rm -rf ${tempTarget} /home/example`).length, 1, "mixed targets must stay guarded");
assert.equal(analyze(`rm -rf ${tempTarget} -- -real-directory`).length, 1, "dash-prefixed targets after -- must stay guarded");
assert.equal(analyze(`sudo rm -rf ${tempTarget}`).length, 1, "privileged temp removal must stay guarded");
assert.equal(analyze("rm -rf /home/example").length, 1, "non-temp removal must stay guarded");
assert.equal(analyze(`rm -rf ${tempTarget}/../other`).length, 1, "parent traversal must stay guarded");

for (const command of ["git push --force", "git push -vf", "git push origin +main:main", "git -C /repo push -f"]) {
	assert.equal(analyze(command)[0]?.deny, true, `${command} must be denied in every mode`);
}
assert.equal(analyze("git push --force-with-lease")[0]?.deny, undefined, "lease remains approvable");
assert.equal(analyze("git push origin main").length, 0, "ordinary push remains unguarded");

// Mock the extension event/UI boundaries; run the actual installed handler.
let onToolCall: ((event: unknown, context: unknown) => Promise<unknown>) | undefined;
installGuard({
	on(event, handler) {
		if (event === "tool_call") onToolCall = handler as typeof onToolCall;
	},
} as Parameters<typeof installGuard>[0]);
assert.ok(onToolCall);
for (const [command, mode, approved, blocked, expectedPrompts] of [
	["git push --force", "tui", true, true, 0],
	["git push origin +main:main", "tui", true, true, 0],
	["git push --force-with-lease", "tui", true, false, 1],
	["git push --force-with-lease", "tui", false, true, 1],
	["git push --force-with-lease", "rpc", true, true, 0],
] as const) {
	let prompts = 0;
	const result = await onToolCall({ toolName: "bash", input: { command } }, {
		mode,
		ui: { confirm: async () => { prompts++; return approved; }, notify: () => {} },
	});
	assert.equal(Boolean(result && typeof result === "object" && "block" in result && result.block), blocked, `${mode}: ${command}`);
	assert.equal(prompts, expectedPrompts, `${mode}: approval prompts for ${command}`);
}
console.log("destructive guard: temp exemptions, force-push policy, and approval paths passed");
