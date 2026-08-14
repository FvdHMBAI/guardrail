#!/bin/bash
# Guard: deploy_branch_guard
# Ensures deployments only happen from approved branches.
# Prevents deploying from feature branches, stale branches,
# or branches that haven't been merged through the proper flow.
#
# Configurable via GUARDRAIL_DEPLOY_BRANCHES (default: "main master production").
# License: MIT

GUARDRAIL_DEPLOY_BRANCHES="${GUARDRAIL_DEPLOY_BRANCHES:-main master production}"

hook_deploy_branch_guard() {
  # Trigger on deploy-like commands
  echo "$CMD" | grep -qiE '(deploy|coolify.*deploy|redeploy|scp\s|rsync\s.*--delete)' || return 0

  # Skip read-only commands
  echo "$CMD" | grep -qE '(^|\s)(grep|cat|less|head|tail|ls|stat)\s' && return 0

  # Detect current branch
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -z "$current_branch" ] && return 0

  # Check if current branch is in allowed deploy branches
  local allowed=false
  for branch in $GUARDRAIL_DEPLOY_BRANCHES; do
    [ "$current_branch" = "$branch" ] && allowed=true
  done

  if [ "$allowed" = false ]; then
    deny "Deploy from branch '$current_branch' blocked. Only these branches may deploy: $GUARDRAIL_DEPLOY_BRANCHES. Merge your changes first."
    guardrail_audit "deploy_branch_guard" "deploy from $current_branch" "$CMD" "blocked"
  fi
}
