#!/bin/bash
# Guard: credential_leak_guard
# Post-execution guard that scans command output for leaked credentials.
# Detects API keys, tokens, passwords, and other secrets in plain text.
#
# Unlike basic_secret_detector (which checks commands), this checks OUTPUT
# for accidentally exposed secrets.
# License: MIT

hook_credential_leak_guard() {
  local out="${OUTPUT:-}"
  [ -z "$out" ] && return 0

  local head_out
  head_out=$(printf '%s' "$out" | head -50)

  local detected=""

  # AWS keys
  echo "$head_out" | grep -qE 'AKIA[0-9A-Z]{16}' && detected="$detected AWS-access-key"

  # Generic API keys (long hex/base64 strings after key= or token= or api_key=)
  echo "$head_out" | grep -qiE '(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|bearer)\s*[=:]\s*["\x27]?[A-Za-z0-9+/]{20,}' && detected="$detected api-key/token"

  # Private keys
  echo "$head_out" | grep -qE 'BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY' && detected="$detected private-key"

  # Database connection strings with passwords
  echo "$head_out" | grep -qiE '(postgres|mysql|mongodb|redis)://[^:]+:[^@]+@' && detected="$detected db-connection-string"

  # JWT tokens
  echo "$head_out" | grep -qE 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.' && detected="$detected jwt-token"

  # Stripe keys
  echo "$head_out" | grep -qE '(sk_live|sk_test|pk_live|pk_test|rk_live|rk_test)_[A-Za-z0-9]{10,}' && detected="$detected stripe-key"

  # GitHub tokens
  echo "$head_out" | grep -qE '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}' && detected="$detected github-token"

  # Anthropic keys
  echo "$head_out" | grep -qE 'sk-ant-[A-Za-z0-9_-]{20,}' && detected="$detected anthropic-key"

  # OpenAI keys
  echo "$head_out" | grep -qE 'sk-[A-Za-z0-9]{40,}' && detected="$detected openai-key"

  if [ -n "$detected" ]; then
    add_context "CREDENTIAL LEAK DETECTED in output:${detected}. The command output contains what appears to be secrets. Do NOT include this output in any response, log, or commit. Investigate the source and rotate affected credentials."
    guardrail_audit "credential_leak_guard" "credential in output:${detected}" "$CMD" "detected"
  fi
}
