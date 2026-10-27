"""Exercise configuration drift that can leave a harness incorrectly wired."""

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "check_wiring", Path(__file__).with_name("check-wiring.py")
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

CODEX_PERMISSIONS = (
    'approval_policy = "on-request"\n'
    'approvals_reviewer = "auto_review"\n'
)


class MergeTests(unittest.TestCase):
    def audit(self, text, harness="Codex"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "config.toml").write_text(text)
            return MODULE.audit_merge(harness, root)

    def test_invalid_config_fails_without_a_traceback(self):
        for text in (
            '[agents]\ndefault_subagent_model = "gpt-6.1-sol"\n'
            'default_subagent_reasoning_effort = "high"\ninvalid toml',
            '[agents]\ndefault_subagent_model = "gpt-6.1-sol"\n'
            'default_subagent_model = "other"\n',
        ):
            with self.subTest(text=text):
                self.assertTrue(self.audit(text))

    def test_equivalent_toml_syntax_is_accepted(self):
        self.assertFalse(self.audit(
            CODEX_PERMISSIONS + "agents = { default_subagent_model = 'gpt-6.1-sol', "
            "default_subagent_reasoning_effort = 'high' }\n"
        ))

    def test_codex_command_review_cannot_silently_be_disabled(self):
        config = (
            CODEX_PERMISSIONS
            + '[agents]\ndefault_subagent_model = "gpt-6.1-sol"\n'
            + 'default_subagent_reasoning_effort = "high"\n'
        )
        self.assertFalse(self.audit(config))
        for old, new in (
            ('approval_policy = "on-request"', 'approval_policy = "never"'),
            ('approval_policy = "on-request"', ''),
            ('approvals_reviewer = "auto_review"', 'approvals_reviewer = "user"'),
            ('approvals_reviewer = "auto_review"', ''),
        ):
            with self.subTest(setting=new or old):
                self.assertTrue(self.audit(config.replace(old, new)))

    def test_grok_requires_a_configured_mcp_command(self):
        config = (
            '[compat.claude]\nskills = false\nagents = false\n'
            '[subagents.models]\nexplore = "grok-4.7"\n'
            'plan = "grok-4.7"\ngeneral-purpose = "grok-4.7"\n'
            '[mcp_servers.convex]\n'
        )
        self.assertTrue(self.audit(config, "Grok"))
        self.assertFalse(self.audit(config +
            'command = "npx"\nargs = ["-y", "convex@latest", "mcp", "start"]\n',
            "Grok"))

    def test_pi_mcp_missing_invalid_and_configured(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertTrue(MODULE.audit_pi_mcp(root))
            path = root / "mcp.json"
            for text in ('invalid json', '{}', '{"mcpServers":{"convex":{}}}'):
                with self.subTest(text=text):
                    path.write_text(text)
                    self.assertTrue(MODULE.audit_pi_mcp(root))
            path.write_text('{"mcpServers":{"convex":{"command":"npx",'
                            '"args":["-y","convex@latest","mcp","start"]}}}')
            self.assertFalse(MODULE.audit_pi_mcp(root))


class CodexAgentsTests(unittest.TestCase):
    # Config checks cannot detect missing rules or drift in the generated root.
    def test_committed_codex_agents_is_current(self):
        result = subprocess.run(
            [sys.executable, SPEC.origin, "--check"], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generation_preserves_import_order_and_detects_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            script = repo / "always/scripts/check-wiring.py"
            script.parent.mkdir(parents=True)
            shutil.copyfile(SPEC.origin, script)
            (repo / "instructions").mkdir()
            (repo / "codex").mkdir()
            (repo / "claude-root.md").write_text(
                "Manifest prose is not an instruction.\n"
                "@~/Development/developer-config/instructions/second.md\n"
                "@~/Development/developer-config/instructions/claude-conventions.md\n"
                "@~/Development/developer-config/instructions/first.md\n"
            )
            (repo / "instructions/second.md").write_text("Second — [link](./rule.md)\n")
            (repo / "instructions/first.md").write_text("First\n")
            (repo / "instructions/claude-conventions.md").write_text("Claude only\n")
            (repo / "codex/model-defaults.md").write_text("Codex card\n")
            target = repo / "codex/AGENTS.md"

            def run(flag):
                return subprocess.run(
                    [sys.executable, str(script), flag], capture_output=True, text=True
                )

            generated = run("--generate")
            self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
            content = target.read_bytes()
            self.assertEqual(content.split(b"\n", 1)[1],
                             "\nSecond — [link](./rule.md)\n\nFirst\n\nCodex card\n".encode())
            self.assertEqual(run("--check").returncode, 0)
            self.assertEqual(run("--generate").returncode, 0)
            self.assertEqual(target.read_bytes(), content)
            for stale in (b"stale\n", content[:-1], None):
                with self.subTest(stale=stale):
                    if stale is None:
                        target.unlink()
                    else:
                        target.write_bytes(stale)
                    result = run("--check")
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("stale", result.stdout)
                    self.assertEqual(target.read_bytes() if target.exists() else None, stale)


if __name__ == "__main__":
    unittest.main()
