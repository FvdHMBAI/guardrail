#!/bin/bash
# Guard: force_push_guard
# Blocks force-push to any branch (not just protected ones).
# Unlike main_push_guard which protects specific branches,
# this catches --force and --force-with-lease everywhere.
# License: MIT

hook_force_push_guard() {
  # Only trigger on git push
  echo "$CMD" | grep -qE '\bgit\s+push\b' || return 0

  # Allow regular push
  echo "$CMD" | grep -qE '\s--(force|force-with-lease)\b|\s-f\b' || return 0

  # Extract target branch
  local target_branch=""
  target_branch=$(echo "$CMD" | grep -oP 'push\s+\S+\s+\K\S+' | head -1)
  [ -z "$target_branch" ] && target_branch="(current branch)"

  # Protected branches are always blocked
  local protected
  protected=$(_guardrail_list_to_regex_raw "$GUARDRAIL_PROTECTED_BRANCHES")
  if echo "$target_branch" | grep -qE "^${protected}$"; then
    deny "Force push to protected branch '$target_branch' is blocked. Use a regular push or create a PR."
    guardrail_audit "force_push_guard" "force-push to $target_branch" "$CMD" "blocked"
    return 0
  fi

  # Non-protected branches: warn but allow
  if [ "$GUARDRAIL_STRICT_MODE" = "true" ]; then
    deny "Force push to '$target_branch' blocked (strict mode). Disable GUARDRAIL_STRICT_MODE or push normally."
  else
    allow_with_msg "Force push to '$target_branch'. This rewrites history and can cause data loss for collaborators."
  fi
  guardrail_audit "force_push_guard" "force-push to $target_branch" "$CMD" "warned"
}
