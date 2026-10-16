// Proves a JS/TS change touches comments only: compares each changed file's
// parsed leaf tokens, with comments, JSDoc and empty JSX expressions removed.
// Usage: node comment-only.cjs <repo> <base-rev> [head-rev]   (no head = working tree)
// Exit 1 lists every file whose code changed, was added or was deleted; other
// file types are listed for a manual check of their comment syntax.
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const [repo, base, head] = process.argv.slice(2);
if (!repo || !base) {
  console.error("usage: node comment-only.cjs <repo> <base-rev> [head-rev]");
  process.exit(2);
}
const ts = require(require.resolve("typescript", { paths: [repo] }));
const git = (...args) =>
  execFileSync("git", ["-C", repo, ...args], {
    maxBuffer: 1 << 28,
    stdio: ["ignore", "pipe", "ignore"],
  }).toString();
const read = (rev, file) => {
  if (rev === undefined) {
    const full = path.join(repo, file);
    return fs.existsSync(full) ? fs.readFileSync(full, "utf8") : null;
  }
  try {
    return git("show", `${rev}:${file}`);
  } catch {
    return null;
  }
};

function leaves(text, file) {
  const kind = /\.[jt]sx$/.test(file) ? ts.ScriptKind.TSX : ts.ScriptKind.TS;
  const sf = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, false, kind);
  const out = [];
  (function walk(node) {
    if (node.kind >= ts.SyntaxKind.FirstJSDocNode && node.kind <= ts.SyntaxKind.LastJSDocNode) return;
    if (node.kind === ts.SyntaxKind.JsxExpression && !node.expression) return;
    const kids = node.getChildren(sf);
    if (kids.length > 0) return kids.forEach(walk);
    let token = node.getText(sf);
    if (node.kind === ts.SyntaxKind.JsxText) token = token.trim().replace(/\s+/g, " ");
    if (token) out.push(token);
  })(sf);
  return out;
}

const range = head === undefined ? [base] : [`${base}...${head}`];
const files = git("diff", "--name-only", ...range).split("\n").filter(Boolean);
const other = [];
let bad = 0;
for (const file of files) {
  if (!/\.[cm]?[jt]sx?$/.test(file)) {
    other.push(file);
    continue;
  }
  const before = read(base, file);
  const after = read(head, file);
  if (before === null || after === null) {
    console.log(`ADDED/DELETED ${file}`);
    bad++;
    continue;
  }
  const a = leaves(before, file);
  const b = leaves(after, file);
  const at = a.findIndex((token, i) => token !== b[i]);
  if (at !== -1 || a.length !== b.length) {
    const i = at === -1 ? Math.min(a.length, b.length) : at;
    console.log(`CODE CHANGE ${file} at token ${i}: ${JSON.stringify(a.slice(i, i + 4))} -> ${JSON.stringify(b.slice(i, i + 4))}`);
    bad++;
  }
}
console.log(`${files.length} files; ${bad} with code changes; check by hand: ${other.join(", ") || "none"}`);
process.exit(bad > 0 ? 1 : 0);
