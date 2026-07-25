#!/bin/bash
# GuardRail Core Guard: destructive_path_guard
# Blocks rm -rf on critical paths and root-level deletions.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_destructive_path_guard() {
  local PROTECTED_PATHS='/opt\b|/home/developer\b|/etc\b|/var/lib/docker\b|/var/lib/postgresql\b|/mnt\b|/root/\.claude|/root/\.ssh'

  local IS_RM_RECURSIVE=false
  echo "$CMD_SHELL" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*r' && IS_RM_RECURSIVE=true
  echo "$CMD_SHELL" | grep -qE 'rm[[:space:]]+--recursive' && IS_RM_RECURSIVE=true

  # find -delete on protected paths
  if echo "$CMD_SHELL" | grep -qE "find[[:space:]]+(${PROTECTED_PATHS})[^|;]*-delete"; then
    deny "PATH-GUARD: find -delete on protected path is blocked. Admin approval: ! touch ${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/rm-approved"
  fi

  if [ "$IS_RM_RECURSIVE" != "true" ]; then
    return 0
  fi

  if echo "$CMD_SHELL" | grep -qE "(rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*|rm[[:space:]]+--recursive)[[:space:]]+.*(${PROTECTED_PATHS})"; then
    if [ -f ${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/rm-approved ]; then
      rm -f ${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/rm-approved 2>/dev/null
      echo "| $(date +%Y-%m-%d\ %H:%M) | Path-Guard | rm -r with approval | $SESSION_ID | $(echo "$CMD_SHELL" | head -c 80 | tr '|' '/') | approved |" >> ${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log} 2>/dev/null
      return 0
    fi
    echo "| $(date +%Y-%m-%d\ %H:%M) | Path-Guard | rm -r on protected path blocked | $SESSION_ID | $(echo "$CMD_SHELL" | head -c 80 | tr '|' '/') | blocked |" >> ${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log} 2>/dev/null
    deny "PATH-GUARD: rm -r/--recursive on protected path blocked (/opt, /home/developer, /etc, /var/lib/docker, /mnt, .claude, .ssh). Admin approval: ! touch ${GUARDRAIL_STATE_DIR:-/tmp/guardrail}/rm-approved"
  fi

  if echo "$CMD_SHELL" | grep -qE '(rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*|rm[[:space:]]+--recursive)[[:space:]]+(/[[:space:]]|/$|/\*|/\.)'; then
    deny "PATH-GUARD: rm -r at root level (/, /*, /.) is always blocked."
  fi
}
