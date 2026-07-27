#!/bin/bash
# GuardRail Core Guard: destructive_path_guard
# Blocks rm -rf on critical paths and root-level deletions.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_destructive_path_guard() {
  local _paths_re
  _paths_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PROTECTED_PATHS")

  local IS_RM_RECURSIVE=false
  echo "$CMD_SHELL" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*r' && IS_RM_RECURSIVE=true
  echo "$CMD_SHELL" | grep -qE 'rm[[:space:]]+--recursive' && IS_RM_RECURSIVE=true

  # find -delete on protected paths
  if echo "$CMD_SHELL" | grep -qE "find[[:space:]]+(${_paths_re})[^|;]*-delete"; then
    guardrail_audit "Path-Guard" "find -delete on protected path blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "PATH-GUARD: find -delete on protected paths is blocked. Run exceptional maintenance outside the controlled agent session."
  fi

  if [ "$IS_RM_RECURSIVE" != "true" ]; then
    return 0
  fi

  if echo "$CMD_SHELL" | grep -qE "(rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*|rm[[:space:]]+--recursive)[[:space:]]+.*(${_paths_re})"; then
    guardrail_audit "Path-Guard" "rm -r on protected path blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "PATH-GUARD: rm -r/--recursive on protected paths is blocked. Run exceptional maintenance outside the controlled agent session."
  fi

  if echo "$CMD_SHELL" | grep -qE '(rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*|rm[[:space:]]+--recursive)[[:space:]]+(/[[:space:]]|/$|/\*|/\.)'; then
    deny "PATH-GUARD: rm -r at root level (/, /*, /.) is always blocked."
  fi
}
