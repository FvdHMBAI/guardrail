#!/bin/bash
# GuardRail Core Guard: db_backup_gate
# Requires a recent database backup before destructive SQL runs.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()
# Config: GUARDRAIL_BACKUP_DIR, GUARDRAIL_BACKUP_MAX_AGE_HOURS, GUARDRAIL_STATE_DIR

hook_db_backup_gate() {
  echo "$CMD" | grep -qiE '(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|COLUMN)|TRUNCATE|DELETE[[:space:]]+FROM|ALTER[[:space:]]+TABLE[[:space:]]+.*DROP)' || return 0

  local backup_dir="${GUARDRAIL_BACKUP_DIR:-/var/backups/postgres}"
  local max_age_hours="${GUARDRAIL_BACKUP_MAX_AGE_HOURS:-6}"
  local state_dir="${GUARDRAIL_STATE_DIR:-/tmp/guardrail}"
  local latest_backup=""
  local backup_age_hours=999

  if [ -d "$backup_dir" ]; then
    latest_backup=$(ls -t "$backup_dir"/*.sql.gz 2>/dev/null | head -1)
  fi

  if [ -n "$latest_backup" ]; then
    local file_epoch now_epoch
    now_epoch=$(date +%s)
    file_epoch=$(stat -c %Y "$latest_backup" 2>/dev/null || echo 0)
    backup_age_hours=$(( (now_epoch - file_epoch) / 3600 ))
  fi

  # Single-use operator approval
  if [ -f "$state_dir/backup-confirmed" ]; then
    guardrail_log "db_backup_gate" "OVERRIDE session=${SESSION_ID:-unknown} age=${backup_age_hours}h"
    guardrail_audit "db_backup_gate" "$CMD" "destructive SQL with operator override" "approved"
    rm -f "$state_dir/backup-confirmed" 2>/dev/null
    return 0
  fi

  if [ -z "$latest_backup" ] || [ "$backup_age_hours" -gt "$max_age_hours" ]; then
    local age_msg="no backup found in $backup_dir"
    [ -n "$latest_backup" ] && age_msg="the latest backup is ${backup_age_hours}h old ($(basename "$latest_backup"))"

    guardrail_log "db_backup_gate" "DENY session=${SESSION_ID:-unknown} age=${backup_age_hours}h cmd=\"$(echo "$CMD" | head -c 150)\""
    guardrail_audit "db_backup_gate" "$CMD" "destructive SQL without a fresh backup" "blocked"
    deny "DB-BACKUP-GATE: This command destroys data (DROP/TRUNCATE/DELETE/ALTER DROP), but $age_msg and the limit is ${max_age_hours}h. Take a fresh backup, then retry. Single-use override: touch $state_dir/backup-confirmed"
  fi
}
