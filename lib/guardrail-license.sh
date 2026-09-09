#!/bin/bash
# GuardRail License Validation
# Checks Pro license key against the API with 24h cache.
# License: MIT

GUARDRAIL_TRIAL_DAYS="${GUARDRAIL_TRIAL_DAYS:-14}"

# Local instance secret, shared with the disable token. Created by install.sh,
# 0600, and edit_path_guard blocks file-tool writes to it, so an agent cannot
# mint its own stamps. Same trust model as .disabled: it stops the agent and
# accidental resets, not the human who owns the machine.
_guardrail_trial_key_file() { echo "${HOME}/.guardrail/disable.key"; }

# Signs a unix timestamp exactly like the disable token: HMAC-SHA256 against
# the local key, truncated to 32 hex chars.
_guardrail_trial_sign() {
  local ts="$1" key_file
  key_file=$(_guardrail_trial_key_file)
  [ -f "$key_file" ] || return 1
  printf '%s' "$ts" |
    openssl dgst -sha256 -hmac "$(cat "$key_file")" 2>/dev/null |
    awk '{print $NF}' | cut -c1-32
}

# Writes "<ts> <signature>" so the stamp cannot be forged by writing a bare
# timestamp. Creates the local key if an older install never generated one.
_guardrail_write_trial_stamp() {
  local INSTALL_DIR="$1"
  local ts key_file sig
  ts=$(date +%s)
  key_file=$(_guardrail_trial_key_file)
  if [ ! -f "$key_file" ]; then
    mkdir -p "$(dirname "$key_file")" || return 1
    head -c 32 /dev/urandom | base64 | tr -d '\n' > "$key_file" || return 1
    chmod 600 "$key_file" 2>/dev/null || true
    chmod 700 "$(dirname "$key_file")" 2>/dev/null || true
  fi
  sig=$(_guardrail_trial_sign "$ts") || return 1
  [ -n "$sig" ] || return 1
  printf '%s %s\n' "$ts" "$sig" > "$INSTALL_DIR/.trial-started"
}

# Days remaining, or -1 for "no valid trial". An unsigned or wrongly signed
# stamp counts as no trial, not as a fresh one.
_guardrail_trial_days_left() {
  local INSTALL_DIR="$1"
  local TRIAL_FILE="$INSTALL_DIR/.trial-started"
  [ -f "$TRIAL_FILE" ] || { echo "-1"; return; }
  local line ts sig expected
  line=$(head -1 "$TRIAL_FILE" 2>/dev/null)
  ts=$(printf '%s' "$line" | awk '{print $1}')
  sig=$(printf '%s' "$line" | awk '{print $2}')
  [[ "$ts" =~ ^[0-9]+$ ]] || { echo "-1"; return; }
  [ -n "$sig" ] || { echo "-1"; return; }
  expected=$(_guardrail_trial_sign "$ts") || { echo "-1"; return; }
  [ -n "$expected" ] && [ "$expected" = "$sig" ] || { echo "-1"; return; }
  echo $(( GUARDRAIL_TRIAL_DAYS - ( ($(date +%s) - ts) / 86400 ) ))
}

_guardrail_check_pro_license() {
  local INSTALL_DIR
  INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local KEY_FILE="$INSTALL_DIR/.license-key"
  local CACHE_FILE="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/license-valid"
  local API_URL="${GUARDRAIL_API_URL:-https://license.guardrail.promptandbuild.de}"
  local CACHE_MAX_AGE=86400  # 24h
  local GRACE_PERIOD=259200  # 72h (API unreachable grace)

  if [ ! -f "$KEY_FILE" ]; then
    local trial_left
    trial_left=$(_guardrail_trial_days_left "$INSTALL_DIR")
    [ "$trial_left" -gt 0 ] 2>/dev/null && return 0
    return 1
  fi

  local LICENSE_KEY
  LICENSE_KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ -z "$LICENSE_KEY" ]; then
    return 1
  fi

  if [ -f "$CACHE_FILE" ]; then
    local CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    local CACHE_CONTENT
    CACHE_CONTENT=$(cat "$CACHE_FILE" 2>/dev/null)

    if [ "$CACHE_AGE" -lt "$CACHE_MAX_AGE" ] && [ "$CACHE_CONTENT" = "valid" ]; then
      return 0
    fi

    if [ "$CACHE_AGE" -lt "$GRACE_PERIOD" ] && [ "$CACHE_CONTENT" = "valid" ]; then
      local RESPONSE
      RESPONSE=$(curl -sf -m 5 -X POST "$API_URL/api/license/validate" \
        -H 'Content-Type: application/json' \
        -d "{\"key\":\"$LICENSE_KEY\"}" 2>/dev/null)

      if [ $? -ne 0 ]; then
        return 0
      fi

      if echo "$RESPONSE" | grep -q '"valid":true'; then
        echo "valid" > "$CACHE_FILE" 2>/dev/null
        return 0
      else
        rm -f "$CACHE_FILE" 2>/dev/null
        return 1
      fi
    fi
  fi

  local RESPONSE
  RESPONSE=$(curl -sf -m 5 -X POST "$API_URL/api/license/validate" \
    -H 'Content-Type: application/json' \
    -d "{\"key\":\"$LICENSE_KEY\"}" 2>/dev/null)

  if [ $? -ne 0 ]; then
    if [ -f "$CACHE_FILE" ]; then
      local CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
      if [ "$CACHE_AGE" -lt "$GRACE_PERIOD" ]; then
        return 0
      fi
    fi
    return 1
  fi

  if echo "$RESPONSE" | grep -q '"valid":true'; then
    echo "valid" > "$CACHE_FILE" 2>/dev/null
    return 0
  fi

  rm -f "$CACHE_FILE" 2>/dev/null
  return 1
}
