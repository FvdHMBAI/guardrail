#!/bin/bash
# Guard: wandering_detector
# Detects aimless trial-and-error loops by counting consecutive failures.
# After GUARDRAIL_WANDERING_THRESHOLD failures (default: 3), blocks further
# attempts and requires the agent to consult documentation first.
#
# Recognizes: connection refused, port conflicts, 404s, auth failures,
# missing databases, missing containers.
# License: MIT

GUARDRAIL_WANDERING_THRESHOLD="${GUARDRAIL_WANDERING_THRESHOLD:-3}"

hook_wandering_detector() {
  local state_file="${GUARDRAIL_STATE_DIR}/wandering-${SESSION_ID:-default}"
  local output_lower
  output_lower=$(printf '%s' "$OUTPUT" | tr '[:upper:]' '[:lower:]' | head -20)

  local is_wandering=false

  # Connection errors (wrong IP/port)
  echo "$output_lower" | grep -qE "connection refused|econnrefused|connect etimedout|no route to host" && is_wandering=true

  # Port conflicts
  echo "$output_lower" | grep -qE "address already in use|eaddrinuse|port.*already|listen eaddrinuse" && is_wandering=true

  # 404 on routes (guessing URLs)
  echo "$output_lower" | grep -qE "404 not found|http_code.*404|status: 404" && is_wandering=true

  # Authentication failures
  echo "$output_lower" | grep -qE "invalid.*password|login.*failed|authentication.*failed|permission denied.*publickey|401 unauthorized" && is_wandering=true

  # Database not found
  echo "$output_lower" | grep -qE "database.*does not exist|relation.*does not exist|unknown database" && is_wandering=true

  # Container/service not found
  echo "$output_lower" | grep -qE "no such container|no such service|error: no such" && is_wandering=true

  if [ "$is_wandering" = true ]; then
    local count=0
    [ -f "$state_file" ] && count=$(head -1 "$state_file" 2>/dev/null)
    count=$(( ${count:-0} + 1 ))
    echo "$count" > "$state_file"

    if [ "$count" -ge "$GUARDRAIL_WANDERING_THRESHOLD" ]; then
      add_context "WANDERING DETECTED: ${count} consecutive failures. You are guessing instead of looking things up. STOP and consult documentation, config files, or project README before trying again. Reset with: rm $state_file"
      guardrail_audit "wandering_detector" "trial-and-error loop ($count failures)" "$CMD" "blocked"
    elif [ "$count" -ge 2 ]; then
      add_context "Wandering warning: ${count}/${GUARDRAIL_WANDERING_THRESHOLD} consecutive failures. Check docs before the next attempt."
    fi
  else
    # Success resets the counter
    local exit_code
    exit_code=$(echo "${OUTPUT:-}" | grep -oP 'exit_code.*?(\d+)' | head -1 | grep -oP '\d+$')
    [ "${exit_code:-1}" = "0" ] && rm -f "$state_file" 2>/dev/null
  fi
}
