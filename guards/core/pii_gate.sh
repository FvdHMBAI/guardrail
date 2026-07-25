#!/bin/bash
# GuardRail Core Guard: pii_gate
# Prevents PII leaks through database queries, environment variables,
# docker commands, .env files, and scripting language env access.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny(), warn()

_pii_deny() {
  local reason="$1"
  guardrail_log "pii-gate" "DENY sess=$SESSION_ID reason=\"$reason\" cmd=\"$(echo "$CMD" | head -c 200)\""
  guardrail_audit "PII-Gate" "$reason" "$(echo "$CMD" | head -c 60)"
  guardrail_notify "pii" "$reason" "high"
  deny "$reason"
}

hook_pii_gate() {
  local _state="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
  if [ -f "$_state/pii-open" ]; then
    rm -f "$_state/pii-open"; return 0
  fi
  local _tables_re; _tables_re=$(_guardrail_list_to_regex "$GUARDRAIL_PROTECTED_TABLES")
  local _pii_cols_re; _pii_cols_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PII_COLUMNS")

  if echo "$CMD" | grep -qiE '(record_out|row_to_text|textin)\s*\(' && echo "$CMD" | grep -qiE "${_tables_re}"; then
    _pii_deny "PII-GATE: SQL trick detected (record_out/row_to_text on protected tables)."
  fi
  if echo "$CMD" | grep -qiE "SELECT\s+\*\s+FROM\s+${_tables_re}\b" && ! echo "$CMD" | grep -qiE '_safe'; then
    _pii_deny "PII-GATE: SELECT * on protected PII table is blocked. Use _safe views."
  fi
  if echo "$CMD" | grep -qiE "select[^;]*${_pii_cols_re}" && ! echo "$CMD" | grep -qiE 'information_schema|pg_catalog|\\\d '; then
    if echo "$CMD" | grep -qiE '\b(CASE\s+WHEN|length\s*\(|char_length\s*\(|LIKE\s)'; then
      :
    elif ! echo "$CMD" | grep -qiE '(from|join)[[:space:]]+[a-z_."]*_safe'; then
      _pii_deny "PII-GATE: SELECT on PII columns only allowed on _safe views. Bypass: touch $_state/pii-open"
    fi
  fi
  if echo "$CMD" | grep -qE '(^|\s|;|\||&&|"|'"'"')(/usr/bin/)?(env|printenv)(\s|$|\||"|'"'"')'; then
    _pii_deny "PII-GATE: env/printenv exposes secrets in terminal output."
  fi
  if echo "$CMD" | grep -qE '/proc/(self|[0-9]+)/environ'; then
    _pii_deny "PII-GATE: /proc/*/environ contains all environment variables including secrets."
  fi
  if echo "$CMD" | grep -qE '(^|\s|;|\||&&)declare\s+-x(\s|$|\|)'; then
    _pii_deny "PII-GATE: declare -x dumps all exported variables including secrets."
  fi
  if echo "$CMD" | grep -qiE '(python3?|perl|node|ruby)\s.*\b(os\.environ|ENV|process\.env|ENV\.to_hash)\b'; then
    _pii_deny "PII-GATE: Environment access via scripting language detected."
  fi
  if echo "$CMD" | grep -qiE 'docker exec [^|;]+ (env|printenv)(\s|$|\||"|'"'"')'; then
    _pii_deny "PII-GATE: docker exec env/printenv exposes secrets."
  fi
  if echo "$CMD" | grep -qiE 'ssh\s+[^ ]+\s+.*\b(env|printenv)\b'; then
    _pii_deny "PII-GATE: env/printenv via SSH exposes secrets."
  fi
  if echo "$CMD" | grep -qiE 'docker\s+inspect\b' && ! echo "$CMD" | grep -qiE '\-\-format|\-f '; then
    _pii_deny "PII-GATE: docker inspect WITHOUT --format dumps ALL env vars."
  fi
  if echo "$CMD" | grep -qiE "docker inspect.*--format.*Config[._]Env"; then
    _pii_deny "PII-GATE: docker inspect --format with Env is blocked."
  fi
  if echo "$CMD" | grep -qE '\b(cat|head|tail|less|more|grep|awk|sed|tac|strings|xxd|od|hexdump)\b[^|;]*\.env(\s|$|\.)'; then
    _pii_deny "PII-GATE: .env files contain secrets."
  fi
  if echo "$CMD" | grep -qiE 'ssh\s+[^ ]+\s+.*\b(cat|head|tail|grep|awk|sed|tac|strings)\b.*\.env(\s|$|\.|"|'"'"')'; then
    _pii_deny "PII-GATE: Reading .env files via SSH is blocked."
  fi
  if echo "$CMD" | grep -qiE 'ssh\s+[^ ]+\s+["\x27].*\$[A-Z_]*(KEY|SECRET|TOKEN|PASS|JWT|ANON)[A-Z_]*'; then
    _pii_deny "PII-GATE: SSH command with local secret variable expansion detected."
  fi
}
