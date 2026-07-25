#!/bin/bash
# GuardRail Post-Edit Dispatcher
# Orchestrates PostToolUse Write/Edit guards.
# Guards add context via add_context() for inline feedback.
# License: MIT

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDS_DIR="$SCRIPT_DIR/../guards/core"
CUSTOM_DIR="${GUARDRAIL_CUSTOM_GUARDS_DIR:-$SCRIPT_DIR/../guards/custom}"
LIB_DIR="$SCRIPT_DIR/../lib"

source "$LIB_DIR/guardrail-common.sh"

# --- Parse JSON once ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null)

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

# Core guards only
_guardrail_load_guard "error_swallow_guard.sh"

_guardrail_run hook_error_swallow_guard

# --- Load custom post-edit guards ---
if [ -d "$CUSTOM_DIR" ]; then
  for custom_guard in "$CUSTOM_DIR"/edit_*.sh; do
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
