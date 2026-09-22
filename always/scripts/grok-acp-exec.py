#!/usr/bin/env python3
"""Run one Grok Build leaf agent over ACP stdio."""

import argparse
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, TextIO


LEAF_RULES = (
    "You are a leaf coding agent delegated by Codex. Do not delegate or spawn "
    "subagents. Make no Git writes of any kind: do not stage, commit, push, "
    "switch branches, create worktrees, stash, restore, reset, clean, merge, "
    "rebase, or change Git configuration. Leave all changes unstaged and report "
    "the files you changed; Codex owns review and every Git operation. You may "
    "inspect outside the brief's file allowlist, but edit only allowlisted files. "
    "If correct completion requires another file or an unresolved dependency, "
    "report scope_expansion_needed with the exact files and reasons, and do not "
    "claim completion while that scope remains unresolved."
)

GIT_DENIES = (
    "Bash(git)",
    "Bash(git *)",
    "Edit(.git/**)",
)


class AcpError(RuntimeError):
    pass


class AcpTimeout(AcpError):
    pass


class RunInterrupted(AcpError):
    pass


def raise_interrupted(_signum: int, _frame: Any) -> None:
    raise RunInterrupted()


def build_command(
    grok: str,
    cwd: Path,
    model: str,
    effort: str,
    sandbox: str,
    max_turns: int,
) -> List[str]:
    command = [
        grok,
        "--cwd",
        str(cwd),
        "--sandbox",
        sandbox,
        "--no-subagents",
        "--max-turns",
        str(max_turns),
        "--rules",
        LEAF_RULES,
    ]
    for rule in GIT_DENIES:
        command.extend(("--deny", rule))
    command.extend(
        (
            "agent",
            "--always-approve",
            "--no-leader",
            "--model",
            model,
            "--reasoning-effort",
            effort,
            "stdio",
        )
    )
    return command


