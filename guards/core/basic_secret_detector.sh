#!/bin/bash
# GuardRail Core: Basic Secret Detector
# Blocks commands that exfiltrate secrets to known exfiltration domains.
# License: MIT

hook_basic_secret_detector() {
  # Block known exfiltration domains
  if echo "$CMD" | grep -qiP '(curl|wget|fetch|nc)\s.*(webhook\.site|requestbin\.|pipedream\.|hookbin\.|burpcollaborator\.|interact\.sh|canarytokens\.)'; then
    guardrail_audit "Secret-Detector" "blocked" "exfil-domain"
    deny "SECRET-GUARD: Known exfiltration domain detected. Do not send data to untrusted endpoints."
    return
  fi

  # Block secret variable exfiltration via curl/wget
  if echo "$CMD" | grep -qiP '(curl|wget)\s.*(-d|--data|--data-raw|--data-binary)\s.*\$\{?(API_KEY|SECRET|TOKEN|PASSWORD|CREDENTIALS|AWS_SECRET)'; then
    deny "SECRET-GUARD: Sending secret variables to external endpoint."
    return
  fi

  # Block base64-encoding of secret variables
  if echo "$CMD" | grep -qiP 'echo\s.*\$\{?(API_KEY|SECRET|TOKEN|PASSWORD|AWS_SECRET).*\|\s*base64'; then
    deny "SECRET-GUARD: Base64-encoding secret variables is a common exfiltration technique."
    return
  fi
}
