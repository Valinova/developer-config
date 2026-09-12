"""Exercise configuration drift that can leave a harness incorrectly wired."""

import importlib.util
import tempfile
import unittest
from pathlib import Path


SPEC = importlib.util.spec_from_file_location(
    "check_wiring", Path(__file__).with_name("check-wiring.py")
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MergeTests(unittest.TestCase):
    def audit(self, text, harness="Codex"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "config.toml").write_text(text)
            return MODULE.audit_merge(harness, root)

    def test_routing_must_be_an_active_instruction(self):
        config = (
            '[agents]\ndefault_subagent_model = "gpt-6-astra"\n'
            'default_subagent_reasoning_effort = "high"\n'
        )
        for prefix in (
            '# read codex/model-defaults.md\n',
            'unrelated = "codex/model-defaults.md"\n',
        ):
            with self.subTest(prefix=prefix):
                self.assertTrue(self.audit(prefix + config))
        self.assertFalse(self.audit(
            'developer_instructions = "Read codex/model-defaults.md before dispatch"\n'
            + config
        ))

    def test_invalid_config_fails_without_a_traceback(self):
        for text in (
            'developer_instructions = "Read codex/model-defaults.md"\n'
            '[agents]\ndefault_subagent_model = "gpt-6-astra"\n'
            'default_subagent_reasoning_effort = "high"\ninvalid toml',
            '[agents]\ndefault_subagent_model = "gpt-6-astra"\n'
            'default_subagent_model = "other"\n',
        ):
            with self.subTest(text=text):
                self.assertTrue(self.audit(text))

    def test_equivalent_toml_syntax_is_accepted(self):
        self.assertFalse(self.audit(
            "developer_instructions = 'Read codex/model-defaults.md before dispatch'\n"
            "agents = { default_subagent_model = 'gpt-6-astra', "
            "default_subagent_reasoning_effort = 'high' }\n"
        ))

    def test_grok_requires_a_configured_mcp_command(self):
        config = (
            '[compat.claude]\nskills = false\nagents = false\n'
            '[subagents.models]\nexplore = "grok-4.6"\n'
            'plan = "grok-4.6"\ngeneral-purpose = "grok-4.6"\n'
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


if __name__ == "__main__":
    unittest.main()
