#!/bin/bash
# GuardRail Pre-Bash Dispatcher
# Orchestrates PreToolUse Bash guards.
# JSON is parsed once, guards loaded context-sensitively by command profile.
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

# Strip heredoc body from git commit commands
CMD_SHELL="$CMD"
if echo "$CMD" | grep -qE 'git commit\b.*<<'; then
  CMD_SHELL=$(echo "$CMD" | sed '/<<.*EOF/,/^[[:space:]]*EOF/d; /<<.*HEREDOC/,/^[[:space:]]*HEREDOC/d')
  [ -z "$CMD_SHELL" ] && CMD_SHELL="$CMD"
fi

ALLOW='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
WARNINGS=""

[ -z "$CMD" ] && { echo "$ALLOW"; exit 0; }

deny() {
  local reason="$1"
  local rjson; rjson=$(printf '%s' "$reason" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":${rjson}}}"
  exit 0
}

allow_with_msg() {
  local msg="$1"
  local json; json=$(printf '%s' "$msg" | jq -Rs .)
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"permissionDecisionReason\":$json}}"
  exit 0
}

warn() {
  local msg="$1"
  if [ -z "$WARNINGS" ]; then
    WARNINGS="$msg"
  else
    WARNINGS="$WARNINGS | $msg"
  fi
}

# --- Load guard helper ---
_guardrail_load_guard() {
  local guard="$1"
  [ -f "$GUARDS_DIR/$guard" ] && source "$GUARDS_DIR/$guard"
}

_guardrail_run() {
  local fn="$1"
  declare -F "$fn" >/dev/null && "$fn"
}

# --- Security gates (ALWAYS run, non-negotiable) ---
_guardrail_load_guard "tabu_gate.sh"
_guardrail_load_guard "pii_gate.sh"
_guardrail_load_guard "api_key_guard.sh"
_guardrail_load_guard "secret_output_guard.sh"
_guardrail_load_guard "main_push_guard.sh"
_guardrail_load_guard "destructive_path_guard.sh"
_guardrail_load_guard "firewall_flush_guard.sh"
_guardrail_load_guard "service_protection_guard.sh"
_guardrail_load_guard "infra_file_guard.sh"
_guardrail_load_guard "anti_self_bypass_guard.sh"
_guardrail_load_guard "gate_file_guard.sh"
_guardrail_load_guard "agent_control_policy_guard.sh"
_guardrail_load_guard "pre_exec_file_scanner.sh"

_guardrail_run hook_tabu_gate
_guardrail_run hook_pii_gate
_guardrail_run hook_api_key_guard
_guardrail_run hook_secret_output_guard
_guardrail_run hook_main_push_guard
_guardrail_run hook_destructive_path_guard
_guardrail_run hook_firewall_flush_guard
_guardrail_run hook_service_protection_guard
_guardrail_run hook_infra_file_guard
_guardrail_run hook_anti_self_bypass_guard
_guardrail_run hook_gate_file_guard
_guardrail_run hook_agent_control_policy_guard
_guardrail_run hook_pre_exec_file_scanner

# --- Profile-specific guards ---
case "$CMD" in
  *"psql"*|*"ALTER TABLE"*|*"DROP TABLE"*|*"DELETE FROM"*|*"TRUNCATE"*|*"CREATE TABLE"*|*"docker exec"*psql*)
    _guardrail_load_guard "mass_update_guard.sh"
    _guardrail_load_guard "db_backup_gate.sh"
    _guardrail_run hook_mass_update_guard
    _guardrail_run hook_db_backup_gate
    ;;
  *"npm "*|*"npx "*|*"yarn "*|*"pnpm "*)
    _guardrail_load_guard "npm_audit_guard.sh"
    _guardrail_load_guard "license_compliance_guard.sh"
    _guardrail_run hook_npm_audit_guard
    _guardrail_run hook_license_compliance_guard
    ;;
  *"crontab"*|*"cron"*)
    _guardrail_load_guard "cron_delete_guard.sh"
    _guardrail_run hook_cron_delete_guard
    ;;
  *"curl "*|*"wget "*|*"ssh "*|*"scp "*)
    _guardrail_load_guard "curl_exitcode_guard.sh"
    _guardrail_run hook_curl_exitcode_guard
    ;;
  *"slack"*|*"email"*|*"smtp"*|*"sendgrid"*|*"postmark"*)
    _guardrail_load_guard "message_post_guard.sh"
    _guardrail_run hook_message_post_guard
    ;;
esac

# --- Load custom guards ---
if [ -d "$CUSTOM_DIR" ]; then
  for custom_guard in "$CUSTOM_DIR"/*.sh; do
    [ -f "$custom_guard" ] || continue
    source "$custom_guard"
    local_fn="hook_$(basename "$custom_guard" .sh)"
    declare -F "$local_fn" >/dev/null && "$local_fn"
  done
fi

# Output result
if [ -n "$WARNINGS" ]; then
  allow_with_msg "$WARNINGS"
else
  echo "$ALLOW"
  exit 0
fi
