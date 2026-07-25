#!/bin/bash
# GuardRail Core Guard: gate_file_guard
# Protects gate and flag files. Guards use them to record that a check passed
# or that a human granted an approval, so removing one silently resets the
# safety state without leaving an error behind.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()
# Config: GUARDRAIL_STATE_DIR, GUARDRAIL_SELF_SERVICE_TOKENS
#
# Counterpart: anti_self_bypass_guard.sh blocks creation of approval tokens.
# Both token lists must stay consistent.

hook_gate_file_guard() {
  # Files used to trigger a gate from outside may not be forged
  if echo "$CMD" | grep -qE '\.gate-trigger'; then
    if echo "$CMD" | grep -qE '(touch|echo|cat|tee|cp|mv|>).*\.gate-trigger'; then
      guardrail_audit "gate_file_guard" "$CMD" "gate trigger creation" "blocked"
      deny "GATE-FILE-GUARD: Creating .gate-trigger files is blocked. They bypass safety gates and may only be created by authorized processes."
    fi
  fi

  local state_dir="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"

  # Tokens the agent may create itself, after actually doing the work
  local self_service="${GUARDRAIL_SELF_SERVICE_TOKENS:-quality-gate-passed verify-work-passed pre-mortem-passed verify-ui-gate review-passed test-passed}"
  local token
  for token in $self_service; do
    if echo "$CMD" | grep -qE "^[[:space:]]*(touch|echo|printf|mkdir)[[:space:]][^;&|]*${token}"; then
      return 0
    fi
    if echo "$CMD" | grep -qE ">[[:space:]]*[^[:space:];&|]*${token}[[:space:]]*\$"; then
      return 0
    fi
  done

  # Only commands touching the state directory are relevant below
  case "$CMD" in
    *"$state_dir"*) ;;
    *) return 0 ;;
  esac

  # find -delete / find -exec rm clears every flag in one go
  if echo "$CMD" | grep -qiE '\bfind\b[^;&|]*(-delete|-exec[[:space:]]+(rm|unlink|shred)\b)'; then
    guardrail_log "gate_file_guard" "DENY find-delete session=${SESSION_ID:-unknown}"
    guardrail_audit "gate_file_guard" "$CMD" "find-delete on gate files" "blocked"
    deny "GATE-FILE-GUARD: Gate files may not be removed with find. Resolve the blocked condition instead of clearing the flags."
  fi

  if echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)(sudo[[:space:]]+)?(rm|unlink|shred)([[:space:]]|$)'; then
    guardrail_log "gate_file_guard" "DENY delete session=${SESSION_ID:-unknown}"
    guardrail_audit "gate_file_guard" "$CMD" "deletion of gate file" "blocked"
    deny "GATE-FILE-GUARD: Gate files may not be deleted. They record that a check passed or that a human granted an approval."
  fi

  if echo "$CMD" | grep -qE '(^|[;&|][[:space:]]*)(sudo[[:space:]]+)?(mv|cp|truncate)([[:space:]]|$)'; then
    guardrail_log "gate_file_guard" "DENY move session=${SESSION_ID:-unknown}"
    guardrail_audit "gate_file_guard" "$CMD" "move or overwrite of gate file" "blocked"
    deny "GATE-FILE-GUARD: Gate files may not be moved or overwritten."
  fi

  if echo "$CMD" | grep -qE '>[[:space:]]*[^[:space:];&|]*'"$(printf '%s' "$state_dir" | sed 's/[][\.*^$\/]/\\&/g')"; then
    guardrail_log "gate_file_guard" "DENY redirect session=${SESSION_ID:-unknown}"
    guardrail_audit "gate_file_guard" "$CMD" "redirect onto gate file" "blocked"
    deny "GATE-FILE-GUARD: Gate files may not be overwritten via output redirection."
  fi
}
