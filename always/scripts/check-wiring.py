#!/usr/bin/env python3
"""Report drift between repo-owned wiring and installed harnesses.

The map below enforces SETUP.md's contract; update both together. Resolve
relative symlinks and command-link chains before comparing targets. Only
repo-pointing extras in managed directories are errors; foreign entries are
informational. Hand-merged configs are parsed with Python 3.11+ tomllib.
Never write live files. Exit 1 for drift, 0 when all installed harnesses pass.
"""

# simplified: report-only, run by hand and in the gate. upgrade when: the
# other machine is found drifted after a pull a second time (then a
# SessionStart hook), or the report has been hand-applied identically on
# two machines (then --fix).

import json
import re
import sys
import tomllib
from pathlib import Path


# Harness name, home-relative root, installation gate (Claude is required).
HARNESSES = (
    ("Claude", ".claude", None),
    ("Codex", ".codex", ".codex"),
    ("Pi", ".pi/agent", ".pi/agent"),
    ("Grok", ".grok", ".grok"),
    ("Hermes", ".hermes", ".hermes/skills"),
)

# Paths on the left are relative to the harness root; sources to the repo.
LINKS = {
    "Claude": {
        "CLAUDE.md": "claude-root.md",
        "settings.json": "always/settings.json",
        "mcp/playwright.json": "always/mcp/playwright.json",
        "mcp/playwright-browser.json": "always/mcp/playwright-browser.json",
        "mcp/playwright-browser-headed.json": "always/mcp/playwright-browser-headed.json",
    },
    "Codex": {"AGENTS.md": "instructions/principles.md"},
    "Pi": {
        "AGENTS.md": "instructions/principles.md",
        "settings.json": "pi/settings.json",
        "subagents.json": "pi/subagents.json",
        "APPEND_SYSTEM.md": "pi/model-defaults.md",
        "scripts": "always/scripts",
    },
    "Grok": {
        "rules/00-principles.md": "instructions/principles.md",
        "rules/10-git-operations.md": "instructions/git-operations.md",
        "rules/05-dispatch-bootstrap.md": "instructions/dispatch-bootstrap.md",
        "rules/30-model-defaults.md": "grok/model-defaults.md",
        "skills/convex-mcp": "pi/skills/convex-mcp",
    },
    "Hermes": {
        "scripts/sync-soul-principles.py": "hermes/scripts/sync-soul-principles.py",
        "skills/software-development/docs": "always/skills/docs",
    },
}

# Repo-maintenance scripts run from the checkout (by hand or CI), never linked
# into a harness.
REPO_ONLY_SCRIPTS = {Path(__file__).name, "check-private-terms.sh"}

DIRECTORIES = {
    "Claude": (
        ("skills", "always/skills"),
        ("skills", "claude/skills"),
        ("commands", "always/commands/shared"),
        ("commands", "always/commands/claude"),
    ),
    "Codex": (("skills", "always/skills"), ("skills", "codex/skills")),
    "Pi": (
        ("skills", "always/skills"),
        ("skills", "pi/skills"),
        ("agents", "pi/agents"),
        ("extensions", "pi/extensions"),
        ("prompts", "always/commands/shared"),
        ("prompts", "always/commands/pi"),
    ),
    "Grok": (("skills", "always/skills"), ("skills", "grok/skills")),
    "Hermes": (("skills/software-development", "hermes/skills"),),
}


CONVEX_MCP = {
    "command": "npx",
    "args": ["-y", "convex@latest", "mcp", "start"],
}


def hook_scripts(settings):
    """Extract basenames from command hooks, including quoted repo paths."""
    names = set()
    for groups in settings["hooks"].values():
        for group in groups:
            for hook in group["hooks"]:
                if hook.get("type") == "command":
                    tokens = re.findall(r"[^\s\"';&|()]+", hook["command"])
                    names.update(token.rsplit("/", 1)[-1] for token in tokens)
    return names


def expected_links(harness, root, repo, settings):
    expected = {root / live: repo / source
                for live, source in LINKS[harness].items()}
    managed = {path.parent for path in expected if path.parent != root}
    for live, source in DIRECTORIES[harness]:
        managed.add(root / live)
        for child in sorted((repo / source).iterdir()):
            path = root / live / child.name
            if path in expected and expected[path] != child:
                raise ValueError("Conflicting wiring owners for {}".format(path))
            expected[path] = child
    if harness == "Claude":
        managed.add(root / "scripts")
        excluded = hook_scripts(settings)
        for child in sorted((repo / "always/scripts").iterdir()):
            if (child.is_file() and not child.match("test_*.py")
                    and child.name not in REPO_ONLY_SCRIPTS
                    and child.name not in excluded):
                expected[root / "scripts" / child.name] = child
    return expected, managed


def actual_entry(path):
    if path.is_symlink():
        target = path.resolve()
        suffix = " (target absent)" if not path.exists() else ""
        return "symlink -> {}{}".format(target, suffix)
    if path.is_dir():
        return "directory"
    return "regular file" if path.exists() else "absent"


