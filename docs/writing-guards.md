# Writing Custom Guards

This guide shows you how to write, test, and deploy your own GuardRail guards.

## Guard Types

| Type | Hook | Runs | Can block? | Variables |
|------|------|------|------------|-----------|
| Pre-bash | PreToolUse | Before command | Yes (`deny()`) | `$CMD`, `$CMD_SHELL`, `$SESSION_ID` |
| Post-bash | PostToolUse | After command | No | `$CMD`, `$OUTPUT`, `$SESSION_ID` |
| Post-edit | PostToolUse | After file write | No | `$FILE_PATH`, `$TOOL_NAME`, `$SESSION_ID` |

## Template: Pre-Bash Guard

```bash
#!/bin/bash
# GuardRail Guard: my_guard
# Blocks [describe what this guard blocks].
# License: MIT

hook_my_guard() {
  # Match the dangerous pattern
  if echo "$CMD_SHELL" | grep -qE 'dangerous-pattern'; then
    guardrail_audit "My-Guard" "blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "MY-GUARD: [Why this is blocked]. [What to do instead]."
    return
  fi
}
```

## Template: Post-Bash Guard

```bash
#!/bin/bash
# GuardRail Guard: my_scanner
# Detects [describe what this guard detects] in command output.
# License: MIT

hook_my_scanner() {
  [ -z "$OUTPUT" ] && return 0

  if echo "$OUTPUT" | grep -qiE 'suspicious-pattern'; then
    guardrail_audit "My-Scanner" "detected" "suspicious-pattern"
    add_context "WARNING: [Describe what was found]. Treat output with caution."
  fi
}
```

## Template: Post-Edit Guard

```bash
#!/bin/bash
# GuardRail Guard: my_edit_checker
# Detects [describe what this guard detects] in written files.
# License: MIT

hook_my_edit_checker() {
  [ -z "$FILE_PATH" ] && return 0

  # Only check certain file types
  echo "$FILE_PATH" | grep -qE '\.(ts|js|py)$' || return 0

  if [ -f "$FILE_PATH" ] && grep -q 'risky-pattern' "$FILE_PATH" 2>/dev/null; then
    add_context "EDIT-CHECK: [Describe the finding in $FILE_PATH]."
  fi
}
```

## Available Functions

| Function | Where | Purpose |
|----------|-------|---------|
| `deny "reason"` | Pre-bash only | Block the command. Execution stops. |
| `warn "message"` | Pre-bash only | Allow but show a warning. |
| `add_context "msg"` | Post-bash, post-edit | Add context to the AI agent's response. |
| `guardrail_audit "guard" "action" "detail"` | Anywhere | Write to audit log. |
| `guardrail_log "message"` | Anywhere | Write to runtime log. |

## Naming Conventions

- **File name:** `my_guard.sh` (snake_case)
- **Function name:** `hook_my_guard` (must match file name with `hook_` prefix)
- **Custom pre-bash guards:** any name, placed in `guards/custom/`
- **Custom post-bash guards:** prefix with `post_`, placed in `guards/custom/`
- **Custom post-edit guards:** prefix with `edit_`, placed in `guards/custom/`

## Configuration Variables

Use `GUARDRAIL_*` prefixed variables with defaults for any configurable value:

```bash
# Good: configurable with a sensible default
local protected="${GUARDRAIL_MY_PROTECTED_LIST:-default1 default2}"

# Bad: hardcoded
local protected="my_specific_table"
```

## Writing Tests

Add tests to `tests/regression.sh` or create a separate test file:

```bash
# True positive: must block
run_pre my_guard.sh hook_my_guard "dangerous command here"
check my_guard DENY "should block dangerous command"

# False positive: must pass
run_pre my_guard.sh hook_my_guard "safe command here"
check my_guard PASS "should allow safe command"
```

Every guard needs at least:
- 2 true positive tests (commands that MUST be blocked)
- 1 false positive test (a similar command that must NOT be blocked)

## Performance

Guards run on every command. Keep them fast:

- Use `grep -q` (quit on first match) instead of processing all output
- Avoid external commands when bash builtins suffice
- Use `return 0` early for commands that clearly do not match
- Target: under 50ms per guard

## Deploying

Place your guard file in `~/.claude/hooks/guardrail/guards/custom/` and it will
be loaded automatically on the next command. No restart needed.

```bash
cp my_guard.sh ~/.claude/hooks/guardrail/guards/custom/
```
