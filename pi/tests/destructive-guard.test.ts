import assert from "node:assert/strict";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import installGuard, { analyze } from "../extensions/destructive-guard";

for (const target of ["/", "/*", "~", "~/*", "$HOME", "$HOME/*", "..", "../*", homedir(), `${homedir()}/`]) {
	assert.equal(analyze(`rm -rf ${target}`).length, 1, `rm -rf ${target} must stay guarded`);
}
assert.equal(analyze(`sudo rm -rf ${join(tmpdir(), "x")}`).length, 1, "privileged removal must stay guarded");
for (const command of ["rm -rf /srv/example", "rm -rf ./dist", "rm -rf /tmp/x", "find . -delete"]) {
	assert.equal(analyze(command).length, 0, `${command} is left to judgement`);
}

for (const command of ["git push --force", "git push -vf", "git push origin +main:main", "git -C /repo push -f"]) {
	assert.equal(analyze(command)[0]?.deny, true, `${command} must be denied in every mode`);
}
assert.equal(analyze("git push --force-with-lease")[0]?.deny, undefined, "lease remains approvable");
assert.equal(analyze("git push origin main").length, 0, "ordinary push remains unguarded");

for (const command of [
	"doppler run --config prd -- psql",
	"doppler run -c prd -- pnpm sync",
	"doppler run --config=prd -- true",
	"DOPPLER_CONFIG=prd doppler run -- psql",
	"doppler secrets --config prd --only-names",
	`bash -c "doppler run --config prd -- psql"`,
]) {
	assert.equal(analyze(command)[0]?.rule, "doppler prd", `${command} must ask before touching production`);
}
for (const command of ["doppler run --config dev -- psql", "doppler run --config prd_like -- x", "echo prd"]) {
	assert.equal(analyze(command).length, 0, `${command} is not production`);
}

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
	["doppler run --config prd -- psql", "tui", true, false, 1],
	["doppler run --config prd -- psql", "rpc", true, true, 0],
] as const) {
	let prompts = 0;
	const result = await onToolCall({ toolName: "bash", input: { command } }, {
		mode,
		ui: { confirm: async () => { prompts++; return approved; }, notify: () => {} },
	});
	assert.equal(Boolean(result && typeof result === "object" && "block" in result && result.block), blocked, `${mode}: ${command}`);
	assert.equal(prompts, expectedPrompts, `${mode}: approval prompts for ${command}`);
}
console.log("destructive guard: catastrophic rm floor, force-push policy, and approval paths passed");
