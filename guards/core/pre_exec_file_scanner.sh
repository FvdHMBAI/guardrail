#!/bin/bash
# GuardRail Core Guard: pre_exec_file_scanner
# Scans a script file for injection payloads BEFORE it is executed.
# Command-line guards only see "bash script.sh"; without this, the contents of
# that script are never inspected.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()
# Config: GUARDRAIL_SAFE_SCRIPT_DIRS, GUARDRAIL_HOME

hook_pre_exec_file_scanner() {
  # Only execution commands, not read-only ones like cat/grep/head
  echo "$CMD" | grep -qP '^\s*(source|\.)\s+\S|^\s*(bash|sh|zsh)\s+\S|^\s*(node|python3?|ruby|perl)\s+\S|eval\s.*\$\(cat\s' || return 0

  local file=""

  if echo "$CMD" | grep -qP '^\s*(source|\.)\s+'; then
    file=$(echo "$CMD" | sed -nE 's/^\s*(source|\.)\s+([^ ;|&]+).*/\2/p')
  elif echo "$CMD" | grep -qP '^\s*(bash|sh|zsh|node|python3?|ruby|perl)\s+'; then
    file=$(echo "$CMD" | sed -nE 's/^\s*(bash|sh|zsh|node|python3?|ruby|perl)\s+([^ ;|&]+).*/\2/p')
  elif echo "$CMD" | grep -qP 'eval\s.*\$\(cat\s'; then
    file=$(echo "$CMD" | sed -nE 's/.*\$\(cat\s+([^ )]+).*/\1/p')
  fi

  file="${file/#\~/$HOME}"

  [ -z "$file" ] && return 0
  [ -f "$file" ] || return 0
  [ -r "$file" ] || return 0

  # Whitelist: system directories and vendored dependencies
  local safe_dirs="${GUARDRAIL_SAFE_SCRIPT_DIRS:-/usr/ /bin/ /sbin/}"
  local safe_dir
  for safe_dir in $safe_dirs; do
    case "$file" in "$safe_dir"*) return 0 ;; esac
  done
  case "$file" in
    */node_modules/*) return 0 ;;
    "${GUARDRAIL_HOME:-$HOME/.guardrail}"/guards/*) return 0 ;;
  esac

  local fsize
  fsize=$(stat -c%s "$file" 2>/dev/null || echo 0)
  [ "$fsize" -gt 1048576 ] && return 0

  local content
  content=$(head -c 524288 "$file" 2>/dev/null)
  [ -z "$content" ] && return 0

  local found=""

  # Instruction override
  if echo "$content" | grep -qiP '(ignore\s+(all\s+)?previous\s+instructions|forget\s+(all\s+)?(previous|prior)|disregard\s+(all\s+)?(above|previous)|override\s+(all\s+)?(system|safety)\s+(prompt|rules))'; then
    found="Instruction-Override"
  fi

  # Role hijack
  if echo "$content" | grep -qiP '(you\s+are\s+now|new\s+instructions?:|system\s*:\s*you|<system>|IMPORTANT:\s*ignore|act\s+as\s+(if|a)\s|pretend\s+you\s+are|from\s+now\s+on\s+you)'; then
    found="${found:+$found, }Role-Hijack"
  fi

  # Command injection, checked only on non-comment lines so that documentation
  # describing these patterns does not trip the guard
  local code_lines
  code_lines=$(echo "$content" | grep -vP '^\s*(#|//|/\*|\*)' 2>/dev/null)
  if echo "$code_lines" | grep -qiP '(curl\s.*\|\s*bash|wget\s.*\|\s*sh|base64\s+-d\s.*\|\s*(sh|bash))'; then
    found="${found:+$found, }Command-Injection"
  fi

  # Data exfiltration
  if echo "$content" | grep -qiP '(send\s+(this|the|all|my)\s+(data|info|key|token|secret|credential)|exfiltrat|post\s+to\s+https?://|upload\s+(this|to)\s+|webhook\.site|requestbin\.|pipedream\.)'; then
    found="${found:+$found, }Data-Exfiltration"
  fi

  # Credential access
  if echo "$code_lines" | grep -qiP '(\.credentials\.json|oauth_creds|auth\.json|cat\s+.*\.env\b|credentials\.json|service.role.key|id_rsa|\.aws/credentials)'; then
    found="${found:+$found, }Credential-Access"
  fi

  # Multi-step attack: read something sensitive, then send it somewhere
  if echo "$content" | grep -qiP '(first\s+(read|cat|get)\s+.*then\s+(send|post|curl)|step\s*1.*step\s*2|read\s+the\s+(credentials?|\.env|secrets?|password|token)\s+.{0,20}(file|from|and))'; then
    found="${found:+$found, }Multi-Step-Attack"
  fi

  if [ -n "$found" ]; then
    guardrail_log "pre_exec_file_scanner" "INJECTION session=${SESSION_ID:-unknown} type=$found file=$file"
    guardrail_audit "pre_exec_file_scanner" "$CMD" "$found in $file" "blocked"
    guardrail_notify "pre_exec_file_scanner" "injection payload in $file" "critical"
    deny "PRE-EXEC-INJECTION: '$file' contains suspicious patterns ($found) and was NOT executed. Inspect the file contents before running it."
  fi
}
