"""Exercise configuration drift that can leave a harness incorrectly wired."""

import importlib.util
import json
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
from codex_registry import CODEX_MODELS  # noqa: E402  (lib is on sys.path via MODULE)

SOL, ASTRA = CODEX_MODELS["sol"], CODEX_MODELS["astra"]
CODEX_PERMISSIONS = (
    'approval_policy = "on-request"\n'
    'approvals_reviewer = "auto_review"\n'
)
CODEX_CONFIG = (
    CODEX_PERMISSIONS
    + f'model = "{ASTRA}"\n'
    + f'[agents]\ndefault_subagent_model = "{SOL}"\n'
    + 'default_subagent_reasoning_effort = "high"\n'
)


class MergeTests(unittest.TestCase):
    def audit(self, text, harness="Codex"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "config.toml").write_text(text)
            return MODULE.audit_merge(harness, root)

    def test_invalid_config_fails_without_a_traceback(self):
        for text in (
            CODEX_CONFIG + 'invalid toml',
            CODEX_CONFIG + 'default_subagent_model = "other"\n',
        ):
            with self.subTest(text=text):
                self.assertTrue(self.audit(text))

    def test_equivalent_toml_syntax_is_accepted(self):
        self.assertFalse(self.audit(
            CODEX_PERMISSIONS + f"model = '{ASTRA}'\n"
            + f"agents = {{ default_subagent_model = '{SOL}', "
            "default_subagent_reasoning_effort = 'high' }\n"
        ))

    def test_codex_model_projections_must_match_the_owner(self):
        # Codex reads exact IDs, not roles: a stale, unknown or missing primary
        # and a stale or swapped subagent must be reported, not left to the next
        # dispatch. The primary role is the user's pick: either approved ID passes.
        for primary in (ASTRA, SOL):
            with self.subTest(primary=primary):
                self.assertFalse(self.audit(
                    CODEX_CONFIG.replace(f'model = "{ASTRA}"', f'model = "{primary}"')))
        for name, old, new in (
            ("primary missing", f'model = "{ASTRA}"\n', ''),
            ("primary old Sol", f'model = "{ASTRA}"', 'model = "gpt-6.1-sol"'),
            ("primary old Astra", f'model = "{ASTRA}"', 'model = "gpt-6-astra"'),
            ("primary unknown", f'model = "{ASTRA}"', 'model = "gpt-6.2-luna"'),
            ("subagent is Astra", f'default_subagent_model = "{SOL}"',
             f'default_subagent_model = "{ASTRA}"'),
            ("subagent old pin", f'default_subagent_model = "{SOL}"',
             'default_subagent_model = "gpt-6.1-sol"'),
        ):
            with self.subTest(name):
                self.assertTrue(self.audit(CODEX_CONFIG.replace(old, new)))

    def test_codex_command_review_cannot_silently_be_disabled(self):
        config = CODEX_CONFIG
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


class CatalogTests(unittest.TestCase):
    # An approved ID the installed Codex CLI cannot list, or a catalog that
    # cannot be read, must be a finding; merge tests never read the catalog.
    def test_every_approved_model_must_be_in_a_readable_catalog(self):
        rows = (
            ("both listed", {"models": [{"slug": SOL}, {"slug": ASTRA}]}, []),
            ("astra missing", {"models": [{"slug": SOL}]}, [ASTRA]),
            ("empty", {"models": []}, [SOL, ASTRA]),
            ("no models key", {"slugs": [SOL, ASTRA]}, None),
            ("entry without slug", {"models": [{"id": SOL}]}, None),
            ("models not a list", {"models": 3}, None),
            ("invalid json", "not json", None),
            ("absent", False, None),
        )
        for name, catalog, missing in rows:
            with self.subTest(name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                if catalog is not False:
                    text = catalog if isinstance(catalog, str) else json.dumps(catalog)
                    (root / "models_cache.json").write_text(text)
                findings = MODULE.audit_catalog(root)
                if missing is None:
                    self.assertEqual([f[2] for f in findings],
                                     ["readable catalog with models[].slug"])
                else:
                    self.assertEqual(sorted(f[2] for f in findings), sorted(missing))


class LinkTests(unittest.TestCase):
    # A machine-owned skill under the gitignored local/ must not read as drift,
    # while any other unmapped link into the checkout still does.
    def test_local_links_are_foreign_and_other_repo_links_unexpected(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory).resolve()
            repo, root = base / "repo", base / "home"
            for name in ("local/skills/private", "stray"):
                (repo / name).mkdir(parents=True)
            (root / "skills").mkdir(parents=True)
            (root / "skills/private").symlink_to(repo / "local/skills/private")
            (root / "skills/stray").symlink_to(repo / "stray")
            findings = MODULE.audit_links({}, {root / "skills"}, root, repo, "Claude")
            self.assertEqual({(kind, path.name) for kind, path, _, _ in findings},
                             {("FOREIGN", "private"), ("UNEXPECTED", "stray")})


class CodexAgentsTests(unittest.TestCase):
    # Config checks cannot detect missing rules or drift in the generated root.
    def test_committed_codex_agents_is_current(self):
        result = subprocess.run(
            [sys.executable, SPEC.origin, "--check"], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_generation_preserves_source_order_and_detects_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            script = repo / "always/scripts/check-wiring.py"
            script.parent.mkdir(parents=True)
            shutil.copyfile(SPEC.origin, script)
            (script.parent / "lib").mkdir()
            shutil.copyfile(Path(SPEC.origin).parent / "lib/codex_registry.py",
                            script.parent / "lib/codex_registry.py")
            (repo / "instructions").mkdir()
            (repo / "codex").mkdir()
            for source in MODULE.CODEX_SOURCES:
                (repo / source).write_text(source + "\n")
            target = repo / "codex/AGENTS.md"

            def run(flag):
                return subprocess.run(
                    [sys.executable, str(script), flag], capture_output=True, text=True
                )

            generated = run("--generate")
            self.assertEqual(generated.returncode, 0, generated.stdout + generated.stderr)
            content = target.read_bytes()
            self.assertEqual(content.split(b"\n", 1)[1],
                             ("\n" + "\n\n".join(MODULE.CODEX_SOURCES) + "\n").encode())
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
