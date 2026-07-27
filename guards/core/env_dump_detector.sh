#!/bin/bash
# GuardRail Core Guard: env_dump_detector
# Detects environment variable dumps in command output (even from obfuscated commands).
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID, $OUTPUT
# Shared fns: add_context()

hook_env_dump_detector() {
  [ -z "$OUTPUT" ] && return 0

  # Whitelist: safe-env-check is allowed
  echo "$CMD" | grep -qE '(safe-env-check|guardrail.*status)' && return 0

  # Count KEY=VALUE lines (typical env dump pattern)
  local KV_COUNT
  KV_COUNT=$(echo "$OUTPUT" | grep -cE '^[A-Z_][A-Z0-9_]{2,}=.+' 2>/dev/null) || KV_COUNT=0

  if [ "$KV_COUNT" -ge 8 ]; then
    local command_ref session_ref state_file log_file
    command_ref=$(printf '%s' "$CMD" | _guardrail_sha256 | cut -c1-16)
    session_ref=$(printf '%s' "$SESSION_ID" | _guardrail_sha256 | cut -c1-16)
    log_file="${GUARDRAIL_LOG_DIR:-/var/log/guardrail}/pii-scanner.log"
    state_file="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/pii-leak-${session_ref}"
    (umask 077; touch "$log_file" "$state_file") 2>/dev/null

    mkdir -p "${GUARDRAIL_STATE_DIR:-/tmp/guardrail}" 2>/dev/null
    echo "$(_guardrail_timestamp) ENV-DUMP-BLOCKED sess-ref=$session_ref command-ref=$command_ref kv_lines=$KV_COUNT" >> "$log_file" 2>/dev/null
    echo "$(_guardrail_timestamp) ENV-DUMP: $KV_COUNT KEY=VALUE lines; command-ref=$command_ref" > "$state_file" 2>/dev/null

    add_context "ENV DUMP DETECTED: Output contains $KV_COUNT KEY=VALUE lines (likely env/printenv dump). Do NOT use this output. Resolve the session safety marker before continuing."
  fi
}
