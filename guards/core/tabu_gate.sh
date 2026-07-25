#!/bin/bash
# GuardRail Core Guard: tabu_gate
# Blocks destructive database operations on protected tables and on the
# PostgreSQL host-based authentication config. Also scans script and SQL
# files referenced by the command, because "bash script.sh" would otherwise
# bypass every pattern below.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny(), warn()
# Config: GUARDRAIL_PROTECTED_TABLES, GUARDRAIL_MAX_FILE_SCAN, GUARDRAIL_HOME

_tabu_deny() {
  local reason="$1"
  guardrail_log "tabu_gate" "DENY session=${SESSION_ID:-unknown} reason=$reason"
  guardrail_audit "tabu_gate" "$CMD" "$reason" "blocked"
  guardrail_notify "tabu_gate" "$reason" "critical"
  deny "$reason"
}

# Scan arbitrary text for forbidden patterns.
# $1 = text to scan, $2 = origin ("" for the command line, otherwise a file path)
_tabu_scan() {
  local text="$1" src="$2" origin=""
  [ -n "$src" ] && origin=" [found in file: $src]"

  local tables_re
  tables_re=$(_guardrail_list_to_regex "${GUARDRAIL_PROTECTED_TABLES:-auth.users profiles members}")

  # Superuser password change
  echo "$text" | grep -qiE "ALTER[[:space:]]+(USER|ROLE)[[:space:]]+postgres\b.*PASSWORD" && \
    _tabu_deny "TABU-GATE: Changing the postgres superuser password is blocked. It locks out every service that shares the credential.$origin"

  # Writes to protected tables
  echo "$text" | grep -qiE "(INSERT[[:space:]]+INTO|UPDATE|DELETE[[:space:]]+FROM)[[:space:]]+(public\.)?${tables_re}" && \
    _tabu_deny "TABU-GATE: Write operations (INSERT/UPDATE/DELETE) on protected tables are blocked. Use the application layer instead.$origin"

  # DROP TABLE on protected tables
  echo "$text" | grep -qiE "DROP[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?(public\.)?${tables_re}" && \
    _tabu_deny "TABU-GATE: DROP TABLE on a protected table is blocked.$origin"

  # TRUNCATE on protected tables
  echo "$text" | grep -qiE "TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?(public\.)?${tables_re}" && \
    _tabu_deny "TABU-GATE: TRUNCATE on a protected table is blocked.$origin"

  # ALTER TABLE on protected tables
  echo "$text" | grep -qiE "ALTER[[:space:]]+TABLE[[:space:]]+(public\.)?${tables_re}" && \
    _tabu_deny "TABU-GATE: Schema changes (ALTER TABLE) on protected tables are blocked.$origin"

  # Bulk import into protected tables
  echo "$text" | grep -qiE "COPY[[:space:]]+(public\.)?${tables_re}[[:space:]]+FROM" && \
    _tabu_deny "TABU-GATE: COPY ... FROM into a protected table is blocked.$origin"

  # DROP DATABASE / DROP SCHEMA
  echo "$text" | grep -qiE "DROP[[:space:]]+(DATABASE|SCHEMA)[[:space:]]" && \
    _tabu_deny "TABU-GATE: DROP DATABASE / DROP SCHEMA is blocked. Restore paths for this are rarely tested.$origin"

  # pg_hba.conf: only write operations, not grep/cat
  echo "$text" | grep -qiE "(sed|echo[[:space:]]*>|tee|cp|mv|truncate)[[:space:]].*pg_hba\.conf" && \
    _tabu_deny "TABU-GATE: Modifying pg_hba.conf is blocked. A broken rule locks out every database client at once.$origin"

  # Config reload in a psql context
  if echo "$text" | grep -qiE "pg_reload_conf"; then
    echo "$text" | grep -qi "psql" && \
      _tabu_deny "TABU-GATE: pg_reload_conf() is blocked. Reload the configuration through your deployment tooling.$origin"
  fi

  # SELECT * without WHERE on protected tables
  if echo "$text" | grep -qiE "SELECT[[:space:]]+\*[[:space:]]+FROM[[:space:]]+(public\.)?${tables_re}([[:space:]]|;|$)" && \
     ! echo "$text" | grep -qiE 'WHERE[[:space:]]'; then
    _tabu_deny "TABU-GATE: SELECT * on a protected table without a WHERE clause is blocked. Add a filter or select specific columns.$origin"
  fi
}

