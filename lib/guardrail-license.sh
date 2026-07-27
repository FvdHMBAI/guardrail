#!/bin/bash
# GuardRail License Validation
# Checks Pro license key against the API with 24h cache.
# License: MIT

_guardrail_check_pro_license() {
  local INSTALL_DIR
  INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local KEY_FILE="$INSTALL_DIR/.license-key"
  local CACHE_FILE="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/license-valid"
  local API_URL="${GUARDRAIL_API_URL:-https://license.guardrail.promptandbuild.de}"
  local CACHE_MAX_AGE=86400  # 24h
  local GRACE_PERIOD=259200  # 72h (API unreachable grace)

  if [ ! -f "$KEY_FILE" ]; then
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
