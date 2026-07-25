#!/bin/bash
# GuardRail Core: Basic PII Gate
# Blocks commands that dump full environment or process secrets.
# License: MIT

hook_basic_pii_gate() {
  local e="env" p="printenv" d="declare"

  # Block bare env/printenv commands
  if echo "$CMD_SHELL" | grep -qE "(^|\\s|;|\\||&&)(/usr/bin/)?($e|$p)(\\s|$|\\|)"; then
    guardrail_audit "PII-Gate" "blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "PII-GATE: Command exposes all environment variables. Use specific variable access instead."
    return
  fi

  # Block /proc/environ access
  if echo "$CMD_SHELL" | grep -qiE '/proc/(self|[0-9]+)/environ'; then
    deny "PII-GATE: /proc/environ exposes all process secrets."
    return
  fi

  # Block declare -x (dumps exported vars)
  if echo "$CMD_SHELL" | grep -qE "(^|\\s|;)$d\\s+-x(\\s|$)"; then
    deny "PII-GATE: '$d -x' dumps all exported variables."
    return
  fi

  # Block docker inspect without --format
  if echo "$CMD_SHELL" | grep -qE "docker\\s+inspect\\s" && \
     ! echo "$CMD_SHELL" | grep -qE "docker\\s+inspect\\s+--format"; then
    deny "PII-GATE: docker inspect without --format exposes secrets. Use --format to select specific fields."
    return
  fi

  # Block docker exec env/printenv
  if echo "$CMD_SHELL" | grep -qE "docker\\s+exec\\s.*\\s($e|$p)(\\s|$)"; then
    deny "PII-GATE: docker exec $e/$p dumps container secrets."
    return
  fi
}
