#!/bin/bash
# GuardRail Core Guard: cron_delete_guard
# Blocks deletion and silent disabling of scheduled jobs.
# A failing job should be repaired, not removed: a deleted monitoring or backup
# job produces no error, so the resulting gap goes unnoticed.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny()

hook_cron_delete_guard() {
  # crontab -r removes every cron job of the user at once
  if echo "$CMD" | grep -qE 'crontab[[:space:]]+(-[a-z]*r|--remove)\b'; then
    guardrail_audit "cron_delete_guard" "$CMD" "crontab -r" "blocked"
    deny "CRON-GUARD: 'crontab -r' deletes ALL cron jobs at once and is blocked. Repair the failing job, or edit the single line you mean to change."
  fi

  # Commenting out or filtering cron lines via sed/grep -v
  if echo "$CMD" | grep -qiE '(sed[[:space:]]+.*[/#].*crontab|sed[[:space:]]+-i.*cron|grep[[:space:]]+-v.*cron.*\|[[:space:]]*crontab)'; then
    guardrail_audit "cron_delete_guard" "$CMD" "cron line removal" "blocked"
    deny "CRON-GUARD: Deleting or commenting out cron jobs is blocked. Repair the job instead of disabling it. A silently stopped job creates a monitoring gap nobody sees."
  fi

  # Disabling systemd timers is the same problem in a different shape
  if echo "$CMD" | grep -qE 'systemctl[[:space:]]+(disable|mask)[[:space:]]+[^[:space:];&|]*\.timer'; then
    guardrail_audit "cron_delete_guard" "$CMD" "systemd timer disabled" "blocked"
    deny "CRON-GUARD: Disabling or masking a systemd timer is blocked. Fix the unit it triggers instead of turning the schedule off."
  fi
}
