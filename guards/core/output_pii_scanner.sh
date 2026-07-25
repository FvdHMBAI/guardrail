#!/bin/bash
# GuardRail Core Guard: output_pii_scanner
# Scans command output for accidentally leaked PII (emails, passwords, tokens).
# License: MIT
#
# Shared vars: $CMD, $OUTPUT, $SESSION_ID
# Shared fns: add_context()

hook_output_pii_scanner() {
  [ -z "$OUTPUT" ] && return 0

  local _pii_cols_re
  _pii_cols_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PII_COLUMNS")

  # Email pattern in output
  if echo "$OUTPUT" | grep -qE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'; then
    if ! echo "$CMD" | grep -qiE '(git log|git blame|npm|package\.json|README|LICENSE)'; then
      guardrail_log "output-pii" "EMAIL-LEAK sess=$SESSION_ID cmd=$(echo "$CMD" | head -c 80)"
      add_context "PII-LEAK WARNING: Email address detected in command output. If this is from a database query, use _safe views. Never copy PII into code or logs."
    fi
  fi

  # Secret patterns in output
  local _secret_re="${GUARDRAIL_SECRET_VARS:-JWT_SECRET SERVICE_ROLE_KEY ANON_KEY POSTGRES_PASSWORD DATABASE_URL SMTP_PASS API_KEY}"
  local _secret_pat; _secret_pat=$(echo "$_secret_re" | tr ' ' '|')
  if echo "$OUTPUT" | grep -qE "(${_secret_pat})="; then
    guardrail_log "output-pii" "SECRET-LEAK sess=$SESSION_ID cmd=$(echo "$CMD" | head -c 80)"
    add_context "SECRET-LEAK WARNING: Secret variable assignment detected in output. Secrets must NEVER appear in terminal output."
  fi

  # JWT token in output
  if echo "$OUTPUT" | grep -qE 'eyJhbGciOi[A-Za-z0-9_-]{20,}'; then
    guardrail_log "output-pii" "JWT-LEAK sess=$SESSION_ID"
    add_context "SECRET-LEAK WARNING: JWT token detected in output. Tokens must never appear in terminal output."
  fi
}
