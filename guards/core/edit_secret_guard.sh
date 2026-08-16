#!/bin/bash
# GuardRail Core Guard: edit_secret_guard
# License: MIT
# Runs in the PreToolUse pre-edit dispatcher (Write/Edit/MultiEdit).
# Shared vars: $FILE_PATH, $CONTENT, $SESSION_ID
# Shared fns: deny()
#
# Blocks writing high-confidence live secrets into files through the agent's
# file tools. Mirrors the bash secret detector for the write path. Kept
# deliberately narrow (known key formats only) to avoid false positives on
# placeholders and documentation.

hook_edit_secret_guard() {
  local content="$CONTENT"
  [ -z "$content" ] && return 0

  # High-confidence live-credential formats. Placeholders (x's, <...>, YOUR_)
  # are excluded by requiring realistic entropy/charset in the token body.
  local hit=""
  # AWS access key id
  printf '%s' "$content" | grep -qE 'AKIA[0-9A-Z]{16}' && hit="AWS access key"
  # Stripe live secret key
  [ -z "$hit" ] && printf '%s' "$content" | grep -qE 'sk_live_[0-9a-zA-Z]{24,}' && hit="Stripe live secret key"
  # Private key block
  [ -z "$hit" ] && printf '%s' "$content" | grep -qE 'BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY' && hit="private key block"
  # GitHub token
  [ -z "$hit" ] && printf '%s' "$content" | grep -qE 'gh[pousr]_[0-9A-Za-z]{36,}' && hit="GitHub token"
  # Slack token
  [ -z "$hit" ] && printf '%s' "$content" | grep -qE 'xox[baprs]-[0-9A-Za-z-]{20,}' && hit="Slack token"
  # Google API key
  [ -z "$hit" ] && printf '%s' "$content" | grep -qE 'AIza[0-9A-Za-z_-]{35}' && hit="Google API key"

  if [ -n "$hit" ]; then
    guardrail_audit "edit_secret_guard" "live secret written to file ($hit)" "$FILE_PATH" "blocked"
    deny "Secret blocked: a live $hit would be written to $FILE_PATH. Never commit real credentials to files. Use environment variables or a secret manager and reference them at runtime."
    return 0
  fi

  return 0
}
