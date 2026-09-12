#!/usr/bin/env python3
"""Sync developer-config principles into ~/.hermes/SOUL.md.

Hermes always injects SOUL.md. Shared engineering doctrine lives in
developer-config; this script embeds a byte-stable copy between markers so
coding rules are always-on without manually duplicating them.

Canonical copy: developer-config `hermes/scripts/sync-soul-principles.py`,
linked to `~/.hermes/scripts/` per SETUP.md.

Usage:
  python3 ~/.hermes/scripts/sync-soul-principles.py
"""
from __future__ import annotations

import re
from pathlib import Path

SOUL = Path.home() / ".hermes" / "SOUL.md"
PRINCIPLES = (
    Path(__file__).resolve().parent.parent.parent
    / "instructions"
    / "principles.md"
)
BEGIN = "<!-- PRINCIPLES:BEGIN -->"
END = "<!-- PRINCIPLES:END -->"


def nest_headings(md: str, bump: int = 1) -> str:
    """Bump ATX heading levels so principles nest under SOUL §5."""

    def repl(m: re.Match[str]) -> str:
        hashes, rest = m.group(1), m.group(2)
        new_level = min(6, len(hashes) + bump)
        return "#" * new_level + rest

    return re.sub(r"^(#{1,6})(\s+.+)$", repl, md, flags=re.M)


def main() -> None:
    if not PRINCIPLES.is_file():
        raise SystemExit(f"missing principles: {PRINCIPLES}")
    if not SOUL.is_file():
        raise SystemExit(f"missing SOUL: {SOUL}")

    principles = PRINCIPLES.read_text().rstrip() + "\n"
    if principles.startswith("# Engineering principles\n"):
        body = principles[len("# Engineering principles\n") :].lstrip("\n")
    else:
        body = principles
    body = nest_headings(body, bump=1)

    block = (
        f"{BEGIN}\n"
        f"_Synced from `{PRINCIPLES}` via "
        f"`~/.hermes/scripts/sync-soul-principles.py`. "
        f"Edit the source, then re-run the script — do not hand-edit this "
        f"block._\n\n"
        f"{body}"
        f"{END}"
    )

    soul = SOUL.read_text()
    if BEGIN not in soul or END not in soul:
        raise SystemExit(
            f"SOUL missing {BEGIN} / {END} markers — refuse to guess insert point"
        )

    pre, rest = soul.split(BEGIN, 1)
    _, post = rest.split(END, 1)
    new_soul = pre + block + post
    if new_soul != soul:
        SOUL.write_text(new_soul)
        print(f"updated {SOUL} ({len(body)} chars principles body)")
    else:
        print(f"already in sync ({len(body)} chars principles body)")


if __name__ == "__main__":
    main()
