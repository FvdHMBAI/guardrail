#!/bin/bash
# Guard: uncommitted_code_guard
# Prevents session end with uncommitted work in the repository.
# An AI agent should never silently abandon changes.
#
# Works as a post-execution guard: checks for dirty working tree
# after commands that suggest task completion (git log, echo "done").
# License: MIT

hook_uncommitted_code_guard() {
  # Only trigger on completion signals
  echo "$CMD" | grep -qiE '(^echo.*(done|finished|complete|fertig)|session.*end|task.*complete)' || return 0

  # Check for uncommitted changes (excluding common noise)
  local dirty
  dirty=$(git status --porcelain 2>/dev/null | grep -vE '(node_modules/|\.cache/|dist/|build/|\.next/)' | head -5)

  if [ -n "$dirty" ]; then
    local file_count
    file_count=$(echo "$dirty" | wc -l)

    add_context "UNCOMMITTED CODE: ${file_count} file(s) with uncommitted changes detected. Commit or document what is open before declaring the task complete. Files: $(echo "$dirty" | awk '{print $2}' | tr '\n' ', ')"
    guardrail_audit "uncommitted_code_guard" "uncommitted changes ($file_count files)" "$CMD" "warned"
  fi
}
