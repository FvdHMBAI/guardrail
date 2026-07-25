# GuardRail

Pre-execution security guards for AI coding agents.
Open source. Battle-tested. EU AI Act ready.

**Works with:** Claude Code, Cursor, GitHub Copilot, Windsurf

## The Problem

Your AI coding agent runs commands on your machine. It can delete files, push to
production, leak secrets, and drop database tables. Most tools catch problems
*after* they happen. GuardRail catches them *before*.

**EU AI Act enforcement starts August 2, 2026.** If you use AI coding agents in
the EU, you need governance. GuardRail gives you that in one command.

## Quick Start

```bash
npx guardrail-agent init
```

That's it. 10 security guards are now active.

## What It Does

Every command your AI agent runs passes through GuardRail first.
Dangerous operations are blocked before they execute, not after.

```
Agent: "rm -rf /etc"           -> BLOCKED (destructive path)
Agent: "git push origin main"  -> BLOCKED (protected branch)
Agent: "env"                   -> BLOCKED (secret exposure)
Agent: "DELETE FROM users"     -> BLOCKED (mass update)
Agent: "iptables -F"           -> BLOCKED (firewall flush)
```

## Core Guards (MIT)

10 guards that cover the most common risks:

| Guard | Type | Protects Against |
|---|---|---|
| `main_push_guard` | pre-bash | Direct push to main/master, force push, reset --hard |
| `basic_pii_gate` | pre-bash | Environment dumps via env/printenv/docker inspect |
| `basic_secret_detector` | pre-bash | Secret exfiltration to known malicious domains |
| `destructive_path_guard` | pre-bash | rm -rf on system paths (/etc, /usr, /var, /home) |
| `firewall_flush_guard` | pre-bash | iptables flush, ufw disable/reset |
| `service_protection_guard` | pre-bash | Killing critical services (sshd, docker, postgres) |
| `mass_update_guard` | pre-bash | UPDATE/DELETE without WHERE clause |
| `env_dump_detector` | post-bash | Full environment variable dumps in output |
| `basic_injection_scanner` | post-bash | Prompt injection patterns in command output |
| `error_swallow_guard` | post-edit | Empty catch blocks in critical code paths |

## GuardRail Pro

40+ advanced guards derived from real production incidents. Covers attack vectors
that basic guards miss.

| Category | Examples |
|---|---|
| Advanced PII | 15+ leak vectors beyond env/printenv, script content analysis |
| Injection Defense | Multi-step attack detection, semantic injection, skill file poisoning |
| Supply Chain | npm audit integration, license compliance checks |
| Infrastructure | Config file protection, gate file mechanisms, cron job safety |
| Agent Control | Self-bypass prevention, autonomy boundaries, message approval |

Plus: PEN-test framework, EU AI Act compliance reports (PDF), audit trail.

**Pricing:** EUR 20/dev/month | EUR 5,000 compliance kit

Learn more: guardrail.dev/pro

## Configuration

After installation, customize `~/.claude/hooks/guardrail/guardrail.config.sh`:

```bash
# Protected database tables
GUARDRAIL_PROTECTED_TABLES="auth.users profiles members"

# Protected git branches
GUARDRAIL_PROTECTED_BRANCHES="main master production"

# Critical services (blocked from kill/stop)
GUARDRAIL_PROTECTED_SERVICES="sshd nginx postgres docker"

# Strict mode (true = block, false = warn only)
GUARDRAIL_STRICT_MODE="true"
```

## Custom Guards

Add your own guards to `~/.claude/hooks/guardrail/guards/custom/`:

```bash
#!/bin/bash
# Custom guard: block_dangerous_pattern
# License: MIT

hook_block_dangerous_pattern() {
  if echo "$CMD" | grep -q "dangerous-pattern"; then
    deny "BLOCKED: Explain why this is blocked."
  fi
}
```

See [CONTRIBUTING.md](.github/CONTRIBUTING.md) for the full guard-writing guide.

## CLI

```bash
guardrail init             # Install guards into Claude Code
guardrail test             # Run regression tests (41 tests)
guardrail status           # Show active guards and recent activity
guardrail audit            # Generate audit report
guardrail audit --days 30  # Last 30 days
guardrail upgrade          # Learn about GuardRail Pro
```

## EU AI Act Compliance

GuardRail helps meet key requirements of the EU AI Act (Regulation 2024/1689):

| Article | Requirement | GuardRail Solution |
|---|---|---|
| Art. 9 | Risk management | Guard classification, PEN-test framework |
| Art. 10 | Data governance | PII gates, secret output protection |
| Art. 12 | Record-keeping | Audit log with timestamps |
| Art. 14 | Human oversight | deny() gates, approval workflows |
| Art. 15 | Accuracy & robustness | Injection defense, regression tests |

Full compliance mapping available in GuardRail Pro.

## Architecture

```
AI Coding Agent (Claude Code / Cursor / Copilot)
        |
        v
  [Pre-Bash Dispatcher]    <-- Before command runs
        |
  [Guards] ─────────────── DENY  (blocks execution)
        |                   WARN  (adds context)
        v
  [Command Executes]
        |
        v
  [Post-Bash Dispatcher]   <-- After command runs
        |
  [Output Scanners] ────── Context (injection, env dumps)
```

## Requirements

- bash 4+
- jq
- Claude Code (or compatible AI coding tool with hook support)
- Linux or macOS

## License

MIT. See [LICENSE](LICENSE).

## Security

See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

Built by [Prompt & Build](https://promptandbuild.de). Battle-tested in
production with 100+ guards across 15 applications.
