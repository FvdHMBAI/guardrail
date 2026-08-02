#!/bin/bash
# Guard: tool_call_budget_guard
# Tracks the number of tool calls in a session and warns/blocks when
# the agent is consuming too many. Prevents runaway agents from burning
# through context windows and API credits.
#
# Configurable:
#   GUARDRAIL_TOOL_CALL_WARN (default: 25) — warn threshold
#   GUARDRAIL_TOOL_CALL_MAX  (default: 50) — hard block threshold
# License: MIT

GUARDRAIL_TOOL_CALL_WARN="${GUARDRAIL_TOOL_CALL_WARN:-25}"
GUARDRAIL_TOOL_CALL_MAX="${GUARDRAIL_TOOL_CALL_MAX:-50}"

hook_tool_call_budget_guard() {
  local counter_file="${GUARDRAIL_STATE_DIR}/tool-calls-${SESSION_ID:-default}"

  local count=0
  [ -f "$counter_file" ] && count=$(head -1 "$counter_file" 2>/dev/null)
  count=$(( ${count:-0} + 1 ))
  echo "$count" > "$counter_file"

  if [ "$count" -ge "$GUARDRAIL_TOOL_CALL_MAX" ]; then
    deny "Tool call budget exceeded: ${count}/${GUARDRAIL_TOOL_CALL_MAX} calls this session. Break the task into smaller steps or start a new session. Reset with: rm $counter_file"
    guardrail_audit "tool_call_budget_guard" "budget exceeded ($count calls)" "$CMD" "blocked"
    return 0
  fi

  if [ "$count" -ge "$GUARDRAIL_TOOL_CALL_WARN" ]; then
    allow_with_msg "Tool call budget warning: ${count}/${GUARDRAIL_TOOL_CALL_MAX} calls. Consider whether the current approach is efficient."
  fi
}
