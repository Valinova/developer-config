#!/usr/bin/env python3
"""Lint: every harness skill stub for a shared workflow points at that workflow.

For each */skills/<name>/SKILL.md whose <name> has a workflows/<name>.md, the
stub must reference `workflows/<name>.md`. Any SKILL.md that references a
workflows/*.md must name a file that exists. Exit 1 with one line per problem.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REF = re.compile(r"workflows/([A-Za-z0-9_-]+)\.md")


def main() -> int:
    workflows = {p.stem for p in (ROOT / "workflows").glob("*.md")}
    problems = []
    for stub in sorted(ROOT.glob("*/skills/*/SKILL.md")):
        rel = stub.relative_to(ROOT)
        name = stub.parent.name
        refs = set(REF.findall(stub.read_text(encoding="utf-8")))
        if name in workflows and name not in refs:
            problems.append(f"{rel}: does not reference workflows/{name}.md")
        for ref in sorted(refs - workflows):
            problems.append(f"{rel}: references missing workflows/{ref}.md")
    for line in problems:
        print(line)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
