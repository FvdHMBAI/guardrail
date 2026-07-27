#!/bin/bash
# GuardRail Core: Basic Secret Detector
# Blocks commands that exfiltrate secrets to known exfiltration domains.
# License: MIT

hook_basic_secret_detector() {
  local secret_variable_re='\$\{?[A-Za-z0-9_]*(API_KEY|SECRET|TOKEN|PASSWORD|CREDENTIALS|DATABASE_URL|PRIVATE_KEY)[A-Za-z0-9_]*\}?'
  # Block known exfiltration domains
  if echo "$CMD_SHELL" | grep -qiE '((^|[[:space:];|&])(command[[:space:]]+)?([^[:space:];|&]*/)?)(curl|wget|fetch|nc)[[:space:]].*(webhook\.site|requestbin\.|pipedream\.|hookbin\.|burpcollaborator\.|interact\.sh|canarytokens\.)'; then
    guardrail_audit "Secret-Detector" "blocked" "exfil-domain"
    deny "SECRET-GUARD: Known exfiltration domain detected. Do not send data to untrusted endpoints."
    return
  fi

  # Block secret variable exfiltration via curl/wget
  if echo "$CMD_SHELL" | grep -qiE "((command[[:space:]]+)?([^[:space:];|&]*/)?)(curl|wget)[[:space:]].*(--data[^[:space:]]*|-d[[:space:]]|--post-data|--header|-H[[:space:]]).*${secret_variable_re}"; then
    deny "SECRET-GUARD: Sending secret variables to external endpoint."
    return
  fi

  # Block base64-encoding of secret variables
  if echo "$CMD_SHELL" | grep -qiE "echo[[:space:]].*${secret_variable_re}.*\\|[[:space:]]*base64"; then
    deny "SECRET-GUARD: Base64-encoding secret variables is a common exfiltration technique."
    return
  fi
}
