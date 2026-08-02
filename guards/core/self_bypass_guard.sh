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

  # Build pattern from prefix and explicit gate files
  local gate_pattern="$GUARDRAIL_GATE_PREFIX"
  if [ -n "$GUARDRAIL_GATE_FILES" ]; then
    local escaped_files
    escaped_files=$(printf '%s' "$GUARDRAIL_GATE_FILES" | tr ' ' '|')
    gate_pattern="($gate_pattern|$escaped_files)"
  fi

  # Check for file creation commands targeting gate paths
  # touch
  if echo "$cmd" | grep -qE "(^|[;&|]\s*)(touch|touch\s+--)\s" && echo "$cmd" | grep -qF "$GUARDRAIL_GATE_PREFIX"; then
    deny "Self-bypass blocked: AI agents must not create gate files. Only human operators can approve gates."
    guardrail_audit "self_bypass_guard" "touch on gate file" "$cmd" "blocked"
    return 0
  fi

  # echo/printf redirect
  if echo "$cmd" | grep -qE "(echo|printf)\s" && echo "$cmd" | grep -qE ">\s*$GUARDRAIL_GATE_PREFIX"; then
    deny "Self-bypass blocked: AI agents must not write to gate files."
    guardrail_audit "self_bypass_guard" "redirect to gate file" "$cmd" "blocked"
    return 0
  fi

  # tee/cp/ln
  if echo "$cmd" | grep -qE "(tee|cp|ln)\s" && echo "$cmd" | grep -qF "$GUARDRAIL_GATE_PREFIX"; then
    deny "Self-bypass blocked: AI agents must not create gate files via tee/cp/ln."
    guardrail_audit "self_bypass_guard" "tee/cp/ln on gate file" "$cmd" "blocked"
    return 0
  fi
}
