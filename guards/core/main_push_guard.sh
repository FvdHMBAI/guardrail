#!/bin/bash
# GuardRail Core Guard: main_push_guard
# Blocks direct pushes to protected branches and destructive git operations.
# License: MIT
#
# Shared vars: $CMD, $CMD_SHELL, $SESSION_ID
# Shared fns: deny()

hook_main_push_guard() {
  local _state="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
  local _branches_re
  _branches_re=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PROTECTED_BRANCHES")

  # FORCE-PUSH BLOCK
  if echo "$CMD_SHELL" | grep -qE 'git[[:space:]]+push[[:space:]].*(\-\-force|\-f($|[[:space:]]))'; then
    guardrail_audit "Force-Push-Guard" "Force push blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "FORCE-PUSH BLOCKED: git push --force risks data loss. Use --force-with-lease on feature branches or a normal push."
  fi

  # --force-with-lease only blocked on protected branches (OK on feature branches after rebase)
  if echo "$CMD_SHELL" | grep -qE 'git[[:space:]]+push[[:space:]].*--force-with-lease' \
     && echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:space:]](origin|upstream)[[:space:]]+${_branches_re}([^[:alnum:]_-]|\$)"; then
    guardrail_audit "Force-Push-Guard" "Force-with-lease on protected branch blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "FORCE-WITH-LEASE on protected branch BLOCKED: Protected branches cannot be force-pushed. Use a normal push or create a new branch."
  fi

  # DESTRUCTIVE GIT COMMANDS
  if echo "$CMD_SHELL" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard'; then
    guardrail_audit "Git-Safety-Guard" "reset --hard blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "GIT RESET --HARD BLOCKED: Can irreversibly delete uncommitted code. Use 'git stash' or 'git checkout <file>' for individual files."
  fi
  if echo "$CMD_SHELL" | grep -qE 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
    guardrail_audit "Git-Safety-Guard" "clean -f blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "GIT CLEAN -F BLOCKED: Irreversibly deletes untracked files. Check and remove files individually."
  fi

  # Only consider push commands (covers bash -c, sh -c, eval wrappers)
  echo "$CMD_SHELL" | grep -qE '(^|[;&|][[:space:]]*|ssh[^;&|]*|(bash|sh)[[:space:]]+-c[[:space:]]*['"'"'"]?|eval[[:space:]]+['"'"'"]?)git[^;&|]*[[:space:]]push([[:space:]]|$)' || return 0

  # Direct push to protected branches?
  if echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:space:]](origin|upstream)[[:space:]]+${_branches_re}([^[:alnum:]_-]|\$)" \
     || echo "$CMD_SHELL" | grep -qE "push[^;&|]*[[:alnum:]/_.-]+:(refs/heads/)?${_branches_re}([^[:alnum:]_-]|\$)"; then

    # Exception 1: Explicit admin approval (one-time)
    if [ -f "$_state/main-push-approved" ]; then
      rm -f "$_state/main-push-approved" 2>/dev/null
      guardrail_audit "Main-Push-Guard" "Push with admin approval" "$(echo "$CMD_SHELL" | head -c 60)" "approved"
      return 0
    fi

    # Exception 2: Clean workflow — main only contains commits that are also on develop
    local GIT_DIR=""
    GIT_DIR=$(echo "$CMD_SHELL" | grep -oP 'cd\s+\K/[^\s;&]+' | head -1)
    [ -z "$GIT_DIR" ] && GIT_DIR=$(echo "$CMD_SHELL" | grep -oP 'git\s+-C\s+\K/[^\s]+' | head -1)
    local GIT_CMD="git"
    [ -n "$GIT_DIR" ] && [ -d "$GIT_DIR/.git" ] && GIT_CMD="git -C $GIT_DIR"
    $GIT_CMD fetch --quiet origin main develop 2>/dev/null || true
    if [ -n "$($GIT_CMD log --oneline origin/main..main 2>/dev/null)" ] \
       && $GIT_CMD merge-base --is-ancestor origin/develop main 2>/dev/null; then
      guardrail_audit "Main-Push-Guard" "Push after PR merge (clean workflow)" "$(echo "$CMD_SHELL" | head -c 60)" "approved"
      return 0
    fi

    guardrail_audit "Main-Push-Guard" "Direct push to protected branch blocked" "$(echo "$CMD_SHELL" | head -c 60)"
    deny "MAIN-PUSH-GUARD: Direct pushes to protected branches are BLOCKED. Use 'gh pr create' to create a pull request. Admin exception: touch $_state/main-push-approved (valid for one push)."
  fi
  return 0
}
