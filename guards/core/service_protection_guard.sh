#!/bin/bash
# GuardRail Core Guard: service_protection_guard
# Blocks stop/disable/kill on critical system services.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_service_protection_guard() {
  local _services_re
  _services_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_CRITICAL_SERVICES")
  local _state="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"

  if echo "$CMD_SHELL" | grep -qE 'systemctl[[:space:]]+(stop|disable|mask)[[:space:]]'; then
    if echo "$CMD_SHELL" | grep -qE "systemctl[[:space:]]+(stop|disable|mask)[[:space:]]+${_services_re}"; then
      if [ -f "$_state/service-approved" ]; then
        rm -f "$_state/service-approved" 2>/dev/null
        guardrail_audit "Service-Guard" "Service stop with approval" "$(echo "$CMD_SHELL" | head -c 60)" "approved"
        return 0
      fi
      guardrail_audit "Service-Guard" "Critical service stop blocked" "$(echo "$CMD_SHELL" | head -c 60)"
      deny "SERVICE-GUARD: Stopping/disabling critical services is blocked. Admin approval: touch $_state/service-approved"
    fi
  fi

  if echo "$CMD_SHELL" | grep -qE "killall[[:space:]]+${_services_re}"; then
    deny "SERVICE-GUARD: killall on critical process is blocked."
  fi

  if echo "$CMD_SHELL" | grep -qE "pkill[[:space:]]+${_services_re}"; then
    deny "SERVICE-GUARD: pkill on critical process is blocked."
  fi
  if echo "$CMD_SHELL" | grep -qE "kill[[:space:]].*pgrep[[:space:]]+${_services_re}"; then
    deny "SERVICE-GUARD: kill \$(pgrep ...) on critical process is blocked."
  fi
}