class AcpClient:
    def __init__(
        self,
        command: List[str],
        cwd: Path,
        events_path: Path,
        stderr_path: Path,
        timeout_seconds: float,
    ) -> None:
        self.command = command
        self.cwd = cwd
        self.events_path = events_path
        self.stderr_path = stderr_path
        self.timeout_seconds = timeout_seconds
        self.process: Optional[subprocess.Popen[bytes]] = None
        self.session_id: Optional[str] = None
        self._next_id = 1
        self._stdout_buffer = b""
        self._message_chunks: List[str] = []
        self._events: Optional[TextIO] = None
        self._stderr: Optional[Any] = None

    def run(self, brief: str) -> str:
        deadline = time.monotonic() + self.timeout_seconds
        self.events_path.parent.mkdir(parents=True, exist_ok=True)
        self.stderr_path.parent.mkdir(parents=True, exist_ok=True)
        self._events = self.events_path.open("w", encoding="utf-8")
        self._stderr = self.stderr_path.open("wb")
        env = os.environ.copy()
        env.update(
            {
                "GROK_CLAUDE_MCPS_ENABLED": "false",
                "GROK_CURSOR_MCPS_ENABLED": "false",
                "GROK_MCP_AUTO_RESTART": "false",
            }
        )
        self.process = subprocess.Popen(
            self.command,
            cwd=str(self.cwd),
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self._stderr,
            start_new_session=True,
        )

        try:
            self._request(
                "initialize",
                {
                    "protocolVersion": 1,
                    "clientCapabilities": {
                        "fs": {"readTextFile": False, "writeTextFile": False},
                        "terminal": False,
                    },
                    "_meta": {
                        "clientType": "developer-config-grok-acp",
                        "clientVersion": "1",
                        "startupHints": {"nonInteractive": True},
                    },
                },
                deadline,
            )
            new_session = self._request(
                "session/new",
                {"cwd": str(self.cwd), "mcpServers": []},
                deadline,
            )
            session_id = new_session.get("sessionId")
            if not isinstance(session_id, str) or not session_id:
                raise AcpError("session/new returned no sessionId")
            self.session_id = session_id
            self._request(
                "session/prompt",
                {
                    "sessionId": session_id,
                    "prompt": [{"type": "text", "text": brief}],
                },
                deadline,
            )
            return "".join(self._message_chunks)
        except (KeyboardInterrupt, RunInterrupted):
            self._cancel()
            raise RunInterrupted("Grok ACP run interrupted")
        except AcpTimeout:
            self._cancel()
            raise
        finally:
            self._shutdown()

    def _request(
        self, method: str, params: Dict[str, Any], deadline: float
    ) -> Dict[str, Any]:
        request_id = self._next_id
        self._next_id += 1
        self._send(
            {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
        )
        while True:
            message = self._read_message(deadline)
            if message.get("id") == request_id and "method" not in message:
                error = message.get("error")
                if error is not None:
                    raise AcpError(f"{method} failed: {json.dumps(error, sort_keys=True)}")
                result = message.get("result", {})
                if not isinstance(result, dict):
                    raise AcpError(f"{method} returned a non-object result")
                return result
            self._handle_message(message)

    def _handle_message(self, message: Dict[str, Any]) -> None:
        method = message.get("method")
        if method == "session/update":
            update = message.get("params", {}).get("update", {})
            update_kind = update.get("sessionUpdate")
            if update_kind == "tool_call":
                self._message_chunks.clear()
            elif update_kind == "agent_message_chunk":
                content = update.get("content", {})
                text = content.get("text")
                if isinstance(text, str):
                    self._message_chunks.append(text)
            return

        if method == "session/request_permission" and "id" in message:
            options = message.get("params", {}).get("options", [])
            option_id = self._allow_once_option(options)
            outcome: Dict[str, Any]
            if option_id is None:
                outcome = {"outcome": "cancelled"}
            else:
                outcome = {"outcome": "selected", "optionId": option_id}
            self._send(
                {"jsonrpc": "2.0", "id": message["id"], "result": {"outcome": outcome}}
            )
            return

        if method is not None and "id" in message:
            self._send(
                {
                    "jsonrpc": "2.0",
                    "id": message["id"],
                    "error": {"code": -32601, "message": f"Unsupported method: {method}"},
                }
            )

    @staticmethod
    def _allow_once_option(options: Any) -> Optional[Any]:
        if not isinstance(options, list):
            return None
        for option in options:
            if not isinstance(option, dict):
                continue
            kind = re.sub(r"[_-]", "", str(option.get("kind", "")).lower())
            if kind == "allowonce" and "optionId" in option:
                return option["optionId"]
        return None

    def _read_message(self, deadline: float) -> Dict[str, Any]:
        if self.process is None or self.process.stdout is None:
            raise AcpError("Grok ACP process is not running")
        while b"\n" not in self._stdout_buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AcpTimeout(
                    f"Grok ACP run exceeded {self.timeout_seconds:g} seconds"
                )
            readable, _, _ = select.select([self.process.stdout], [], [], remaining)
            if not readable:
                raise AcpTimeout(
                    f"Grok ACP run exceeded {self.timeout_seconds:g} seconds"
                )
            chunk = os.read(self.process.stdout.fileno(), 65536)
            if not chunk:
                code = self.process.poll()
                raise AcpError(
                    f"Grok ACP process exited before completing (exit code {code}); "
                    f"see {self.stderr_path}"
                )
            self._stdout_buffer += chunk

        raw, self._stdout_buffer = self._stdout_buffer.split(b"\n", 1)
        try:
            message = json.loads(raw)
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise AcpError(f"Grok emitted invalid ACP JSON: {raw[:200]!r}") from error
        if not isinstance(message, dict):
            raise AcpError("Grok emitted a non-object ACP message")
        self._log("receive", message)
        return message

    def _send(self, message: Dict[str, Any]) -> None:
        if self.process is None or self.process.stdin is None:
            raise AcpError("Grok ACP process is not running")
        self._log("send", message)
        try:
            self.process.stdin.write(
                (json.dumps(message, separators=(",", ":")) + "\n").encode("utf-8")
            )
            self.process.stdin.flush()
        except BrokenPipeError as error:
            raise AcpError(
                f"Grok ACP process closed stdin; see {self.stderr_path}"
            ) from error

    def _log(self, direction: str, message: Dict[str, Any]) -> None:
        if self._events is None:
            return
        record = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "direction": direction,
            "message": message,
        }
        self._events.write(json.dumps(record, separators=(",", ":")) + "\n")
        self._events.flush()

    def _cancel(self) -> None:
        if self.session_id is None or self.process is None or self.process.poll() is not None:
            return
        try:
            self._send(
                {
                    "jsonrpc": "2.0",
                    "method": "session/cancel",
                    "params": {"sessionId": self.session_id},
                }
            )
        except AcpError:
            pass

    def _shutdown(self) -> None:
        process = self.process
        if process is not None:
            if process.stdin is not None and not process.stdin.closed:
                process.stdin.close()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            if process.stdout is not None:
                process.stdout.close()
        if self._events is not None:
            self._events.close()
        if self._stderr is not None:
            self._stderr.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Delegate one leaf task to Grok Build through ACP stdio."
    )
    parser.add_argument("task", help="artifact-safe task name")
    parser.add_argument("brief", type=Path, help="task brief file")
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("--model", default="grok-4.7")
    parser.add_argument("--effort", default="high")
    parser.add_argument(
        "--sandbox", choices=("workspace", "read-only", "strict"), default="workspace"
    )
    parser.add_argument("--max-turns", type=int, default=30)
    parser.add_argument("--timeout-seconds", type=float, default=1800)
    parser.add_argument("--artifacts-dir", type=Path, default=Path("/tmp"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.task):
        print("grok-acp-exec.py: task name contains unsafe characters", file=sys.stderr)
        return 2
    if not args.brief.is_file():
        print(f"grok-acp-exec.py: brief not found: {args.brief}", file=sys.stderr)
        return 2
    cwd = args.cwd.resolve()
    if not cwd.is_dir():
        print(f"grok-acp-exec.py: cwd is not a directory: {cwd}", file=sys.stderr)
        return 2
    if args.max_turns < 1 or args.timeout_seconds <= 0:
        print("grok-acp-exec.py: max turns and timeout must be positive", file=sys.stderr)
        return 2
    grok = shutil.which("grok")
    if grok is None:
        print("grok-acp-exec.py: 'grok' CLI not found on PATH", file=sys.stderr)
        return 3

    prefix = args.artifacts_dir / f"grok-acp-{args.task}"
    events_path = Path(f"{prefix}.events.jsonl")
    stderr_path = Path(f"{prefix}.stderr.log")
    result_path = Path(f"{prefix}.result.md")
    client = AcpClient(
        build_command(grok, cwd, args.model, args.effort, args.sandbox, args.max_turns),
        cwd,
        events_path,
        stderr_path,
        args.timeout_seconds,
    )

    previous_sigterm = signal.getsignal(signal.SIGTERM)
    signal.signal(signal.SIGTERM, raise_interrupted)
    try:
        result = client.run(args.brief.read_text(encoding="utf-8"))
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(result.rstrip() + "\n", encoding="utf-8")
        print(result)
        print(f"grok-acp-exec.py: events: {events_path}", file=sys.stderr)
        print(f"grok-acp-exec.py: stderr: {stderr_path}", file=sys.stderr)
        print(f"grok-acp-exec.py: result: {result_path}", file=sys.stderr)
        return 0
    except AcpTimeout as error:
        print(f"grok-acp-exec.py: {error}", file=sys.stderr)
        return 124
    except RunInterrupted as error:
        print(f"grok-acp-exec.py: {error}", file=sys.stderr)
        return 130
    except (AcpError, OSError) as error:
        print(f"grok-acp-exec.py: {error}", file=sys.stderr)
        return 1
    finally:
        signal.signal(signal.SIGTERM, previous_sigterm)


if __name__ == "__main__":
    sys.exit(main())