def audit_links(expected, managed, root, repo, harness):
    findings = []
    paths = set(expected)
    for directory in managed:
        if directory.is_dir():
            paths.update(directory.iterdir())
    for path in sorted(paths):
        target = expected.get(path)
        want = str(target) if target else "no repo-owned entry"
        actual = actual_entry(path)
        forbidden = (harness in ("Pi", "Grok")
                     and path == root / "skills/convex"
                     and (path.exists() or path.is_symlink()))
        if forbidden:
            findings.append(("FORBIDDEN", path, "absent (use convex-mcp)", actual))
        if target is not None:
            if not path.is_symlink():
                kind = "NOT_SYMLINK" if path.exists() else "MISSING"
                # SETUP.md tolerates a plain copy of ~/.claude/settings.json:
                # what matters is that its permissions and hooks blocks match
                # the repo, which audit_settings reports on separately.
                if (kind == "NOT_SYMLINK" and harness == "Claude"
                        and path == root / "settings.json"):
                    kind = "INFO"
                findings.append((kind, path, want, actual))
            elif path.resolve() != target.resolve():
                findings.append(("WRONG_TARGET", path, want, actual))
        if path.is_symlink() and path.resolve().is_relative_to(repo):
            if not path.exists():
                findings.append(("DANGLING", path, want, actual))
            if target is None:
                findings.append(("UNEXPECTED", path, want, actual))
        elif target is None and not forbidden:
            findings.append(("FOREIGN", path, "unmanaged (no repo target)", actual))
    return findings


def config_value(config, *keys):
    value = config
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def audit_merge(harness, root):
    path = root / "config.toml"
    if not path.exists():
        return [("MISSING", path, "SETUP.md config merge", "absent")]
    try:
        config = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError:
        return [("MERGE", path, "valid TOML", "invalid TOML")]
    if harness == "Codex":
        instructions = config.get("developer_instructions")
        checks = [
            ('[agents] default_subagent_model = "gpt-6-astra"',
             config_value(config, "agents", "default_subagent_model") == "gpt-6-astra"),
            ('[agents] default_subagent_reasoning_effort = "high"',
             config_value(config, "agents", "default_subagent_reasoning_effort") == "high"),
            ("developer_instructions: codex/model-defaults.md reference",
             isinstance(instructions, str) and "codex/model-defaults.md" in instructions),
        ]
    else:
        checks = [("[compat.claude] {} = false".format(key),
                   config_value(config, "compat", "claude", key) is False)
                  for key in ("skills", "agents")]
        checks.extend(('[subagents.models] {} = "grok-4.6"'.format(key),
                       config_value(config, "subagents", "models", key) == "grok-4.6")
                      for key in ("explore", "plan", "general-purpose"))
        checks.extend(("[mcp_servers.convex] " + key,
                       config_value(config, "mcp_servers", "convex", key) == expected)
                      for key, expected in CONVEX_MCP.items())
    return [("MERGE", path, expected, "required value absent or different")
            for expected, passed in checks if not passed]


def audit_settings(root, settings):
    path = root / "settings.json"
    if path.is_symlink() or not path.is_file():
        return []
    try:
        live = json.loads(path.read_text())
        if not isinstance(live, dict):
            raise ValueError("settings must be a JSON object")
    except ValueError as error:
        return [("SETTINGS", path, "valid JSON object", str(error))]
    findings = []
    for key in ("hooks", "permissions"):
        actual, expected = live.get(key), settings[key]
        if key == "permissions":
            expected = {k: v for k, v in expected.items() if k != "defaultMode"}
            if isinstance(actual, dict):
                actual = {k: v for k, v in actual.items() if k != "defaultMode"}
        equal = actual == expected
        label = key + (" minus defaultMode" if key == "permissions" else "")
        findings.append(("INFO" if equal else "SETTINGS", path,
                         "always/settings.json: " + label,
                         "equal" if equal else "different"))
    return findings


def audit_pi_mcp(root):
    path = root / "mcp.json"
    if not path.is_file():
        return [("MISSING", path, "SETUP.md Convex MCP entry", "absent")]
    try:
        config = json.loads(path.read_text())
    except ValueError:
        return [("MCP", path, "valid JSON", "invalid JSON")]
    return [("MCP", path, "mcpServers.convex." + key, "absent or different")
            for key, expected in CONVEX_MCP.items()
            if config_value(config, "mcpServers", "convex", key) != expected]


def main(home=None, repo=None):
    home = Path.home() if home is None else Path(home)
    repo = Path(__file__).resolve().parents[2] if repo is None else Path(repo)
    repo = repo.resolve()
    settings = json.loads((repo / "always/settings.json").read_text())
    failures = information = checked = skipped = 0
    for harness, relative, gate in HARNESSES:
        if gate and not (home / gate).exists():
            print("{}: skipped (not installed)".format(harness))
            skipped += 1
            continue
        root = home / relative
        expected, managed = expected_links(harness, root, repo, settings)
        findings = audit_links(expected, managed, root, repo, harness)
        if harness in ("Codex", "Grok"):
            findings.extend(audit_merge(harness, root))
        if harness == "Claude":
            findings.extend(audit_settings(root, settings))
        if harness == "Pi":
            findings.extend(audit_pi_mcp(root))
        errors = [item for item in findings if item[0] not in ("FOREIGN", "INFO")]
        info = [item for item in findings if item[0] in ("FOREIGN", "INFO")]
        print("{}: {}".format(harness, "{} finding(s)".format(len(errors))
                             if errors else "ok"))
        for kind, path, want, actual in errors + info:
            print("  {} {}: expected {}; found {}".format(kind, path, want, actual))
        failures += len(errors)
        information += len(info)
        checked += 1
    print("Summary: {} finding(s), {} informational; {} checked, {} skipped".format(
        failures, information, checked, skipped))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
