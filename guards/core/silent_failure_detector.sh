#!/bin/bash
# GuardRail Core Guard: silent_failure_detector
# Detects suspiciously empty results from data-producing commands.
# Pattern: Exit 0 but result is empty/null where data is expected.
# License: MIT
#
# Shared vars: $CMD, $OUTPUT, $SESSION_ID
# Shared fns: add_context()

hook_silent_failure_detector() {
  [ -z "$OUTPUT" ] && return 0
  local warning=""

  # psql SELECT with 0 result rows (but not COUNT/EXISTS/schema queries)
  if echo "$CMD" | grep -qiE "psql.*SELECT" && ! echo "$CMD" | grep -qiE "COUNT|EXISTS|pg_|information_schema|\\\\d|EXPLAIN"; then
    if echo "$OUTPUT" | grep -qE "^\(0 rows?\)$"; then
      warning="psql SELECT returned 0 rows"
    fi
  fi

  # curl API calls returning empty arrays/null
  if echo "$CMD" | grep -qE "curl.*(api/)" && ! echo "$CMD" | grep -qiE "health|status|ping"; then
    if echo "$OUTPUT" | grep -qE '^\[\]$|^null$|^{"data":\[\]}$'; then
      warning="API response is empty ([], null, or empty data array)"
    fi
  fi

  # docker exec with completely empty output
  if echo "$CMD" | grep -qE "docker exec.*psql.*SELECT" && ! echo "$CMD" | grep -qiE "UPDATE|INSERT|DELETE|ALTER|CREATE|DROP|GRANT"; then
    if [ -z "$(echo "$OUTPUT" | tr -d '[:space:]')" ]; then
      warning="docker exec psql returned completely empty output"
    fi
  fi

  if [ -n "$warning" ]; then
    add_context "SILENT-FAILURE WARNING: $warning. Check if the result is correct! Empty results from data-producing commands often indicate missing grants, wrong database, or swallowed errors."
  fi
}
