#!/bin/bash
# GuardRail Core Guard: script_pii_guard
# Warns when a written script contains PII queries or secret extraction patterns.
# License: MIT
#
# Shared vars: $FILE_PATH, $SESSION_ID, $TOOL_NAME
# Shared fns: add_context()

hook_script_pii_guard() {
  [ -z "$FILE_PATH" ] && return 0
  echo "$FILE_PATH" | grep -qiE '\.(sh|bash|py|js|mjs)$' || return 0
  echo "$FILE_PATH" | grep -qE '(/tmp/|/scratchpad/)' || return 0
  [ ! -f "$FILE_PATH" ] && return 0

  local CONTENT; CONTENT=$(head -100 "$FILE_PATH" 2>/dev/null)

  local pii_cols="${GUARDRAIL_PII_COLUMNS:-email full_name first_name last_name phone encrypted_password recovery_token confirmation_token}"
  local pii_re; pii_re=$(echo "$pii_cols" | tr ' ' '|')

  # PII columns in SQL queries
  if echo "$CONTENT" | grep -qiE "SELECT[^;]*(${pii_re})\\b" && \
     ! echo "$CONTENT" | grep -qiE '\b(CASE\s+WHEN|length\s*\(|char_length\s*\(|count\s*\()'; then
    add_context "SCRIPT-PII-WARNING: Script '$FILE_PATH' contains SELECT on PII columns. Use indirect checks only (CASE WHEN, length(), count). Do NOT extract raw PII values."
  fi

  # Secret extraction patterns
  if echo "$CONTENT" | grep -qiE '(cat|grep|sed|awk)\b.*\.(env|conf)\b|printenv|docker inspect.*Env'; then
    add_context "SCRIPT-PII-WARNING: Script '$FILE_PATH' contains secret extraction patterns (.env/.conf/printenv/docker inspect). Secrets must NOT appear in output."
  fi

  local secret_vars="${GUARDRAIL_SECRET_VARS:-JWT_SECRET SERVICE_ROLE_KEY ANON_KEY POSTGRES_PASSWORD DATABASE_URL SMTP_PASS API_KEY}"
  local secret_re; secret_re=$(echo "$secret_vars" | tr ' ' '|')

  if echo "$CONTENT" | grep -qE "\\$(${secret_re})"; then
    add_context "SCRIPT-PII-WARNING: Script '$FILE_PATH' references secret env vars. Output of this script must NOT contain secrets or tokens."
  fi
}
