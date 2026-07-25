#!/bin/bash
# GuardRail Core Guard: agent_control_policy_guard
# Classifies each command into an operation, category and risk level, then
# hands it to an external policy engine for an allow/warn/deny decision.
# Inactive unless GUARDRAIL_POLICY_CHECK_CMD points to an executable.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny(), warn()
# Config: GUARDRAIL_POLICY_CHECK_CMD
#
# The policy command is invoked as: <cmd> <event-json-file>
# and is expected to print JSON on stdout:
#   {"decision":"allow|warn|deny","reasons":[...],"required_actions":[...]}

hook_agent_control_policy_guard() {
  local policy_check="${GUARDRAIL_POLICY_CHECK_CMD:-}"
  [ -n "$policy_check" ] || return 0
  [ -x "$policy_check" ] || return 0

  command -v jq >/dev/null 2>&1 || return 0

  local event_file policy_file decision reasons actions project_dir operation risk category

  project_dir=$(echo "${INPUT:-}" | jq -r '.cwd // .workspace.current_dir // ""' 2>/dev/null)
  [ -z "$project_dir" ] && project_dir="$PWD"

  operation="terminal-command"
  risk="low"
  category="ops"

  case "$CMD" in
    *"SERVICE_ROLE"*|*"api-token"*|*"secret"*|*"password"*|*"credential"*)
      operation="secret-access"
      risk="high"
      category="security"
      ;;
    *"psql"*|*"ALTER TABLE"*|*"DROP TABLE"*|*"DELETE FROM"*|*"TRUNCATE"*|*"CREATE TABLE"*|*"UPDATE "*)
      operation="db-change"
      risk="high"
      category="db"
      ;;
    *"deploy"*|*"webhook"*|*"docker push"*|*"docker restart"*|*"docker stop"*|*"docker rm"*|*"systemctl "*)
      operation="deploy"
      risk="high"
      category="infra"
      ;;
    *"git push"*|*"git merge"*|*"gh pr merge"*|*"release"*)
      operation="release"
      risk="high"
      category="ops"
      ;;
    *"npm install"*|*"npm add"*|*"npm i "*|*"docker build"*|*"docker run"*|*"git commit"*)
      operation="code-change"
      risk="medium"
      category="ops"
      ;;
  esac

  event_file=$(mktemp)
  policy_file=$(mktemp)

  jq -n \
    --arg event "guardrail_pre_bash_policy" \
    --arg tool "bash" \
    --arg operation "$operation" \
    --arg project_dir "$project_dir" \
    --arg risk "$risk" \
    --arg category "$category" \
    --arg session "${SESSION_ID:-unknown}" \
    --arg command "$CMD" \
    '{
      event:$event,
      tool:$tool,
      operation:$operation,
      project_dir:$project_dir,
      risk:$risk,
      category:$category,
      session_id:$session,
      input:{command:$command},
      context:{entrypoint:"guardrail-pre-bash-dispatcher"}
    }' > "$event_file"

  if ! "$policy_check" "$event_file" > "$policy_file" 2>/dev/null; then
    rm -f "$event_file" "$policy_file"
    guardrail_audit "agent_control_policy_guard" "$CMD" "policy engine unavailable" "blocked"
    deny "AGENT-CONTROL: The policy engine failed to answer. The command is blocked pending manual review."
  fi

  decision=$(jq -r '.decision // "deny"' "$policy_file" 2>/dev/null)
  reasons=$(jq -r '.reasons // [] | join("; ")' "$policy_file" 2>/dev/null)
  actions=$(jq -r '.required_actions // [] | join("; ")' "$policy_file" 2>/dev/null)

  rm -f "$event_file" "$policy_file"

  case "$decision" in
    deny)
      [ -z "$reasons" ] && reasons="The policy engine denied this command."
      guardrail_audit "agent_control_policy_guard" "$CMD" "$reasons" "blocked"
      deny "AGENT-CONTROL: Policy denied this command ($operation, risk=$risk): $reasons"
      ;;
    warn)
      guardrail_audit "agent_control_policy_guard" "$CMD" "${reasons:-review required}" "warned"
      warn "AGENT-CONTROL: Policy warning: ${reasons:-review required}. Required actions: ${actions:-document the evidence where applicable}."
      return 0
      ;;
  esac

  if [ -n "$actions" ] && [ "$risk" != "low" ]; then
    warn "AGENT-CONTROL: Required actions for this command: $actions"
  fi
}
