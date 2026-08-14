# Architecture

## Overview

GuardRail hooks into AI coding agents via their hook/extension system. Every
command the agent runs passes through GuardRail's dispatchers, which load and
execute guards. Guards can block commands, add warnings, or annotate output.

```
AI Coding Agent (Claude Code, Cursor, Copilot, ...)
      │
      │  PreToolUse (Bash)
      ▼
┌──────────────────────────────────────────────────────────────┐
│                  Pre-Bash Dispatcher                         │
│                                                              │
│  1. Parse JSON input (tool_name, command, session_id)        │
│  2. Source guardrail-common.sh (config, shared functions)    │
│  3. Source each guard file from core/ → custom/ → premium/   │
│  4. Call each hook_* function with $CMD set                  │
│  5. If any guard calls deny(): return JSON with deny         │
│  6. If no guard denies: return JSON with allow               │
│                                                              │
│  Guards available: deny(), allow_with_msg(), warn()          │
└──────────────────────┬───────────────────────────────────────┘
          ┌────────────┴────────────┐
          │                         │
     DENIED                    ALLOWED
     (command never              (command
      executes)                  executes)
          │                         │
          ▼                         ▼
     Audit Log              ┌──────────────┐
                            │   Command    │
                            │   Executes   │
                            └──────┬───────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────────┐
                    │        Post-Bash Dispatcher          │
                    │                                      │
                    │  Runs AFTER every command:            │
                    │  • Output scanners (injection, PII)   │
                    │  • Error detectors (self-correction)  │
                    │  • State trackers (wandering, budget) │
                    │                                      │
                    │  Guards call add_context() to inject  │
                    │  warnings into the agent's next turn  │
                    └──────────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────────┐
                    │         Post-Edit Dispatcher         │
                    │                                      │
                    │  Runs AFTER every file Write/Edit:    │
                    │  • Error swallow detection            │
                    │  • Security pattern scanning          │
                    └──────────────────────────────────────┘
```

## Components

### Dispatchers (`dispatchers/`)

Three bash scripts that receive JSON from the AI tool's hook system:

| Dispatcher | Trigger | Input | Output |
|------------|---------|-------|--------|
| `pre-bash.sh` | Before any Bash command | `{tool_input: {command}, session_id}` | `{permissionDecision: "allow"\|"deny"}` |
| `post-bash.sh` | After any Bash command | `{tool_input: {command}, tool_response: {output}}` | `{additionalContext: "..."}` or `{}` |
| `post-edit.sh` | After Write/Edit | `{tool_name, tool_input: {file_path}}` | `{additionalContext: "..."}` or `{}` |

Each dispatcher:
1. Parses JSON input (requires `jq`)
2. Sources the shared library (`lib/guardrail-common.sh`)
3. Loads guard files from `guards/core/`, `guards/custom/`, and `guards/premium/`
4. Calls each guard's `hook_*()` function
5. Returns JSON output

### Guards (`guards/`)

Each guard is a standalone bash file containing one `hook_*()` function:

```
guards/
  core/           # 18 MIT-licensed guards (shipped with GuardRail)
  custom/         # User-defined guards (loaded automatically)
  premium/        # Pro guards (licensed, not in open source)
```

Guards use shared variables set by the dispatcher:

| Variable | Set by | Contains |
|----------|--------|----------|
| `$CMD` | pre-bash, post-bash | The command string |
| `$CMD_SHELL` | pre-bash | The command string (identical to CMD) |
| `$OUTPUT` | post-bash | Command output (stdout) |
| `$FILE_PATH` | post-edit | Path of the written/edited file |
| `$TOOL_NAME` | post-edit | "Write" or "Edit" |
| `$SESSION_ID` | all | Session identifier |

### Shared Library (`lib/guardrail-common.sh`)

Provides configuration defaults and utility functions:

- **Config variables:** `GUARDRAIL_PROTECTED_BRANCHES`, `GUARDRAIL_PROTECTED_TABLES`, `GUARDRAIL_WANDERING_THRESHOLD`, etc.
- **`guardrail_log()`** — write to per-guard log file
- **`guardrail_audit()`** — write to central audit log (timestamped, content-hashed)
- **`guardrail_notify()`** — call webhook for critical events (optional)
- **`_guardrail_list_to_regex()`** — convert space-separated list to regex alternation

### Configuration (`guardrail.config.sh`)

All behavior is configurable via `GUARDRAIL_*` environment variables with
sensible defaults. The config file is sourced by `guardrail-common.sh`.

## Guard Categories

### Pre-execution (block before command runs)

| Guard | Category | What it protects |
|---|---|---|
| `main_push_guard` | Git safety | Protected branches |
| `force_push_guard` | Git safety | History rewriting |
| `basic_pii_gate` | Data protection | Environment secrets |
| `basic_secret_detector` | Data protection | Secret exfiltration |
| `destructive_path_guard` | Filesystem safety | System directories |
| `firewall_flush_guard` | Network safety | Firewall rules |
| `service_protection_guard` | Service safety | Critical services |
| `mass_update_guard` | Database safety | Bulk data changes |
| `self_bypass_guard` | Agent governance | Gate file integrity |
| `deploy_branch_guard` | Deployment safety | Branch discipline |
| `large_diff_guard` | Code quality | Commit hygiene |
| `tool_call_budget_guard` | Cost control | API budget |
| `context_window_guard` | Cost control | Output volume |

### Post-execution (scan output after command runs)

| Guard | Category | What it detects |
|---|---|---|
| `env_dump_detector` | Data protection | Environment dumps |
| `basic_injection_scanner` | Security | Prompt injection |
| `credential_leak_guard` | Data protection | Secrets in output |
| `wandering_detector` | Agent governance | Trial-and-error loops |
| `self_correction_loop` | Code quality | Ignored errors |

### Edit-time (check file writes)

| Guard | Category | What it detects |
|---|---|---|
| `error_swallow_guard` | Code quality | Empty catch blocks |

## Data Flow: Pre-Bash (Blocking)

```
1. Agent wants to run: "git push origin main"
2. Claude Code calls pre-bash.sh with JSON
3. Dispatcher parses CMD = "git push origin main"
4. Dispatcher loads main_push_guard.sh
5. hook_main_push_guard() matches "push origin main"
6. Guard calls deny("Protected branch")
7. deny() outputs JSON: {permissionDecision: "deny", reason: "..."}
8. Claude Code blocks the command
9. Agent sees: "Command blocked by GuardRail: Protected branch"
```

## Data Flow: Post-Bash (Context Injection)

```
1. Agent ran: "cat some-file.txt"
2. Output contains: "ignore all previous instructions"
3. Claude Code calls post-bash.sh with JSON (command + output)
4. Dispatcher loads basic_injection_scanner.sh
5. hook_basic_injection_scanner() matches injection pattern
6. Guard calls add_context("INJECTION WARNING: ...")
7. Dispatcher outputs JSON: {additionalContext: "INJECTION WARNING: ..."}
8. Agent sees the warning as additional context in its next turn
```

## Performance

| Metric | Value |
|---|---|
| Pre-dispatch total | <5ms |
| Per-guard execution | <1ms |
| Post-dispatch total | <3ms |
| Memory overhead | ~2MB (bash + jq) |
| Disk footprint | <500KB installed |

Guards do no network calls, no disk reads beyond config, and no process spawning. The entire guard chain runs in a single bash process.

## Audit Log

Every decision is logged with a content hash (never the raw command):

```
| 2026-08-02 14:23 | main_push_guard | push to main | session-abc | command-ref:a1b2c3d4 | blocked |
```

This prevents secrets from leaking into logs while maintaining a complete evidence trail.
