#!/bin/bash
# GuardRail Pre-Bash Dispatcher
# License: MIT
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
    guardrail_audit "Dispatcher" "$reason" "${CMD:-unavailable}" "blocked"
  fi
  rj=$(printf "%s" "$reason" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":${rj}}}"
  exit 0
}

if [ ! -f "$LIB_DIR/guardrail-common.sh" ] || ! source "$LIB_DIR/guardrail-common.sh"; then
  deny "GUARDRAIL INTEGRITY ERROR: common safety library could not be loaded."
fi

# A security boundary must fail closed. A Bash hook without a valid command is
# not a harmless no-op: it means the dispatcher cannot inspect the action.
if ! printf '%s' "$INPUT" | jq -e '
  type == "object"
  and (.tool_input | type == "object")
  and (.tool_input.command | type == "string")
  and (.tool_input.command | length > 0)
' >/dev/null 2>&1; then
  SESSION_ID="invalid-input"
  guardrail_audit "Dispatcher" "Malformed Bash hook payload blocked" "$INPUT"
  deny "GUARDRAIL INPUT ERROR: malformed or empty Bash hook payload. Command execution was blocked because it could not be inspected."
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"')
CMD_SHELL="$CMD"
WARNINGS=""

allow_with_msg() {
  local m="$1"
  local j
  j=$(printf "%s" "$m" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":$j}}"
  exit 0
}
warn() { local m="$1"; [ -z "$WARNINGS" ] && WARNINGS="$m" || WARNINGS="$WARNINGS | $m"; }
_guardrail_load_guard() {
  local g="$1"
  [ -f "$GUARDS_DIR/$g" ] || deny "GUARDRAIL INTEGRITY ERROR: required guard $g is missing."
  source "$GUARDS_DIR/$g" || deny "GUARDRAIL INTEGRITY ERROR: guard $g could not be loaded."
}
_guardrail_run() {
  local f="$1"
  declare -F "$f" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: required function $f is missing."
  "$f" || deny "GUARDRAIL RUNTIME ERROR: guard $f failed and command execution was blocked."
}
# Core guards (MIT)
_guardrail_load_guard "main_push_guard.sh"
_guardrail_load_guard "basic_pii_gate.sh"
_guardrail_load_guard "basic_secret_detector.sh"
_guardrail_load_guard "destructive_path_guard.sh"
_guardrail_load_guard "firewall_flush_guard.sh"
_guardrail_load_guard "service_protection_guard.sh"
_guardrail_run hook_main_push_guard
_guardrail_run hook_basic_pii_gate
_guardrail_run hook_basic_secret_detector
_guardrail_run hook_destructive_path_guard
_guardrail_run hook_firewall_flush_guard
_guardrail_run hook_service_protection_guard
case "${CMD,,}" in
  *"psql"*|*"pgcli"*|*"docker exec"*psql*)
    _guardrail_load_guard "mass_update_guard.sh"; _guardrail_run hook_mass_update_guard
    ;;
esac
if [ -d "$CUSTOM_DIR" ]; then
  for cg in "$CUSTOM_DIR"/*.sh; do
    [ -f "$cg" ] || continue
    source "$cg" || deny "GUARDRAIL INTEGRITY ERROR: custom guard $(basename "$cg") could not be loaded."
    lfn="hook_$(basename "$cg" .sh)"
    declare -F "$lfn" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: custom guard function $lfn is missing."
    "$lfn" || deny "GUARDRAIL RUNTIME ERROR: custom guard $lfn failed."
  done
fi

PRO_DIR="${SCRIPT_DIR}/../guards/pro"
if [ -d "$PRO_DIR" ]; then
  source "$LIB_DIR/guardrail-license.sh" || deny "GUARDRAIL INTEGRITY ERROR: license module could not be loaded."
  if _guardrail_check_pro_license; then
    for pg in "$PRO_DIR"/*.sh; do
      [ -f "$pg" ] || continue
      source "$pg" || deny "GUARDRAIL INTEGRITY ERROR: Pro guard $(basename "$pg") could not be loaded."
      pfn="hook_$(basename "$pg" .sh)"
      declare -F "$pfn" >/dev/null || deny "GUARDRAIL INTEGRITY ERROR: Pro guard function $pfn is missing."
      "$pfn" || deny "GUARDRAIL RUNTIME ERROR: Pro guard $pfn failed."
    done
  fi
fi
if [ -n "$WARNINGS" ]; then allow_with_msg "$WARNINGS"; else echo "$ALLOW"; exit 0; fi
