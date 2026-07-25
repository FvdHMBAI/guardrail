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
    echo "$(date -Iseconds) ENV-DUMP-BLOCKED sess=$SESSION_ID cmd=$(echo "$CMD" | head -c 80) kv_lines=$KV_COUNT" >> "${GUARDRAIL_LOG_DIR:-/var/log/guardrail}/pii-scanner.log" 2>/dev/null

    mkdir -p "${GUARDRAIL_STATE_DIR:-/tmp/guardrail}" 2>/dev/null
    echo "$(date -Iseconds) ENV-DUMP: $KV_COUNT KEY=VALUE lines in output (cmd: $(echo "$CMD" | head -c 60))" > "${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/pii-leak-$SESSION_ID" 2>/dev/null

    add_context "ENV DUMP DETECTED: Output contains $KV_COUNT KEY=VALUE lines (likely env/printenv dump). Do NOT use this output! Session end blocked until: rm ${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/pii-leak-$SESSION_ID"
  fi
}
