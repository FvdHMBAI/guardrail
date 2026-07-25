# Architecture

## Overview

GuardRail hooks into AI coding agents via their hook/extension system. Every
command the agent runs passes through GuardRail's dispatchers, which load and
execute guards. Guards can block commands, add warnings, or annotate output.

```
AI Coding Agent
  |
  |  PreToolUse (Bash)
  v
+------------------+
| pre-bash.sh      |  Dispatcher
|  +-------------+ |
|  | Guard 1     | |---> deny()  = BLOCK command
|  | Guard 2     | |---> warn()  = ALLOW with message
|  | Guard N     | |
|  +-------------+ |
+------------------+
  |
  v
Command Executes
  |
  |  PostToolUse (Bash)
  v
+------------------+
| post-bash.sh     |  Dispatcher
|  +-------------+ |
|  | Scanner 1   | |---> add_context() = annotate response
|  | Scanner 2   | |
|  +-------------+ |
+------------------+
  |
  |  PostToolUse (Write/Edit)
  v
+------------------+
| post-edit.sh     |  Dispatcher
|  +-------------+ |
|  | Checker 1   | |---> add_context() = annotate response
|  +-------------+ |
+------------------+
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
3. Loads guard files from `guards/core/` and `guards/custom/`
4. Calls each guard's `hook_*()` function
5. Returns JSON output

### Guards (`guards/`)

Each guard is a standalone bash file containing one `hook_*()` function:

```
guards/
  core/           # 10 MIT-licensed guards (shipped with GuardRail)
  custom/         # User-defined guards (loaded automatically)
  premium/        # Pro guards (not included in open source)
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

- **Config variables:** `GUARDRAIL_PROTECTED_BRANCHES`, `GUARDRAIL_PROTECTED_TABLES`, etc.
- **`guardrail_log()`** -- write to runtime log
- **`guardrail_audit()`** -- write to audit log (timestamped, structured)
- **`guardrail_notify()`** -- call webhook for critical events (optional)

### Configuration (`guardrail.config.sh`)

All behavior is configurable via `GUARDRAIL_*` environment variables with
sensible defaults. The config file is sourced by `guardrail-common.sh`.

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

## Data Flow: Post-Bash (Context)

```
1. Agent ran: "cat some-file.txt"
2. Output contains: "ignore all previous instructions"
3. Claude Code calls post-bash.sh with JSON (command + output)
4. Dispatcher loads basic_injection_scanner.sh
5. hook_basic_injection_scanner() matches injection pattern
6. Guard calls add_context("INJECTION WARNING: ...")
7. Dispatcher outputs JSON: {additionalContext: "INJECTION WARNING: ..."}
8. Agent sees the warning as additional context
```

## Custom Guard Loading

Custom guards are loaded from `GUARDRAIL_CUSTOM_GUARDS_DIR` (default:
`guards/custom/`). The dispatcher matches guards by filename prefix:

| Prefix | Loaded by |
|--------|-----------|
| (any) | pre-bash dispatcher (all custom guards) |
| `post_` | post-bash dispatcher |
| `edit_` | post-edit dispatcher |

## Profiles (Pro)

GuardRail Pro supports command profiles that activate additional guards based
on what the command does:

| Profile | Activates when | Additional guards |
|---------|----------------|-------------------|
| `database` | Command contains psql/mysql/sqlite | DB-specific guards |
| `docker` | Command contains docker/podman | Container guards |
| `remote` | Command contains ssh/scp | Remote execution guards |
| `deploy` | Command contains deploy/release | Deployment guards |

Core GuardRail activates `mass_update_guard` for psql commands as a basic
example of profile-based activation.
