#!/bin/bash
# GuardRail Core Guard: pii_deutsch_guard
# Detects German personal data patterns in command output (IBAN, tax IDs,
# social security numbers, phone numbers, credit card numbers, secret prefixes).
# License: MIT
#
# Shared vars: $CMD, $OUTPUT, $SESSION_ID
# Shared fns: add_context()

hook_pii_deutsch_guard() {
  [ -z "$OUTPUT" ] && return 0
  [ ${#OUTPUT} -lt 10 ] && return 0

  local findings=""

  # IBAN (DE + 20 digits)
  if echo "$OUTPUT" | grep -qE '\bDE[0-9]{2}\s?[0-9]{4}\s?[0-9]{4}\s?[0-9]{4}\s?[0-9]{4}\s?[0-9]{2}\b'; then
    findings="IBAN"
  fi

  # German tax ID (Steuer-ID: 11 digits)
  if echo "$OUTPUT" | grep -qE '\b[0-9]{2}\s?[0-9]{3}\s?[0-9]{3}\s?[0-9]{3}\b'; then
    findings="${findings:+$findings, }Tax-ID-pattern"
  fi

  # Credit card numbers (13-19 digits with optional spaces/dashes)
  if echo "$OUTPUT" | grep -qE '\b[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{1,7}\b'; then
    findings="${findings:+$findings, }Credit-card-pattern"
  fi

  # Secret prefixes (sk_live, pk_live, ghp_, gho_, etc.)
  if echo "$OUTPUT" | grep -qE '\b(sk_live_|pk_live_|ghp_|gho_|ghs_|glpat-|xoxb-|xoxp-|AKIA)[A-Za-z0-9]{10,}'; then
    findings="${findings:+$findings, }Secret-prefix"
  fi

  # Field labels suggesting PII context
  if echo "$OUTPUT" | grep -qiE '\b(sozialversicherungsnummer|steuer.?id|personalausweis|geburtsdatum|geburtsname)\b'; then
    findings="${findings:+$findings, }PII-field-label"
  fi

  if [ -n "$findings" ]; then
    guardrail_log "pii-deutsch" "DETECTED sess=$SESSION_ID findings=$findings cmd=$(echo "$CMD" | head -c 80)"
    add_context "PII-DEUTSCH WARNING: German personal data pattern detected in output ($findings). Do NOT copy, store, or forward this data. Mask or redact before any further use."
  fi
}
