#!/bin/bash
# GuardRail Core Guard: api_key_guard
# Blocks hardcoded API keys, writing keys to files, and attempts to send
# credentials to external endpoints.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()

hook_api_key_guard() {
  # Direct key assignment
  if echo "$CMD" | grep -qiP '(export|=)\s*(OPENAI_API_KEY|GOOGLE_API_KEY|MISTRAL_API_KEY|COHERE_API_KEY|REPLICATE_API_TOKEN|AWS_SECRET_ACCESS_KEY)\s*='; then
    guardrail_audit "api_key_guard" "$CMD" "hardcoded API key" "blocked"
    deny "API-KEY-GUARD: Hardcoding API keys is blocked. Read them from your secret manager or the process environment instead."
  fi

  # Writing keys to files
  if echo "$CMD" | grep -qiP '(echo|printf|cat|tee)\s.*\$?(OPENAI|GOOGLE|MISTRAL|COHERE|REPLICATE|ANTHROPIC|AWS|JWT).*>\s'; then
    guardrail_audit "api_key_guard" "$CMD" "key written to file" "blocked"
    deny "API-KEY-GUARD: Writing keys to files is blocked. A committed or world-readable key is a disclosed key. Use your secret manager or environment variables."
  fi

  # Indirect exfiltration through network clients
  if echo "$CMD" | grep -qiP '(curl|wget|nc|ncat|socat)\s.*\$\{?(ANTHROPIC_API_KEY|OPENAI_API_KEY|SERVICE_ROLE_KEY|JWT_SECRET|DATABASE_URL|API_KEY|SECRET_KEY|AUTH_TOKEN|ACCESS_TOKEN|PASSWORD)'; then
    guardrail_audit "api_key_guard" "$CMD" "credential exfiltration attempt" "blocked"
    guardrail_notify "api_key_guard" "credential exfiltration attempt" "critical"
    deny "API-KEY-GUARD: Exfiltration attempt detected. Credential variables must not be passed to curl, wget, nc or socat."
  fi

  # Known request-capture services, commonly used to collect leaked secrets
  if echo "$CMD" | grep -qiP '(curl|wget|fetch|nc)\s.*(webhook\.site|requestbin\.|pipedream\.|hookbin\.|burpcollaborator|interact\.sh|oastify\.com)'; then
    guardrail_audit "api_key_guard" "$CMD" "request-capture domain" "blocked"
    guardrail_notify "api_key_guard" "request-capture domain contacted" "critical"
    deny "API-KEY-GUARD: A known request-capture domain was detected. These services collect whatever is sent to them and are blocked."
  fi

  # Base64 encoding of secrets, a common way to slip them past naive filters
  if echo "$CMD" | grep -qiP 'base64.*\$\{?(ANTHROPIC|OPENAI|AWS|JWT|API_KEY|SECRET|TOKEN|PASSWORD)|(ANTHROPIC|OPENAI|AWS|JWT|API_KEY|SECRET|TOKEN|PASSWORD).*\|\s*base64'; then
    guardrail_audit "api_key_guard" "$CMD" "base64-encoded secret" "blocked"
    deny "API-KEY-GUARD: Base64 encoding of a credential was detected. Encoding a secret does not protect it and is blocked."
  fi
}
