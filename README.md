# GuardRail

Pre-execution security guards for AI coding agents.
30 guards. Self-improving. EU AI Act ready.

**Works with:** Claude Code, Cursor, GitHub Copilot, Windsurf

## The Problem

Your AI coding agent runs commands on your machine. It can delete files, push to
production, leak secrets, and drop database tables. Most tools catch problems
*after* they happen. GuardRail catches them *before*.

**EU AI Act enforcement starts August 2, 2026.** If you use AI coding agents in
the EU (or serve EU customers), you need governance. GuardRail gives you that in
one command.

## Quick Start

```bash
npx guardrail init
```

That's it. 30 security guards are now active in your Claude Code setup.

## What It Does

Every command your AI agent runs passes through GuardRail first.
Dangerous operations are blocked before they execute, not after.

```
Agent: "rm -rf /etc"           -> BLOCKED (destructive path)
Agent: "git push origin main"  -> BLOCKED (protected branch)
Agent: "env"                   -> BLOCKED (secret exposure)
Agent: "DROP TABLE users"      -> BLOCKED (protected table)
Agent: "cat .env.local"        -> BLOCKED (secret file)
```

## Guards

### Security Gates (always active)

| Guard | Protects Against |
|---|---|
| `tabu_gate` | Destructive DB operations (DROP, TRUNCATE, ALTER postgres) |
| `pii_gate` | PII/secret leaks via env, docker inspect, .env files |
| `main_push_guard` | Direct push to protected branches, force push, reset --hard |
| `secret_output_guard` | Secrets in grep output, JWT tokens in echo |
| `pre_exec_file_scanner` | Scanning referenced scripts for dangerous content |
| `api_key_guard` | API key exposure in commands |
| `destructive_path_guard` | rm -rf on system paths |
| `firewall_flush_guard` | iptables flush, ufw disable |
| `service_protection_guard` | Killing critical services (sshd, docker, postgres) |
| `infra_file_guard` | Modifications to infrastructure config files |
| `gate_file_guard` | Gate file mechanism for approval workflows |
| `agent_control_policy_guard` | Agent autonomy boundaries |

### Injection Defense

| Guard | Protects Against |
|---|---|
| `prompt_injection_scanner` | Prompt injection in tool output |
| `semantic_injection_guard` | Semantic manipulation attempts |
| `multi_step_attack_guard` | Multi-step attack sequences |
| `skill_injection_guard` | Malicious content in skill/config files |
| `anti_self_bypass_guard` | Agent attempting to bypass its own guards |

### Code Quality

| Guard | Protects Against |
|---|---|
| `error_swallow_guard` | Empty catch blocks, silenced errors |
| `silent_failure_detector` | Operations that fail without indication |
| `mass_update_guard` | UPDATE/DELETE without WHERE clause |
| `script_pii_guard` | PII patterns in written scripts |

### Package Security

| Guard | Protects Against |
|---|---|
| `npm_audit_guard` | Installing packages with known vulnerabilities |
| `license_compliance_guard` | Packages with non-permissive licenses |

### Operations

| Guard | Protects Against |
|---|---|
| `cron_delete_guard` | Deleting cron jobs without backup |
| `curl_exitcode_guard` | curl without error checking |
| `message_post_guard` | Posting messages without approval |
| `db_backup_gate` | DB changes without recent backup |
| `env_dump_detector` | Full environment dumps in output |

## Configuration

After installation, customize `~/.claude/hooks/guardrail/guardrail.config.sh`:

```bash
# Protected database tables
GUARDRAIL_PROTECTED_TABLES="auth.users profiles members your_table"

# Protected git branches
GUARDRAIL_PROTECTED_BRANCHES="main master production staging"

# Critical services (blocked from kill/stop)
GUARDRAIL_PROTECTED_SERVICES="sshd nginx postgres docker"

# Webhook for critical events (Slack, PagerDuty, etc.)
GUARDRAIL_WEBHOOK_CMD="/path/to/your/webhook.sh"

# Strict mode (true = block, false = warn only)
GUARDRAIL_STRICT_MODE="true"
```

## Custom Guards

Add your own guards to `~/.claude/hooks/guardrail/guards/custom/`:

```bash
#!/bin/bash
# Custom guard: block-my-thing
# License: MIT

hook_block_my_thing() {
  if echo "$CMD" | grep -q "dangerous-pattern"; then
    deny "BLOCKED: Explain why this is blocked."
  fi
}
```

Pre-bash custom guards are loaded automatically. Name post-bash guards with
`post_` prefix and post-edit guards with `edit_` prefix.

## CLI

```bash
guardrail init           # Install guards
guardrail test           # Run regression tests
guardrail status         # Show active guards
guardrail audit          # Generate audit report
guardrail audit --days 30  # Last 30 days
```

## EU AI Act Compliance

GuardRail helps you meet key requirements of the EU AI Act (Regulation 2024/1689):

| Article | Requirement | GuardRail Solution |
|---|---|---|
| Art. 9 | Risk management | Guard classification, PEN-test framework |
| Art. 10 | Data governance | PII gates, secret output protection |
| Art. 12 | Record-keeping | Audit log, gate audit trail |
| Art. 14 | Human oversight | deny() gates, approval workflows |
| Art. 15 | Accuracy & robustness | Injection defense, regression tests |

## Architecture

```
Claude Code / Cursor / Copilot
        |
        v
  [Pre-Bash Dispatcher]  <-- Before command runs
        |
        v
  [Security Gates]  -----> DENY (blocks execution)
  [Profile Guards]  -----> WARN (adds context)
        |
        v
  [Command Executes]
        |
        v
  [Post-Bash Dispatcher]  <-- After command runs
        |
        v
  [Output Scanners]  -----> Context (injection, PII, failures)
```

Guards are bash functions loaded by dispatchers. Each guard receives the command
(pre-bash) or the output (post-bash) and can block, warn, or add context.

## Requirements

- bash 4+
- jq
- Claude Code (or compatible AI coding tool)
- Linux or macOS

## License

MIT. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md).

---

Built by [Prompt & Build](https://promptandbuild.de). Battle-tested in
production with 100+ guards across 15 applications.
