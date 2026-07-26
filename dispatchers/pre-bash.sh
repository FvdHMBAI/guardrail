#!/bin/bash
# GuardRail Pre-Bash Dispatcher
# License: MIT
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARDS_DIR="$SCRIPT_DIR/../guards/core"
CUSTOM_DIR="${GUARDRAIL_CUSTOM_GUARDS_DIR:-$SCRIPT_DIR/../guards/custom}"
LIB_DIR="$SCRIPT_DIR/../lib"
source "$LIB_DIR/guardrail-common.sh"
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r ".tool_input.command // """ 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r ".session_id // "default"" 2>/dev/null)
CMD_SHELL="$CMD"
ALLOW='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
WARNINGS=""
[ -z "$CMD" ] && { echo "$ALLOW"; exit 0; }
deny() {
  local reason="$1"
  local rj
  rj=$(printf "%s" "$reason" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":${rj}}}"
  exit 0
}

allow_with_msg() {
  local m="$1"
  local j
  j=$(printf "%s" "$m" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":$j}}"
  exit 0
}
warn() { local m="$1"; [ -z "$WARNINGS" ] && WARNINGS="$m" || WARNINGS="$WARNINGS | $m"; }
_guardrail_load_guard() { local g="$1"; [ -f "$GUARDS_DIR/$g" ] && source "$GUARDS_DIR/$g"; }
_guardrail_run() { local f="$1"; declare -F "$f" >/dev/null && "$f"; }
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
case "$CMD" in
  *"psql"*|*"docker exec"*psql*)
    _guardrail_load_guard "mass_update_guard.sh"; _guardrail_run hook_mass_update_guard
    ;;
esac
if [ -d "$CUSTOM_DIR" ]; then
  for cg in "$CUSTOM_DIR"/*.sh; do
    [ -f "$cg" ] || continue
    source "$cg"
    lfn="hook_$(basename "$cg" .sh)"
    declare -F "$lfn" >/dev/null && "$lfn"
  done
fi

PRO_DIR="${SCRIPT_DIR}/../guards/pro"
if [ -d "$PRO_DIR" ]; then
  source "$LIB_DIR/guardrail-license.sh"
  if _guardrail_check_pro_license; then
    for pg in "$PRO_DIR"/*.sh; do
      [ -f "$pg" ] || continue
      source "$pg"
      pfn="hook_$(basename "$pg" .sh)"
      declare -F "$pfn" >/dev/null && "$pfn"
    done
  fi
fi
if [ -n "$WARNINGS" ]; then allow_with_msg "$WARNINGS"; else echo "$ALLOW"; exit 0; fi
