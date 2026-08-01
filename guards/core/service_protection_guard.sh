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

  if echo "$CMD_SHELL" | grep -qE 'systemctl[[:space:]]+(stop|disable|mask)[[:space:]]'; then
    if echo "$CMD_SHELL" | grep -qE "systemctl[[:space:]]+(stop|disable|mask)[[:space:]]+${_services_re}"; then
      guardrail_audit "Service-Guard" "Critical service stop blocked" "$(echo "$CMD_SHELL" | head -c 60)"
      deny "SERVICE-GUARD: Stopping or disabling critical services is blocked. Run exceptional maintenance outside the controlled agent session."
    fi
  fi
  if echo "$CMD_SHELL" | grep -qE "service[[:space:]]+${_services_re}[[:space:]]+(stop|disable|kill)"; then
    deny "SERVICE-GUARD: Stopping a critical service through the service command is blocked."
  fi
  if echo "$CMD_SHELL" | grep -qE "docker[[:space:]]+(stop|kill|rm)[[:space:]]+([^;&|]*[[:space:]])?${_services_re}([[:space:];&|]|$)"; then
    deny "SERVICE-GUARD: Stopping or removing a critical service container is blocked."
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
