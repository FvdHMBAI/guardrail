#!/bin/bash
# GuardRail Core Guard: mass_update_guard
# Blocks SQL UPDATE/DELETE without WHERE clause to prevent accidental mass changes.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()

hook_mass_update_guard() {
  local _tables_re
  local _sql_without_comments
  _tables_re=$(_guardrail_list_to_regex "$GUARDRAIL_PROTECTED_TABLES")
  _sql_without_comments=$(printf '%s' "$CMD" | tr '\n' ' ' |
    sed -E ':a; s@/\*([^*]|\*+[^*/])*\*/@ @g; ta; s@--[^\r\n]*@ @g')

  if echo "$_sql_without_comments" | grep -qiE "UPDATE[[:space:]]+(public\\.)?${_tables_re}[[:space:]]+SET"; then
    if ! echo "$_sql_without_comments" | grep -qiE 'WHERE[[:space:]]+.*\bid[[:space:]]*='; then
      guardrail_log "mass-update-guard" "DENY sess=$SESSION_ID cmd=\"$(echo "$CMD" | head -c 200)\""
      deny "MASS-UPDATE-GUARD: UPDATE on protected table WITHOUT 'WHERE id = ...' detected. Mass updates are blocked. Update records individually with an id filter."
    fi
  fi

  if echo "$_sql_without_comments" | grep -qiE "DELETE[[:space:]]+FROM[[:space:]]+(public\\.)?${_tables_re}" ; then
    if ! echo "$_sql_without_comments" | grep -qiE 'WHERE[[:space:]]+.*\bid[[:space:]]*='; then
      guardrail_log "mass-update-guard" "DENY DELETE without WHERE sess=$SESSION_ID"
      deny "MASS-UPDATE-GUARD: DELETE on protected table WITHOUT WHERE clause detected. Delete records individually."
    fi
  fi
}
