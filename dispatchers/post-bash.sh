#!/bin/bash
# GuardRail Post-Bash Dispatcher
# Orchestrates PostToolUse Bash guards.
# Guards add context via add_context() instead of blocking.
# License: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDS_DIR="$SCRIPT_DIR/../guards/core"
CUSTOM_DIR="${GUARDRAIL_CUSTOM_GUARDS_DIR:-$SCRIPT_DIR/../guards/custom}"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/guardrail-common.sh"

# --- Parse JSON once ---
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // .tool_response // ""' 2>/dev/null)

CONTEXT_PARTS=()

add_context() {
  CONTEXT_PARTS+=("$1")
}

# --- Load and run guards ---
_guardrail_load_guard() {
  local guard="$1"
  [ -f "$GUARDS_DIR/$guard" ] && source "$GUARDS_DIR/$guard"
}

_guardrail_run() {
  local fn="$1"
  declare -F "$fn" >/dev/null && "$fn"
}

_guardrail_load_guard "output_pii_scanner.sh"
_guardrail_load_guard "prompt_injection_scanner.sh"
_guardrail_load_guard "multi_step_attack_guard.sh"
_guardrail_load_guard "semantic_injection_guard.sh"
_guardrail_load_guard "silent_failure_detector.sh"
_guardrail_load_guard "env_dump_detector.sh"
_guardrail_load_guard "pii_deutsch_guard.sh"

_guardrail_run hook_output_pii_scanner
_guardrail_run hook_prompt_injection_scanner
_guardrail_run hook_multi_step_attack_guard
_guardrail_run hook_semantic_injection_guard
_guardrail_run hook_silent_failure_detector
_guardrail_run hook_env_dump_detector
_guardrail_run hook_pii_deutsch_guard

# --- Load custom post-bash guards ---
if [ -d "$CUSTOM_DIR" ]; then
  for custom_guard in "$CUSTOM_DIR"/post_*.sh; do
    [ -f "$custom_guard" ] || continue
    source "$custom_guard"
    local_fn="hook_$(basename "$custom_guard" .sh)"
    declare -F "$local_fn" >/dev/null && "$local_fn"
  done
fi

# Output collected context
if [ ${#CONTEXT_PARTS[@]} -gt 0 ]; then
  COMBINED=""
  for part in "${CONTEXT_PARTS[@]}"; do
    [ -n "$COMBINED" ] && COMBINED="$COMBINED\n\n"
    COMBINED="$COMBINED$part"
  done
  json=$(printf '%s' "$COMBINED" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":${json}}}"
else
  echo '{}'
fi
exit 0
