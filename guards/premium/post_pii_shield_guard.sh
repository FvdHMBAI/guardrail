#!/bin/bash
# GuardRail Pro: PII Shield Guard
# Scans agent command output for personal data using the GuardRail PII Shield API.
# Blocks or warns when PII is detected in outputs.
# License: Proprietary (GuardRail Pro)
#
# Hook type: post-bash
# Shared vars: $OUTPUT, $CMD, $SESSION_ID
# Shared fns: add_context(), guardrail_audit()
#
# Config:
#   GUARDRAIL_PII_SHIELD_URL   API base URL (default: https://shield.promptandbuild.de)
#   GUARDRAIL_PII_SHIELD_KEY   API key (falls back to .license-key)
#   GUARDRAIL_PII_COUNTRIES    Comma-separated country codes (default: de,at)
#   GUARDRAIL_PII_MODE         "warn" (default) or "block"
#   GUARDRAIL_PII_MAX_LENGTH   Max output chars to scan (default: 5000)
#   GUARDRAIL_PII_TIMEOUT      API timeout in seconds (default: 3)

hook_post_pii_shield_guard() {
  local shield_url="${GUARDRAIL_PII_SHIELD_URL:-https://shield.promptandbuild.de}"
  local shield_key="${GUARDRAIL_PII_SHIELD_KEY:-}"
  local shield_countries="${GUARDRAIL_PII_COUNTRIES:-de,at}"
  local shield_mode="${GUARDRAIL_PII_MODE:-warn}"
  local shield_max_len="${GUARDRAIL_PII_MAX_LENGTH:-5000}"
  local shield_timeout="${GUARDRAIL_PII_TIMEOUT:-3}"

  [ -z "$OUTPUT" ] && return 0
  [ ${#OUTPUT} -lt 20 ] && return 0

  if [ -z "$shield_key" ]; then
    local INSTALL_DIR
    INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local KEY_FILE="$INSTALL_DIR/.license-key"
    [ -f "$KEY_FILE" ] && shield_key=$(cat "$KEY_FILE" 2>/dev/null | tr -d '[:space:]')
  fi
  [ -z "$shield_key" ] && return 0

  local scan_text="$OUTPUT"
  if [ ${#scan_text} -gt "$shield_max_len" ]; then
    scan_text="${scan_text:0:$shield_max_len}"
  fi

  local payload
  payload=$(jq -n --arg text "$scan_text" --arg laender "$shield_countries" \
    '{text: $text, laender: ($laender | split(","))}')

  local response
  response=$(curl -sf -m "$shield_timeout" \
    -X POST "$shield_url/v1/classify" \
    -H "Authorization: Bearer $shield_key" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null) || return 0

  local stufe
  stufe=$(echo "$response" | jq -r '.stufe // "FREI"' 2>/dev/null)

  case "$stufe" in
    SICHER)
      local findings
      findings=$(echo "$response" | jq -r '(.kategorien // []) | join(", ")' 2>/dev/null)
      guardrail_audit "PII-Shield" "PII detected: $findings" "$(echo "$CMD" | head -c 60)" "blocked"

      if [ "$shield_mode" = "block" ]; then
        add_context "PII-SHIELD BLOCKED: Personal data detected in output ($findings). Output suppressed. Review command: $(echo "$CMD" | head -c 80)"
      else
        add_context "PII-SHIELD WARNING: Personal data detected in output ($findings). Review before sharing."
      fi
      ;;
    PRUEFEN)
      local suspects
      suspects=$(echo "$response" | jq -r '(.kategorien // []) | join(", ")' 2>/dev/null)
      guardrail_audit "PII-Shield" "Possible PII: $suspects" "$(echo "$CMD" | head -c 60)" "warned"
      add_context "PII-SHIELD NOTICE: Possible personal data in output ($suspects). Verify before sharing."
      ;;
  esac
}
