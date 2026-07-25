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
deny() { local reason="$1"; local rj; rj=$(printf "%s" "$reason" | jq -Rs .); echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":${rj}}}"; exit 0; }
allow_with_msg() { local m="$1"; local j; j=$(printf "%s" "$m" | jq -Rs .); echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":$j}}"; exit 0; }
warn() { local m="$1"; [ -z "$WARNINGS" ] && WARNINGS="$m" || WARNINGS="$WARNINGS | $m"; }
_guardrail_load_guard() { local g="$1"; [ -f "$GUARDS_DIR/$g" ] && source "$GUARDS_DIR/$g"; }
_guardrail_run() { local f="$1"; declare -F "$f" >/dev/null && "$f"; }
_guardrail_load_guard "main_push_guard.sh"
_guardrail_load_guard "tabu_gate.sh"
_guardrail_load_guard "pii_gate.sh"
_guardrail_load_guard "secret_output_guard.sh"
_guardrail_load_guard "destructive_path_guard.sh"
_guardrail_load_guard "firewall_flush_guard.sh"
_guardrail_load_guard "service_protection_guard.sh"
_guardrail_load_guard "api_key_guard.sh"
_guardrail_load_guard "anti_self_bypass_guard.sh"
_guardrail_load_guard "gate_file_guard.sh"
_guardrail_load_guard "agent_control_policy_guard.sh"
_guardrail_run hook_main_push_guard
_guardrail_run hook_tabu_gate
_guardrail_run hook_pii_gate
_guardrail_run hook_secret_output_guard
_guardrail_run hook_destructive_path_guard
_guardrail_run hook_firewall_flush_guard
_guardrail_run hook_service_protection_guard
_guardrail_run hook_api_key_guard
_guardrail_run hook_anti_self_bypass_guard
_guardrail_run hook_gate_file_guard
_guardrail_run hook_agent_control_policy_guard
case "$CMD" in
  *"psql"*|*"docker exec"*psql*)
    _guardrail_load_guard "mass_update_guard.sh"; _guardrail_run hook_mass_update_guard
    _guardrail_load_guard "db_backup_gate.sh"; _guardrail_run hook_db_backup_gate
    ;;
  *"npm"*) _guardrail_load_guard "npm_audit_guard.sh"; _guardrail_run hook_npm_audit_guard;;
  *"curl"*) _guardrail_load_guard "curl_exitcode_guard.sh"; _guardrail_run hook_curl_exitcode_guard;;
  *"crontab"*|*"cron"*) _guardrail_load_guard "cron_delete_guard.sh"; _guardrail_run hook_cron_delete_guard;;
esac
if [ -d "$CUSTOM_DIR" ]; then for cg in "$CUSTOM_DIR"/*.sh; do [ -f "$cg" ] || continue; source "$cg"; lfn="hook_$(basename "$cg" .sh)"; declare -F "$lfn" >/dev/null && "$lfn"; done; fi
if [ -n "$WARNINGS" ]; then allow_with_msg "$WARNINGS"; else echo "$ALLOW"; exit 0; fi
