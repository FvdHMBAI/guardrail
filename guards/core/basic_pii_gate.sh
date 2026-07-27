#!/bin/bash
# GuardRail Core: Basic PII Gate
# Blocks commands that dump full environment or process secrets.
# License: MIT

hook_basic_pii_gate() {
  # Block bare env/printenv commands
  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:];|&])([^[:space:];|&]*/)?(busybox[[:space:]]+)?(env|printenv)([[:space:];|&]|$)'; then
    guardrail_audit "PII-Gate" "blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "PII-GATE: Command exposes all environment variables. Use specific variable access instead."
    return
  fi

  # Block /proc/environ access
  if echo "$CMD_SHELL" | grep -qiE '/proc/(self|[0-9]+)/environ'; then
    guardrail_audit "PII-Gate" "blocked" "/proc/environ"
    deny "PII-GATE: /proc/environ exposes all process secrets."
    return
  fi

  # Block declare -x (dumps exported vars)
  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:];|&])(declare|typeset)[[:space:]]+-x([[:space:];|&]|$)'; then
    guardrail_audit "PII-Gate" "blocked" "declare -x"
    deny "PII-GATE: 'declare -x' dumps all exported variables."
    return
  fi

  # Other common shell builtins that enumerate exported variables.
  if echo "$CMD_SHELL" | grep -qE '(^|[[:space:];|&])export[[:space:]]+-p([[:space:];|&]|$)' \
     || echo "$CMD_SHELL" | grep -qE '(^|[[:space:];|&])compgen[[:space:]]+-e([[:space:];|&]|$)' \
     || echo "$CMD_SHELL" | grep -qE '(^|[;|&][[:space:]]*)set([[:space:]]+-o[[:space:]]+posix)?[[:space:]]*($|[;|&])'; then
    guardrail_audit "PII-Gate" "Shell environment enumeration blocked" "environment-enumeration"
    deny "PII-GATE: Shell environment enumeration can expose all process secrets. Query only the specific non-secret variable required."
  fi

  # Block docker inspect without --format
  if echo "$CMD_SHELL" | grep -qE 'docker\s+inspect\s' && \
     ! echo "$CMD_SHELL" | grep -qE 'docker\s+inspect\s+--format'; then
    guardrail_audit "PII-Gate" "blocked" "docker inspect"
    deny "PII-GATE: docker inspect without --format exposes secrets. Use --format to select specific fields."
    return
  fi

  # Block docker exec env/printenv
  if echo "$CMD_SHELL" | grep -qE 'docker\s+exec\s.*\s(env|printenv)(\s|$)'; then
    guardrail_audit "PII-Gate" "blocked" "docker exec env"
    deny "PII-GATE: docker exec env/printenv dumps container secrets."
    return
  fi
}