# Extract referenced script and SQL files from the command.
# Covers: bash/sh/zsh X, source X, . X, ./X, psql -f X, psql --file=X
_tabu_referenced_files() {
  {
    echo "$CMD" | grep -oE '(^|[[:space:]]|;|&&|\|\|)[[:space:]]*(bash|sh|zsh|ksh|source)[[:space:]]+[^[:space:];&|<>]+' \
      | sed -E 's/^[[:space:];&|]*(bash|sh|zsh|ksh|source)[[:space:]]+//; s/.*[[:space:]](bash|sh|zsh|ksh|source)[[:space:]]+//'
    echo "$CMD" | grep -oE '(^|[[:space:]]|;|&&|\|\|)[[:space:]]*\.[[:space:]]+[^[:space:];&|<>]+' \
      | sed -E 's/.*\.[[:space:]]+//'
    # Only paths in execution position, so "rm file.sh" remains possible.
    echo "$CMD" | grep -oE '(^|[;&|][[:space:]]*)\.{0,2}/[^[:space:];&|<>]+\.(sh|bash)' \
      | sed -E 's/^[;&|][[:space:]]*//' | tr -d ' '
    # File arguments only in a psql context.
    if echo "$CMD" | grep -qE '(^|[[:space:]])psql([[:space:]]|$)'; then
      echo "$CMD" | grep -oE '(-f|--file=?)[[:space:]]*[^[:space:];&|<>]+\.(sql|sh)' \
        | sed -E 's/^(-f|--file=?)[[:space:]]*//'
    fi
  } 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

hook_tabu_gate() {
  # Never block harmless read-only commands without shell chaining
  if echo "$CMD" | grep -qE '^[[:space:]]*(grep|rg|ag|cat|head|tail|less|wc)\b[^;&|$`<>]*$'; then
    return 0
  fi

  # 1. The command line itself (covers heredocs contained in the command)
  _tabu_scan "$CMD" ""

  # A pure syntax check executes nothing, so file contents are not inspected.
  # Otherwise no script could be validated with "bash -n" anymore.
  if echo "$CMD" | grep -qE '\b(bash|sh|zsh|ksh)[[:space:]]+-n\b'; then
    return 0
  fi

  # 2. Contents of referenced script and SQL files
  local f content count=0
  local max_files="${GUARDRAIL_MAX_FILE_SCAN:-5}"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ "$count" -ge "$max_files" ] && break
    # GuardRail's own guards contain these patterns by design. Only skip files
    # actually registered in a dispatcher, never a whole directory: a blanket
    # path exemption lets anyone drop a script there and bypass every rule.
    case "$f" in
      "${GUARDRAIL_HOME:-$HOME/.guardrail}"/guards/*|*/guardrail/guards/*)
        if grep -rqF "$(basename "$f")" "${GUARDRAIL_HOME:-$HOME/.guardrail}"/dispatchers/*.sh 2>/dev/null; then
          continue
        fi
        ;;
    esac
    [ -f "$f" ] && [ -r "$f" ] || continue
    [ "$(stat -c %s "$f" 2>/dev/null || echo 999999)" -gt 524288 ] && continue
    content="$(head -c 524288 "$f" 2>/dev/null)"
    [ -z "$content" ] && continue
    count=$((count + 1))
    _tabu_scan "$content" "$f"
  done <<< "$(_tabu_referenced_files)"
}
