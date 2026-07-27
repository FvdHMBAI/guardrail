#!/bin/bash
# GuardRail Core Guard: main_push_guard
# Blocks direct pushes to protected branches and destructive git operations.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_main_push_guard() {
  local _branches_re
  _branches_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PROTECTED_BRANCHES")

  # FORCE-PUSH BLOCK
  if echo "$CMD_SHELL" | grep -qE '([^;&|[:space:]]*/)?git[[:space:]]+push[[:space:]].*(\-\-force|\-f($|[[:space:]]))'; then
    guardrail_audit "Force-Push-Guard" "Force push blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "FORCE-PUSH BLOCKED: git push --force risks data loss. Use --force-with-lease on feature branches or a normal push."
  fi

  # --force-with-lease only blocked on protected branches (OK on feature branches after rebase)
  if echo "$CMD_SHELL" | grep -qE '([^;&|[:space:]]*/)?git[[:space:]]+push[[:space:]].*--force-with-lease' \
     && echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:space:]](origin|upstream)[[:space:]]+${_branches_re}([^[:alnum:]_-]|\$)"; then
    guardrail_audit "Force-Push-Guard" "Force-with-lease on protected branch blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "FORCE-WITH-LEASE on protected branch BLOCKED: Protected branches cannot be force-pushed. Use a normal push or create a new branch."
  fi

  # DESTRUCTIVE GIT COMMANDS
  if echo "$CMD_SHELL" | grep -qE '([^;&|[:space:]]*/)?git[[:space:]]+reset[[:space:]]+--hard'; then
    guardrail_audit "Git-Safety-Guard" "reset --hard blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "GIT RESET --HARD BLOCKED: Can irreversibly delete uncommitted code. Use 'git stash' or 'git checkout <file>' for individual files."
  fi
  if echo "$CMD_SHELL" | grep -qE '([^;&|[:space:]]*/)?git[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*f|--force)'; then
    guardrail_audit "Git-Safety-Guard" "clean -f blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "GIT CLEAN -F BLOCKED: Irreversibly deletes untracked files. Check and remove files individually."
  fi

  # Only consider push commands (covers bash -c, sh -c, eval wrappers)
  echo "$CMD_SHELL" | grep -qE '(^|[;&|][[:space:]]*|ssh[^;&|]*|(bash|sh)[[:space:]]+-c[[:space:]]*['"'"'"]?|eval[[:space:]]+['"'"'"]?)([^;&|[:space:]]*/)?git[^;&|]*[[:space:]]push([[:space:]]|$)' || return 0

  # Direct push to protected branches?
  if echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:space:]](origin|upstream)[[:space:]]+${_branches_re}([^[:alnum:]_-]|\$)" \
     || echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:alnum:]/_.-]+:(refs/heads/)?${_branches_re}([^[:alnum:]_-]|\$)"; then

    guardrail_audit "Main-Push-Guard" "Direct push to protected branch blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "MAIN-PUSH-GUARD: Direct pushes to protected branches are BLOCKED. Use a pull request. Administrative bypasses are intentionally unavailable to the controlled agent."
  fi
  return 0
}
