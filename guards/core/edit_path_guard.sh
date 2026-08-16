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

  # Canonicalize before matching: /a/./b, /a//b and /a/../a/b all write to the
  # same file but would slip past a literal regex. realpath -m -s normalizes
  # . / .. / duplicate slashes WITHOUT resolving symlinks (so literal-path
  # matches still hold). Falls back to the raw path if realpath is unavailable.
  local canon
  canon=$(realpath -m -s -- "$fp" 2>/dev/null) && [ -n "$canon" ] && fp="$canon"

  # 1. Self-bypass: writing anything under GuardRail's own install tree via a
  #    file tool. Covers the disable mechanism AND every directory the
  #    dispatchers auto-source: guards/core, guards/pro, guards/custom (incl.
  #    preedit_*.sh / edit_*.sh), dispatchers/, and lib/. Writing a new
  #    custom guard would otherwise be auto-sourced and executed on the next
  #    tool call, bypassing the whole system.
  if printf '%s' "$fp" | grep -qE 'guardrail/\.disabled$|/\.guardrail/disable\.key$|guardrail/(dispatchers|lib)/|guardrail/guards/(core|pro|custom)/'; then
    guardrail_audit "edit_path_guard" "file-tool write to guardrail control path" "$fp" "blocked"
    deny "Self-bypass blocked: AI agents must not create or modify GuardRail's own guards, dispatchers, or disable mechanism through file tools. This includes custom guards, which are auto-executed. Only a human operator may change these from an interactive terminal."
    return 0
  fi

  # 1a. A custom-guards dir configured via env var. The dispatcher auto-sources
  #     preedit_*.sh from $GUARDRAIL_CUSTOM_GUARDS_DIR, so a write there is the
  #     same bypass as guards/custom/ but at an operator-configured path.
  if [ -n "${GUARDRAIL_CUSTOM_GUARDS_DIR:-}" ]; then
    case "$fp" in
      "${GUARDRAIL_CUSTOM_GUARDS_DIR%/}"/*)
        guardrail_audit "edit_path_guard" "file-tool write to configured custom-guards dir" "$fp" "blocked"
        deny "Self-bypass blocked: AI agents must not write into the configured custom-guards directory (GUARDRAIL_CUSTOM_GUARDS_DIR). Those files are auto-executed. Only a human operator may change them from an interactive terminal."
        return 0
        ;;
    esac
  fi

  # 1b. The hook registry itself. .claude/settings(.local).json is where the
  #     PreToolUse hooks are wired in (install.sh). Rewriting it removes every
  #     guard at once, including this one, without touching any 'guardrail'
  #     path. This is the highest-value bypass and must be blocked.
  if printf '%s' "$fp" | grep -qE '(^|/)\.claude/settings(\.local)?\.json$'; then
    guardrail_audit "edit_path_guard" "file-tool write to Claude hook registry" "$fp" "blocked"
    deny "Self-bypass blocked: AI agents must not modify .claude/settings.json through file tools. That file registers the guard hooks; rewriting it would disable all enforcement. A human operator must change hook configuration from an interactive terminal."
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
    guardrail_audit "edit_path_guard" "file-tool write to auto-executed startup/hook file" "$fp" "blocked"
    deny "Blocked: writing to an auto-executed file ($fp) through a file tool. Git hooks and shell startup files run code automatically. If this is intended, make it an explicit reviewed change."
    return 0
  fi

  return 0
}
