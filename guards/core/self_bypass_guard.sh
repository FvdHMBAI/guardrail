#!/bin/bash
# Guard: self_bypass_guard
# Prevents AI agents from creating their own approval/gate files.
# Gate files should only be created by human operators.
#
# Catches: touch, echo/redirect, tee, cp, ln on gate file paths.
# Configurable via GUARDRAIL_GATE_FILES and GUARDRAIL_GATE_PREFIX.
# License: MIT

GUARDRAIL_GATE_PREFIX="${GUARDRAIL_GATE_PREFIX:-/tmp/guardrail-gate-}"
GUARDRAIL_GATE_FILES="${GUARDRAIL_GATE_FILES:-}"

hook_self_bypass_guard() {
  local cmd="$CMD"

  # Block agent from running guardrail disable/uninstall directly
  if echo "$cmd" | grep -qE '(^|[;&|]\s*)guardrail\s+(disable|uninstall)'; then
    guardrail_audit "self_bypass_guard" "agent tried to run guardrail disable/uninstall" "$cmd" "blocked"
    deny "Self-bypass blocked: AI agents must not disable or uninstall GuardRail. Only human operators can do this from an interactive terminal."
    return 0
  fi

  # Protect guardrail's .disabled file and disable.key from manipulation
  if echo "$cmd" | grep -qE 'guardrail/\.disabled|guardrail.*\.disabled|/\.guardrail/disable\.key'; then
    if echo "$cmd" | grep -qE '(^|[;&|]\s*)(touch|tee|cp|ln|mv|echo|printf|cat\s*>|dd|sed|perl|python|python3|ruby|node|rsync|install)\s'; then
      guardrail_audit "self_bypass_guard" "agent tried to manipulate disable mechanism" "$cmd" "blocked"
      deny "Self-bypass blocked: AI agents must not manipulate the disable mechanism. Use 'guardrail disable' from an interactive terminal."
      return 0
    fi
    if echo "$cmd" | grep -qE '>\s*.*(guardrail/\.disabled|\.guardrail/disable\.key)'; then
      guardrail_audit "self_bypass_guard" "redirect to disable file" "$cmd" "blocked"
      deny "Self-bypass blocked: AI agents must not write to disable files."
      return 0
    fi
  fi

  # Block reading disable.key (agent has no legitimate need)
  if echo "$cmd" | grep -qE '(cat|less|more|head|tail|xxd|od|base64|openssl|awk|grep|read)\s.*\.guardrail/disable\.key'; then
    guardrail_audit "self_bypass_guard" "agent tried to read disable secret" "$cmd" "blocked"
    deny "Self-bypass blocked: AI agents must not read the disable secret."
    return 0
  fi

  # Check for file creation commands targeting gate paths
  if echo "$cmd" | grep -qE "(^|[;&|]\s*)(touch|tee|cp|ln|mv|echo|printf|cat\s*>|dd|sed|perl|python|python3|ruby|node|rsync|install)\s" && echo "$cmd" | grep -qF "$GUARDRAIL_GATE_PREFIX"; then
    guardrail_audit "self_bypass_guard" "write to gate file" "$cmd" "blocked"
    deny "Self-bypass blocked: AI agents must not create gate files. Only human operators can approve gates."
    return 0
  fi

  if echo "$cmd" | grep -qE '>\s*'"$GUARDRAIL_GATE_PREFIX"; then
    guardrail_audit "self_bypass_guard" "redirect to gate file" "$cmd" "blocked"
    deny "Self-bypass blocked: AI agents must not write to gate files."
    return 0
  fi
}
