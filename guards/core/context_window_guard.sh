#!/bin/bash
# Guard: context_window_guard
# Detects commands that produce excessive output, which wastes context
# window space and API tokens. Suggests piping through head/tail/grep.
#
# Catches: cat on large files, find without limits, docker logs without
# --tail, unbounded grep, etc.
# License: MIT

GUARDRAIL_MAX_OUTPUT_LINES="${GUARDRAIL_MAX_OUTPUT_LINES:-200}"

hook_context_window_guard() {
  local cmd="$CMD"

  # cat without head/tail on potentially large files
  if echo "$cmd" | grep -qE '^\s*cat\s+' && ! echo "$cmd" | grep -qE '\|\s*(head|tail|grep|wc|less|more)'; then
    local target
    target=$(echo "$cmd" | grep -oP 'cat\s+\K\S+' | head -1)
    if [ -f "$target" ]; then
      local lines
      lines=$(wc -l < "$target" 2>/dev/null)
      if [ "${lines:-0}" -gt "$GUARDRAIL_MAX_OUTPUT_LINES" ]; then
        allow_with_msg "Large file: $target has ${lines} lines. Consider: cat $target | head -${GUARDRAIL_MAX_OUTPUT_LINES}"
      fi
    fi
  fi

  # find without -maxdepth or | head
  if echo "$cmd" | grep -qE '^\s*find\s+/' && ! echo "$cmd" | grep -qE '(-maxdepth|\|\s*head)'; then
    allow_with_msg "Unbounded find on root path. Consider adding -maxdepth or piping through head."
  fi

  # docker logs without --tail
  if echo "$cmd" | grep -qE 'docker\s+(logs|compose\s+logs)' && ! echo "$cmd" | grep -qE '(--tail|--since|\|\s*tail)'; then
    allow_with_msg "Docker logs without --tail may flood the context. Consider: docker logs --tail 50"
  fi

  # git log without limit
  if echo "$cmd" | grep -qE '^\s*git\s+log\b' && ! echo "$cmd" | grep -qE '(-n\s*\d+|--oneline.*head|\|\s*head|-\d+)'; then
    allow_with_msg "Unbounded git log. Consider: git log -20 --oneline"
  fi
}
