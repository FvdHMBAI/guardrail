#!/bin/bash
# Guard: large_diff_guard
# Warns when a git commit contains an unusually large diff.
# Large commits often indicate accidental inclusion of generated files,
# node_modules, or unreviewed bulk changes.
#
# Configurable via GUARDRAIL_MAX_DIFF_LINES (default: 500).
# License: MIT

GUARDRAIL_MAX_DIFF_LINES="${GUARDRAIL_MAX_DIFF_LINES:-500}"

hook_large_diff_guard() {
  echo "$CMD" | grep -qE '\bgit\s+commit\b' || return 0

  local diff_lines
  diff_lines=$(git diff --cached --stat 2>/dev/null | tail -1 | grep -oP '\d+ insertion' | grep -oP '^\d+')
  diff_lines=${diff_lines:-0}

  local del_lines
  del_lines=$(git diff --cached --stat 2>/dev/null | tail -1 | grep -oP '\d+ deletion' | grep -oP '^\d+')
  del_lines=${del_lines:-0}

  local total=$((diff_lines + del_lines))

  if [ "$total" -gt "$GUARDRAIL_MAX_DIFF_LINES" ]; then
    local file_count
    file_count=$(git diff --cached --name-only 2>/dev/null | wc -l)

    # Check for common mistakes
    local suspect_files
    suspect_files=$(git diff --cached --name-only 2>/dev/null | grep -E '(node_modules|dist/|build/|\.min\.|package-lock\.json|yarn\.lock)' | head -5)

    local msg="Large commit: ${total} lines changed across ${file_count} files (threshold: ${GUARDRAIL_MAX_DIFF_LINES})."
    [ -n "$suspect_files" ] && msg="$msg Suspect files: $(echo "$suspect_files" | tr '\n' ', ')"

    if [ "$GUARDRAIL_STRICT_MODE" = "true" ]; then
      deny "$msg Review the diff before committing. Raise GUARDRAIL_MAX_DIFF_LINES if intentional."
    else
      allow_with_msg "$msg"
    fi
    guardrail_audit "large_diff_guard" "large commit ($total lines)" "$CMD" "warned"
  fi
}
