#!/bin/bash
# GuardRail Core Guard: message_post_guard
# Blocks sending emails, chat messages, and notifications without admin approval.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()

hook_message_post_guard() {
  local _state="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
  if echo "$CMD" | grep -qiE '\b(msmtp|sendmail|mail\s+-s|smtp|swaks)\b'; then
    if [ ! -f "$_state/msg-approved" ]; then
      deny "MESSAGE-GUARD: Sending email is blocked without admin approval. Show the exact text first, then get approval: touch $_state/msg-approved"
    fi
    rm -f "$_state/msg-approved"
  fi
  if echo "$CMD" | grep -qiE 'curl.*(/api/messages|/api/.*comments|/api/.*chat|/api/.*notify).*POST'; then
    if [ ! -f "$_state/msg-approved" ]; then
      deny "MESSAGE-GUARD: Posting messages via API is blocked without admin approval. Show the exact text first, then get approval: touch $_state/msg-approved"
    fi
    rm -f "$_state/msg-approved"
  fi
}
