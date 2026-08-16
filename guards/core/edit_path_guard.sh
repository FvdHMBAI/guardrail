#!/bin/bash
# GuardRail Core Guard: edit_path_guard
# License: MIT
# Runs in the PreToolUse pre-edit dispatcher (Write/Edit/MultiEdit).
# Shared vars: $FILE_PATH, $CONTENT, $SESSION_ID
# Shared fns: deny()
#
# Closes the "shell-only enforcement" gap: guards that only inspect Bash
# commands never see file writes made through the agent's native Write/Edit
# tools. This guard blocks the file-tool equivalents of the dangerous
# operations that the bash guards already stop.

hook_edit_path_guard() {
  local fp="$FILE_PATH"
  [ -z "$fp" ] && return 0

  # 1. Self-bypass: writing GuardRail's own disable mechanism via a file tool.
  if printf '%s' "$fp" | grep -qE 'guardrail/\.disabled$|/\.guardrail/disable\.key$|guardrail/dispatchers/|guardrail/guards/(core|pro)/'; then
    guardrail_audit "edit_path_guard" "file-tool write to guardrail control path" "$fp" "blocked"
    deny "Self-bypass blocked: AI agents must not modify GuardRail's own guards, dispatchers, or disable mechanism through file tools. Only a human operator may change these from an interactive terminal."
    return 0
  fi

  # 2. Persistence / privilege paths: writing these via a file tool is how an
  #    agent would install a backdoor that outlives the session.
  if printf '%s' "$fp" | grep -qE '(^|/)(etc/(passwd|shadow|sudoers|sudoers\.d/|cron\.d/|crontab)|\.ssh/authorized_keys|\.ssh/id_[a-z0-9]+$)'; then
    guardrail_audit "edit_path_guard" "file-tool write to privileged system path" "$fp" "blocked"
    deny "Blocked: writing to a privileged system path ($fp) through a file tool. This is a common persistence vector. Perform account/credential/cron changes as an explicit, reviewed human action."
    return 0
  fi

  # 3. Auto-executed hooks and shell startup files: silent code-execution
  #    persistence (git hooks, shell rc, profile).
  if printf '%s' "$fp" | grep -qE '(^|/)(\.git/hooks/[a-z-]+|\.(bashrc|zshrc|bash_profile|profile|zprofile)|\.config/(fish/config\.fish))$'; then
    guardrail_audit "edit_path_guard" "file-tool write to auto-executed startup/hook file" "$fp" "warned"
    deny "Blocked: writing to an auto-executed file ($fp) through a file tool. Git hooks and shell startup files run code automatically. If this is intended, make it an explicit reviewed change."
    return 0
  fi

  return 0
}
