# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.4.x   | Yes       |
| < 0.4   | No        |

## Enforcement coverage

GuardRail enforces on **both** mutation surfaces the agent can use:

- **Bash commands** — `PreToolUse` on `Bash` (deny-capable).
- **File writes** — `PreToolUse` on `Write` / `Edit` / `MultiEdit` / `NotebookEdit` (deny-capable),
  added in 0.4.0.

Before 0.4.0, deny-capable guards ran on Bash only; file-tool writes were seen
by a `PostToolUse` (advisory) hook after the write had already happened. An
agent could therefore create the disable file, overwrite a privileged path, or
write secrets to disk without a blocking guard ever inspecting it. 0.4.0 closes
this by inspecting `file_path` and content **before** the write. General rule:
every deny-capable guard set must cover all mutation primitives of the runtime,
not just the shell.

## Reporting a Vulnerability

If you discover a security vulnerability in GuardRail, please report it
responsibly. **Do not open a public issue.**

1. Email: security@promptandbuild.de
2. Include: description, reproduction steps, impact assessment
3. We will acknowledge within 48 hours
4. We aim to provide a fix within 7 days for critical issues

## Scope

GuardRail is a pre-execution guard system. Vulnerabilities in scope include:

- Guard bypass techniques (commands that should be blocked but are not)
- Dispatcher logic errors that skip guards
- Configuration injection (manipulating GUARDRAIL_* variables to weaken guards)
- Audit log tampering or evasion

Out of scope:

- Vulnerabilities in Claude Code, Cursor, or other AI tools themselves
- Issues that require root access (GuardRail assumes the host is trusted)
- Social engineering of the AI agent (GuardRail guards commands, not conversations)

## Responsible Disclosure

We follow a 90-day disclosure policy. After reporting, we will:

1. Confirm the vulnerability
2. Develop and test a fix
3. Release the fix
4. Credit you in the changelog (unless you prefer anonymity)

After 90 days, you may disclose publicly regardless of fix status.
