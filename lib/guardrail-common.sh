#!/bin/bash
# GuardRail Common Library
# Shared functions and defaults for all guards.
# License: MIT

# Load config if present
for _cfg in "./guardrail.config.sh" "$HOME/.guardrail/guardrail.config.sh" "${GUARDRAIL_HOME:-$HOME/.guardrail}/guardrail.config.sh"; do
  [ -f "$_cfg" ] && { source "$_cfg"; break; }
done

# --- Configuration with defaults ---
GUARDRAIL_LOG_DIR="${GUARDRAIL_LOG_DIR:-/var/log/guardrail}"
GUARDRAIL_AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"
GUARDRAIL_STATE_DIR="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
GUARDRAIL_CONFIG_DIR="${GUARDRAIL_CONFIG_DIR:-$HOME/.claude}"
GUARDRAIL_WEBHOOK_CMD="${GUARDRAIL_WEBHOOK_CMD:-}"
GUARDRAIL_DB_CONTAINER="${GUARDRAIL_DB_CONTAINER:-postgres}"
GUARDRAIL_BACKUP_DIR="${GUARDRAIL_BACKUP_DIR:-/opt/backups/postgres}"
GUARDRAIL_BACKUP_MAX_AGE_HOURS="${GUARDRAIL_BACKUP_MAX_AGE_HOURS:-6}"
GUARDRAIL_PROTECTED_TABLES="${GUARDRAIL_PROTECTED_TABLES:-auth.users profiles members}"
GUARDRAIL_PROTECTED_BRANCHES="${GUARDRAIL_PROTECTED_BRANCHES:-main master production}"
GUARDRAIL_CRITICAL_SERVICES="${GUARDRAIL_CRITICAL_SERVICES:-coolify coolify-proxy docker sshd ssh traefik postgresql postgres nginx}"
GUARDRAIL_PROTECTED_PATHS="${GUARDRAIL_PROTECTED_PATHS:-/opt/ /home/ /etc/ /var/lib/docker /var/lib/postgresql /mnt/}"
GUARDRAIL_SAFE_SCRIPT_DIRS="${GUARDRAIL_SAFE_SCRIPT_DIRS:-/usr/ /bin/ /sbin/}"
GUARDRAIL_ALLOWED_LICENSES="${GUARDRAIL_ALLOWED_LICENSES:-MIT Apache-2.0 ISC BSD-2-Clause BSD-3-Clause 0BSD Unlicense CC0-1.0 BlueOak-1.0.0}"
GUARDRAIL_PII_COLUMNS="${GUARDRAIL_PII_COLUMNS:-email full_name first_name last_name phone encrypted_password recovery_token confirmation_token}"
GUARDRAIL_STRICT_MODE="${GUARDRAIL_STRICT_MODE:-true}"
GUARDRAIL_MAX_FILE_SCAN="${GUARDRAIL_MAX_FILE_SCAN:-5}"

# Ensure directories exist
mkdir -p "$GUARDRAIL_LOG_DIR" "$GUARDRAIL_STATE_DIR" 2>/dev/null

# --- Shared functions ---

guardrail_log() {
  local guard="$1" message="$2"
  echo "$(date -Iseconds) [$guard] $message" >> "$GUARDRAIL_LOG_DIR/${guard}.log" 2>/dev/null
}

guardrail_audit() {
  local guard="$1" action="$2" detail="$3" decision="${4:-blocked}"
  echo "| $(date +%Y-%m-%d\ %H:%M) | $guard | $(echo "$action" | head -c 80 | tr '|' '/') | ${SESSION_ID:-unknown} | $(echo "$detail" | head -c 60 | tr '|' '/') | $decision |" >> "$GUARDRAIL_AUDIT_LOG" 2>/dev/null
}

guardrail_notify() {
  local guard="$1" reason="$2" severity="${3:-high}"
  if [ -n "$GUARDRAIL_WEBHOOK_CMD" ] && [ -x "$GUARDRAIL_WEBHOOK_CMD" ]; then
    "$GUARDRAIL_WEBHOOK_CMD" "$guard" "$reason" "$severity" &
  fi
}

_guardrail_list_to_regex() {
  echo "$1" | tr ' ' '\n' | sed 's/\./\\./g' | paste -sd'|' | sed 's/^/(/; s/$/)/'
}

_guardrail_list_to_regex_raw() {
  echo "$1" | tr ' ' '\n' | paste -sd'|' | sed 's/^/(/; s/$/)/'
}
