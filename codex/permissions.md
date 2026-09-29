# Codex command approval

```toml
approval_policy = "on-request"
approvals_reviewer = "auto_review"
```

Sandbox escalations go to the native automatic reviewer instead of the user, so
authorized work keeps moving. `command-safety.rules` blocks only the
unrecoverable, mirroring the Claude deny tier: `rm -rf /` and the common
spellings of a bare force push; the instructions cover the other forms.
Nothing else is gated mechanically, on purpose — command gates slowed routine
work without adding judgment. Link the file at
`~/.codex/rules/command-safety.rules`; keep Codex's accumulated allowances in
`default.rules`. Preserve the machine's existing filesystem/network profile;
this file does not add a sandbox.

## Acting autonomously

[Git operations](../instructions/git-operations.md) owns task authority and
recovery checks, and it is the real safeguard now. Proceed within the authorized
task; stop and ask the user when ownership is unclear, when an operation could
lose work that is not provably task-owned (uncommitted files, the user's
parallel WIP, anything reflog cannot recover), or when it has a new production
effect. Name the exact target, operation, and recovery path in the ask.

On a denial from the reviewer or a forbidden rule, explain the exact command and
reason, use a materially safer alternative if one exists, otherwise ask. Never
retry indirectly or weaken the rules to get around a denial.

`approval_policy = "never"` rejects escalations before the reviewer sees them;
report that as a configuration conflict rather than asking the user to
re-approve authorized work. Restart Codex after changing config or rules and
check the new session's effective permissions.

## Verification

`codex execpolicy check --rules codex/command-safety.rules -- <command tokens>`
shows the rule decision without running the command; the inline `match` /
`not_match` examples are checked when rules load. Run the wiring checker too.

References: [OpenAI automatic review](https://learn.chatgpt.com/docs/sandboxing/auto-review),
[command rules](https://learn.chatgpt.com/docs/agent-configuration/rules), and
[configuration](https://learn.chatgpt.com/docs/config-file/config-reference).
