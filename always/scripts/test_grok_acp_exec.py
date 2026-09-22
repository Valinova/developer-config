#!/usr/bin/env python3

import importlib.util
import json
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("grok-acp-exec.py")
SPEC = importlib.util.spec_from_file_location("grok_acp_exec", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


FAKE_AGENT = r'''
import json
import sys

def receive():
    return json.loads(sys.stdin.readline())

def send(message):
    print(json.dumps(message), flush=True)

initialize = receive()
send({"jsonrpc": "2.0", "id": initialize["id"], "result": {"protocolVersion": 1}})
new_session = receive()
send({"jsonrpc": "2.0", "id": new_session["id"], "result": {"sessionId": "fake-session"}})
prompt = receive()
send({
    "jsonrpc": "2.0",
    "method": "session/update",
    "params": {
        "sessionId": "fake-session",
        "update": {
            "sessionUpdate": "agent_message_chunk",
            "content": {"type": "text", "text": "progress"},
        },
    },
})
send({
    "jsonrpc": "2.0",
    "method": "session/update",
    "params": {
        "sessionId": "fake-session",
        "update": {"sessionUpdate": "tool_call", "toolCallId": "tool-1"},
    },
})
send({
    "jsonrpc": "2.0",
    "id": 99,
    "method": "session/request_permission",
    "params": {
        "sessionId": "fake-session",
        "options": [
            {"optionId": "reject", "kind": "reject_once"},
            {"optionId": "allow", "kind": "allow_once"},
        ],
    },
})
permission = receive()
assert permission["result"]["outcome"] == {
    "outcome": "selected",
    "optionId": "allow",
}
for text in ("hello ", "world"):
    send({
        "jsonrpc": "2.0",
        "method": "session/update",
        "params": {
            "sessionId": "fake-session",
            "update": {
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": text},
            },
        },
    })
send({"jsonrpc": "2.0", "id": prompt["id"], "result": {"stopReason": "end_turn"}})
'''

HANGING_AGENT = r'''
import json
import sys

def receive():
    return json.loads(sys.stdin.readline())

def send(message):
    print(json.dumps(message), flush=True)

initialize = receive()
send({"jsonrpc": "2.0", "id": initialize["id"], "result": {}})
new_session = receive()
send({"jsonrpc": "2.0", "id": new_session["id"], "result": {"sessionId": "hung"}})
receive()
cancel = receive()
assert cancel["method"] == "session/cancel"
'''


class GrokAcpExecTests(unittest.TestCase):
    def test_acp_lifecycle_collects_text_and_approves_once(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake = root / "fake_agent.py"
            fake.write_text(textwrap.dedent(FAKE_AGENT), encoding="utf-8")
            events = root / "events.jsonl"
            stderr = root / "stderr.log"
            client = MODULE.AcpClient(
                [sys.executable, str(fake)], root, events, stderr, 5
            )

            self.assertEqual(client.run("do the task"), "hello world")
            records = [json.loads(line) for line in events.read_text().splitlines()]
            methods = [
                record["message"].get("method")
                for record in records
                if record["direction"] == "send"
            ]
            self.assertIn("initialize", methods)
            self.assertIn("session/new", methods)
            self.assertIn("session/prompt", methods)
            self.assertEqual(stderr.read_text(), "")

    def test_command_is_leaf_sandboxed_and_denies_git_writes(self):
        command = MODULE.build_command(
            "/bin/grok", Path("/repo"), "grok-4.7", "high", "workspace", 20
        )

        self.assertIn("--no-subagents", command)
        self.assertEqual(command[command.index("--sandbox") + 1], "workspace")
        self.assertIn("Bash(git *)", command)
        self.assertIn("Edit(.git/**)", command)
        self.assertLess(command.index("agent"), command.index("--always-approve"))
        self.assertEqual(command[-1], "stdio")
        self.assertIn("edit only allowlisted files", MODULE.LEAF_RULES)
        self.assertIn("scope_expansion_needed", MODULE.LEAF_RULES)
        self.assertIn("do not claim completion", MODULE.LEAF_RULES)

    def test_permission_without_allow_once_is_cancelled(self):
        self.assertIsNone(
            MODULE.AcpClient._allow_once_option(
                [{"optionId": "forever", "kind": "allow_always"}]
            )
        )

    def test_timeout_cancels_and_reaps_exact_process(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake = root / "hanging_agent.py"
            fake.write_text(textwrap.dedent(HANGING_AGENT), encoding="utf-8")
            events = root / "events.jsonl"
            client = MODULE.AcpClient(
                [sys.executable, str(fake)], root, events, root / "stderr.log", 0.1
            )

            with self.assertRaises(MODULE.AcpTimeout):
                client.run("hang")

            self.assertIsNotNone(client.process)
            self.assertIsNotNone(client.process.poll())
            methods = [
                json.loads(line)["message"].get("method")
                for line in events.read_text().splitlines()
            ]
            self.assertIn("session/cancel", methods)


if __name__ == "__main__":
    unittest.main()
