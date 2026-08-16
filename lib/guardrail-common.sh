#!/bin/bash
# GuardRail Common Library
# Shared functions and defaults for all guards.
# License: MIT

# Load config if present
for _cfg in "${GUARDRAIL_HOME:-$HOME/.guardrail}/guardrail.config.sh" "$HOME/.guardrail/guardrail.config.sh"; do
  [ -f "$_cfg" ] && { source "$_cfg"; break; }
done

# --- Configuration with defaults ---
GUARDRAIL_LOG_DIR="${GUARDRAIL_LOG_DIR:-$HOME/.guardrail/logs}"
GUARDRAIL_AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-$HOME/.guardrail/audit.log}"
GUARDRAIL_STATE_DIR="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
GUARDRAIL_CONFIG_DIR="${GUARDRAIL_CONFIG_DIR:-$HOME/.claude}"
GUARDRAIL_WEBHOOK_CMD="${GUARDRAIL_WEBHOOK_CMD:-}"
GUARDRAIL_DB_CONTAINER="${GUARDRAIL_DB_CONTAINER:-postgres}"
GUARDRAIL_BACKUP_DIR="${GUARDRAIL_BACKUP_DIR:-/opt/backups/postgres}"
GUARDRAIL_BACKUP_MAX_AGE_HOURS="${GUARDRAIL_BACKUP_MAX_AGE_HOURS:-6}"
GUARDRAIL_PROTECTED_TABLES="${GUARDRAIL_PROTECTED_TABLES:-auth.users profiles members}"
GUARDRAIL_PROTECTED_BRANCHES="${GUARDRAIL_PROTECTED_BRANCHES:-main master production}"
GUARDRAIL_CRITICAL_SERVICES="${GUARDRAIL_CRITICAL_SERVICES:-docker sshd ssh traefik postgresql postgres nginx}"
GUARDRAIL_PROTECTED_PATHS="${GUARDRAIL_PROTECTED_PATHS:-/home/ /etc/ /var/lib/docker /var/lib/postgresql}"
GUARDRAIL_SAFE_SCRIPT_DIRS="${GUARDRAIL_SAFE_SCRIPT_DIRS:-/usr/ /bin/ /sbin/}"
GUARDRAIL_ALLOWED_LICENSES="${GUARDRAIL_ALLOWED_LICENSES:-MIT Apache-2.0 ISC BSD-2-Clause BSD-3-Clause 0BSD Unlicense CC0-1.0 BlueOak-1.0.0}"
GUARDRAIL_PII_COLUMNS="${GUARDRAIL_PII_COLUMNS:-email full_name first_name last_name phone encrypted_password recovery_token confirmation_token}"
GUARDRAIL_STRICT_MODE="${GUARDRAIL_STRICT_MODE:-true}"
GUARDRAIL_MAX_FILE_SCAN="${GUARDRAIL_MAX_FILE_SCAN:-5}"

# Ensure directories exist
mkdir -p "$GUARDRAIL_LOG_DIR" "$GUARDRAIL_STATE_DIR" 2>/dev/null

# --- Colors (respects NO_COLOR, non-TTY) ---
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  _GR_RED=$'\033[0;31m'
  _GR_GREEN=$'\033[0;32m'
  _GR_YELLOW=$'\033[0;33m'
  _GR_BOLD=$'\033[1m'
  _GR_DIM=$'\033[2m'
  _GR_RESET=$'\033[0m'
else
  _GR_RED="" _GR_GREEN="" _GR_YELLOW="" _GR_BOLD="" _GR_DIM="" _GR_RESET=""
fi

# --- Shared functions ---

_guardrail_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

_guardrail_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

guardrail_log() {
  local guard="$1" message="$2"
  local message_ref
  message_ref=$(printf '%s' "$message" | _guardrail_sha256 | cut -c1-16)
  (umask 077; touch "$GUARDRAIL_LOG_DIR/${guard}.log") 2>/dev/null || return 0
  echo "$(_guardrail_timestamp) [$guard] message-ref:$message_ref" >> "$GUARDRAIL_LOG_DIR/${guard}.log" 2>/dev/null
}

guardrail_audit() {
  local guard="$1" action="$2" detail="$3" decision="${4:-blocked}"
  local detail_ref
  detail_ref=$(printf '%s' "$detail" | _guardrail_sha256 | cut -c1-16)
  (umask 077; touch "$GUARDRAIL_AUDIT_LOG") 2>/dev/null || return 0
  echo "| $(date +%Y-%m-%d\ %H:%M) | $guard | $(echo "$action" | head -c 80 | tr '|' '/') | ${SESSION_ID:-unknown} | command-ref:$detail_ref | $decision |" >> "$GUARDRAIL_AUDIT_LOG" 2>/dev/null
}

guardrail_notify() {
  local guard="$1" reason="$2" severity="${3:-high}"
  if [ -n "$GUARDRAIL_WEBHOOK_CMD" ] && [ -x "$GUARDRAIL_WEBHOOK_CMD" ]; then
    "$GUARDRAIL_WEBHOOK_CMD" "$guard" "$reason" "$severity" &
  fi
}

_guardrail_list_to_regex() {
  printf '%s' "$1" | tr ' ' '\n' | sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//; s/^/(/; s/$/)/'
}

_guardrail_list_to_regex_raw() {
  printf '%s' "$1" | tr ' ' '\n' | tr '\n' '|' | sed 's/|$//; s/^/(/; s/$/)/'
}

# Normalizes . / .. / duplicate slashes in a path WITHOUT resolving symlinks
# and without requiring the path to exist, so that /a/./b, /a//b and /a/../a/b
# all reduce to the same string before a guard matches against it.
#
# This was `realpath -m -s`, which is GNU-only. On macOS that call fails, the
# guard silently kept the raw path, and path-matching protections could be
# stepped around with a leading "./". Implemented in shell so both platforms
# behave identically. Written for bash 3.2, which is what macOS ships.
_guardrail_canonicalize_path() {
  local p="$1"
  [ -n "$p" ] || return 1
  case "$p" in
    /*) ;;
    *) p="$PWD/$p" ;;
  esac

  local part result=""
  local oldifs="$IFS"
  IFS='/'
  # Word splitting on / is the point here, so globbing has to be off or a
  # segment like "*" would expand against the filesystem.
  set -f
  for part in $p; do
    case "$part" in
      ''|.) ;;
      ..) result="${result%/*}" ;;
      *) result="$result/$part" ;;
    esac
  done
  set +f
  IFS="$oldifs"

  printf '%s' "${result:-/}"
}
