#!/bin/bash
# GuardRail Pro: Audit Trail Guard
# Logs every guard decision to structured JSONL for compliance reporting.
# License: Proprietary (GuardRail Pro)
#
# Hook type: post-bash (also sourced by pre-bash and post-edit dispatchers)
# Shared vars: $CMD, $OUTPUT, $SESSION_ID
# Shared fns: add_context(), guardrail_audit()

hook_post_audit_trail_guard() {
  local audit_dir="${GUARDRAIL_AUDIT_DIR:-$HOME/.guardrail/audit}"
  local today
  today=$(date +%Y-%m-%d)
  local audit_file="$audit_dir/audit-${today}.jsonl"

  mkdir -p "$audit_dir" 2>/dev/null

  local cmd_truncated
  cmd_truncated=$(echo "$CMD" | head -c 200 | tr '\n' ' ')
  local output_len=${#OUTPUT}
  local cwd_val
  cwd_val=$(pwd 2>/dev/null || echo "unknown")

  local json_line
  json_line=$(jq -n -c \
    --arg ts "$(date -Iseconds)" \
    --arg sid "${SESSION_ID:-unknown}" \
    --arg cmd "$cmd_truncated" \
    --arg cwd "$cwd_val" \
    --argjson output_len "$output_len" \
    --arg hook "post-bash" \
    --arg user "${USER:-unknown}" \
    '{timestamp: $ts, session_id: $sid, hook: $hook, command: $cmd, cwd: $cwd, output_length: $output_len, user: $user}')

  echo "$json_line" >> "$audit_file" 2>/dev/null

  local retention_days="${GUARDRAIL_AUDIT_RETENTION_DAYS:-90}"
  if [ "$((RANDOM % 100))" -eq 0 ]; then
    find "$audit_dir" -name "audit-*.jsonl" -mtime +"$retention_days" -delete 2>/dev/null
  fi
}
