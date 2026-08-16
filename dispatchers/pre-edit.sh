#!/bin/bash
# GuardRail Pre-Edit Dispatcher
# License: MIT
# PreToolUse hook for Write / Edit / MultiEdit. Can DENY (unlike post-edit,
# which only adds context). Closes the gap where deny-capable guards ran on
# Bash only, letting file-tool writes bypass enforcement entirely.
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDS_DIR="$SCRIPT_DIR/../guards/core"
CUSTOM_DIR="${GUARDRAIL_CUSTOM_GUARDS_DIR:-$SCRIPT_DIR/../guards/custom}"
LIB_DIR="$SCRIPT_DIR/../lib"
INPUT=$(cat)
ALLOW='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'

deny() {
  local reason="$1"
  local rj
  if declare -F guardrail_audit >/dev/null 2>&1; then
    guardrail_audit "PreEditDispatcher" "$reason" "${FILE_PATH:-unavailable}" "blocked"
  fi
  rj=$(printf "%s" "$reason" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":${rj}}}"
  exit 0
}

# Load audit early so even a malformed-payload deny is logged (malformed-input
# probing must be visible in the audit trail, not just blocked silently).
[ -f "$LIB_DIR/guardrail-common.sh" ] && source "$LIB_DIR/guardrail-common.sh" 2>/dev/null

# Validate payload shape; block on anything we cannot inspect.
# file_path for Write/Edit/MultiEdit, notebook_path for NotebookEdit.
if ! printf '%s' "$INPUT" | jq -e '
  type == "object"
  and (.tool_input | type == "object")
  and ((.tool_input.file_path // .tool_input.notebook_path) | type == "string")
  and ((.tool_input.file_path // .tool_input.notebook_path) | length > 0)
' >/dev/null 2>&1; then
  deny "GUARDRAIL INPUT ERROR: malformed or empty Write/Edit/Notebook hook payload. The operation was blocked because it could not be inspected."
fi

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"')
# Content across Write (content), Edit (new_string), MultiEdit (edits[].new_string)
# and NotebookEdit (new_source). Coerce non-string values to their JSON form so
# a secret hidden inside a non-string payload is still scanned instead of
# silently dropped (fail-closed: if jq itself errors, block).
CONTENT=$(printf '%s' "$INPUT" | jq -r '
  [ .tool_input.content, .tool_input.new_string, .tool_input.new_source,
    (.tool_input.edits // [] | .[]?.new_string) ]
  | map(select(. != null) | if type == "string" then . else tojson end)
  | join("\n")
' 2>/dev/null) || deny "GUARDRAIL INPUT ERROR: content could not be extracted for inspection. Blocked to fail closed."

# Respect the same HMAC-gated disable flag as pre-bash.
if [ -f "$SCRIPT_DIR/../.disabled" ]; then
  DISABLE_LINE=$(head -1 "$SCRIPT_DIR/../.disabled" 2>/dev/null)
  DISABLE_TS=$(printf '%s' "$DISABLE_LINE" | awk '{print $1}')
  DISABLE_KEY_FILE="$HOME/.guardrail/disable.key"
  if [ -f "$DISABLE_KEY_FILE" ] && [ -n "$DISABLE_TS" ]; then
    NOW=$(date +%s 2>/dev/null || echo 0)
    AGE=$(( NOW - DISABLE_TS ))
    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt 1800 ]; then
      EXPECTED=$(printf '%s' "$DISABLE_TS" | openssl dgst -sha256 -hmac "$(cat "$DISABLE_KEY_FILE")" 2>/dev/null | awk '{print $NF}')
      ACTUAL=$(printf '%s' "$DISABLE_LINE" | awk '{print $2}')
      [ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] && { echo "$ALLOW"; exit 0; }
    fi
  fi
fi

if [ ! -f "$LIB_DIR/guardrail-common.sh" ] || ! source "$LIB_DIR/guardrail-common.sh"; then
  deny "GUARDRAIL INTEGRITY ERROR: common library could not be loaded."
fi

_guardrail_load_guard() {
  local g="$1"
  [ -f "$GUARDS_DIR/$g" ] || deny "GUARDRAIL INTEGRITY ERROR: required guard $g is missing."
  source "$GUARDS_DIR/$g" || deny "GUARDRAIL INTEGRITY ERROR: guard $g could not be loaded."
}
# Fail-closed: a required core guard whose function is missing after sourcing
# is an integrity failure, not a skip. Mirrors pre-bash.sh. Silently running
# past a missing guard would fail open, exactly what this dispatcher prevents.
_guardrail_run_required() {
  local fn="$1"
  declare -F "$fn" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: required guard function $fn is missing. Blocking to fail closed."
  "$fn" || deny "GUARDRAIL RUNTIME ERROR: guard $fn failed. Blocking to fail closed."
}

_guardrail_load_guard "edit_path_guard.sh"
_guardrail_load_guard "edit_secret_guard.sh"
_guardrail_run_required hook_edit_path_guard
_guardrail_run_required hook_edit_secret_guard

# Custom pre-edit guards: preedit_*.sh
if [ -d "$CUSTOM_DIR" ]; then
  for cg in "$CUSTOM_DIR"/preedit_*.sh; do
    [ -f "$cg" ] || continue
    source "$cg" || deny "GUARDRAIL INTEGRITY ERROR: custom guard $(basename "$cg") could not be loaded."
    lfn="hook_$(basename "$cg" .sh)"
    declare -F "$lfn" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: custom guard function $lfn is missing."
    "$lfn" || deny "GUARDRAIL RUNTIME ERROR: custom guard $lfn failed."
  done
fi

# Pro pre-edit guards: preedit_*.sh (license-gated)
PRO_DIR="${SCRIPT_DIR}/../guards/pro"
if [ -d "$PRO_DIR" ]; then
  source "$LIB_DIR/guardrail-license.sh" || deny "GUARDRAIL INTEGRITY ERROR: license module could not be loaded."
  if _guardrail_check_pro_license; then
    for pg in "$PRO_DIR"/preedit_*.sh; do
      [ -f "$pg" ] || continue
      source "$pg" || deny "GUARDRAIL INTEGRITY ERROR: Pro guard $(basename "$pg") could not be loaded."
      pfn="hook_$(basename "$pg" .sh)"
      declare -F "$pfn" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: Pro guard function $pfn is missing."
      "$pfn" || deny "GUARDRAIL RUNTIME ERROR: Pro guard $pfn failed."
    done
  fi
fi

echo "$ALLOW"
exit 0
