#!/bin/bash
# GuardRail Core Guard: anti_self_bypass_guard
# Prevents the agent from granting itself the approval tokens that other
# guards check. Approval tokens exist so a human can unblock a single
# operation; an agent able to create them can disable its own guardrails.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()
# Config: GUARDRAIL_STATE_DIR, GUARDRAIL_APPROVAL_TOKENS
#
# Counterpart: gate_file_guard.sh protects the same tokens from deletion.
# Both token lists must stay consistent.

hook_anti_self_bypass_guard() {
  local state_dir="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
  local tokens="${GUARDRAIL_APPROVAL_TOKENS:-human-approved backup-confirmed infra-approved service-approved rm-approved msg-approved delete-approved push-approved deployment-bypass verify-skip session-skip stop-override uncommitted-ok}"

  # Cheap pre-filter: only commands that could create a file are relevant
  echo "$CMD" | grep -qE '(touch|tee|cp|ln|echo|printf|install|dd|>)' || return 0

  local token
  for token in $tokens; do
    case "$CMD" in
      *"$state_dir/$token"*) ;;
      *) continue ;;
    esac

    # Creating verbs anywhere in the command chain
    if echo "$CMD" | grep -qE '(^|[;&|]|[[:space:]])(sudo[[:space:]]+)?(touch|tee|install|ln|cp|dd)([[:space:]]|--[[:space:]])'; then
      guardrail_audit "anti_self_bypass_guard" "$CMD" "self-granted approval token: $token" "blocked"
      guardrail_log "anti_self_bypass_guard" "DENY token=$token session=${SESSION_ID:-unknown}"
      deny "SELF-BYPASS BLOCKED: Approval token '$token' may only be created by a human operator, not by the agent. Fix the underlying problem instead of bypassing the gate."
    fi

    # Output redirection onto the token file
    if echo "$CMD" | grep -qE ">[[:space:]]*[^[:space:];&|]*${token}"; then
      guardrail_audit "anti_self_bypass_guard" "$CMD" "redirect onto approval token: $token" "blocked"
      guardrail_log "anti_self_bypass_guard" "DENY redirect token=$token session=${SESSION_ID:-unknown}"
      deny "SELF-BYPASS BLOCKED: Approval token '$token' may not be written via output redirection. Only a human operator may grant it."
    fi
  done

  # Variable expansion pointing at the state directory,
  # e.g. touch "$GUARDRAIL_STATE_DIR/backup-confirmed"
  if echo "$CMD" | grep -qE '(touch|tee|cp|ln|install|echo|printf)[[:space:]]' \
     && echo "$CMD" | grep -qE '\$\{?[A-Za-z_][A-Za-z0-9_]*'; then
    case "$CMD" in
      *"$state_dir"*|*GUARDRAIL_STATE_DIR*)
        guardrail_audit "anti_self_bypass_guard" "$CMD" "variable expansion onto state dir" "blocked"
        deny "SELF-BYPASS BLOCKED: Building a gate file path through variable expansion is not allowed. Fix the underlying problem instead of bypassing the gate."
        ;;
    esac
  fi
}
