#!/bin/bash
# GuardRail Core Guard: error_swallow_guard
# Detects catch blocks that swallow errors instead of propagating them.
# License: MIT
#
# Shared vars: $FILE_PATH, $SESSION_ID, $TOOL_NAME
# Shared fns: add_context()

hook_error_swallow_guard() {
  [ -z "$FILE_PATH" ] && return 0

  echo "$FILE_PATH" | grep -qE '\.(ts|tsx|js|jsx)$' || return 0

  echo "$FILE_PATH" | grep -qiE 'webhook|cron|api/|queue|worker|payment|stripe|booking|notification|email' || return 0

  if [ -f "$FILE_PATH" ]; then
    local suspicious
    suspicious=$(grep -n "catch" "$FILE_PATH" 2>/dev/null | head -5)
    if [ -n "$suspicious" ]; then
      add_context "ERROR-SWALLOW-CHECK: File $FILE_PATH contains catch blocks. Verify: Are errors only logged (console.error) or also propagated (throw, notification)? Rule: Every catch in payment/webhook/cron code MUST either re-throw or send a notification."
    fi
  fi
}
