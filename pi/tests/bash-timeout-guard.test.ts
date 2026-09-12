import assert from "node:assert/strict";
import { resolveBashTimeout } from "../extensions/bash-timeout-guard";

assert.equal(resolveBashTimeout(undefined, "ls"), 30, "undefined + ls → 30");
assert.equal(resolveBashTimeout(undefined, "pnpm build"), 300, "undefined + pnpm build → 300");
assert.equal(resolveBashTimeout(15, "ls"), 15, "15 → 15");
assert.equal(resolveBashTimeout(45000, "ls"), 45, "45000 → 45");
assert.equal(resolveBashTimeout(15000, "ls"), 15, "15000 → 15");
assert.equal(resolveBashTimeout(900, "ls"), 600, "900 seconds then hard-cap → 600");
assert.equal(resolveBashTimeout(1200, "pnpm build"), 600, "1200 intended seconds → hard-cap 600, not 1.2s");
assert.equal(resolveBashTimeout(5000, "ls"), 5, "5000 → ms threshold → 5");
assert.equal(resolveBashTimeout(0, "ls"), 30, "0 + short command → 30");
assert.equal(resolveBashTimeout(Number.NaN, "ls"), 30, "NaN + short command → 30");
assert.equal(resolveBashTimeout(0.5, "ls"), 1, "0.5 after ms conversion still clamps to ≥1");

console.log("bash timeout guard: 11 cases passed");
