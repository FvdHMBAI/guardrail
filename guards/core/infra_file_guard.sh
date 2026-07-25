#!/bin/bash
# GuardRail Core Guard: infra_file_guard
# Protects critical infrastructure files from unintended modification.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny(), warn()

hook_infra_file_guard() {
  local INFRA_PATTERNS='authorized_keys|sshd_config|/etc/ssh/|/etc/shadow|/etc/passwd|/etc/sudoers|/etc/pam\.d/'
  local WRITE_OPS='(sed|awk|echo[[:space:]]*>|tee|cp|mv|rm|chmod|chown|truncate|dd|install|>|>>)[[:space:]]'
  if echo "$CMD" | grep -qE "$WRITE_OPS" && echo "$CMD" | grep -qE "$INFRA_PATTERNS"; then
    if [[ "$CMD" =~ ^[[:space:]]*cp[[:space:]] ]] && echo "$CMD" | grep -qE '\.(bak|backup|orig)' && ! echo "$CMD" | grep -qE '[;&|`]|\$\('; then
      return 0
    fi
    local _state="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
    if [ -f "$_state/infra-approved" ]; then
      rm -f "$_state/infra-approved" 2>/dev/null
      guardrail_audit "Infra-Guard" "Change with admin approval" "$(echo "$CMD" | head -c 60)" "approved"
      return 0
    fi
    guardrail_audit "Infra-Guard" "Infra change blocked" "$(echo "$CMD" | head -c 60)"
    deny "INFRA-GUARD: Write to protected infrastructure file detected. Blocked without admin approval. Admin approval: ! touch $_state/infra-approved (single use)."
  fi
  if echo "$CMD" | grep -qE 'systemctl[[:space:]]+(restart|reload)[[:space:]]+ssh'; then
    echo "$CMD" | grep -qE 'sshd[[:space:]]+-t' || warn "INFRA-GUARD: sshd restart/reload without prior 'sshd -t' config test."
  fi
}
