#!/bin/bash
# GuardRail Core Guard: secret_output_guard
# Prevents API keys, JWT tokens, and secrets from appearing in terminal output.
# License: MIT
#
# Shared vars: $CMD, $SESSION_ID
# Shared fns: deny(), warn()

hook_secret_output_guard() {
  if echo "$CMD" | grep -qiE 'grep[^|;]*(key:|secret:|token:|password:)[^|;]*(\.yml|\.yaml|\.json)'; then
    deny "SECRET-OUTPUT-GUARD: grep for key:/secret:/token: in config files shows secrets. Capture in a variable."
  fi
  if echo "$CMD" | grep -qiE 'docker\s+inspect\b' && ! echo "$CMD" | grep -qiE '\-\-format|\-f '; then
    deny "SECRET-OUTPUT-GUARD: docker inspect WITHOUT --format dumps ALL env vars."
  fi
  if echo "$CMD" | grep -qiE 'docker logs[^|;]*(auth|gotrue)' && ! echo "$CMD" | grep -qiE '(grep -v|python3|\| grep (error|status|level|duration))'; then
    deny "SECRET-OUTPUT-GUARD: Auth container logs contain emails and tokens. Filter with grep."
  fi
  if echo "$CMD" | grep -qiE 'environment_variables' && echo "$CMD" | grep -qiE '(value|SELECT \*)'; then
    deny "SECRET-OUTPUT-GUARD: environment_variables table contains secrets. Query only the key column."
  fi
  if echo "$CMD" | grep -qE 'echo.*eyJhbG'; then
    deny "SECRET-OUTPUT-GUARD: JWT token detected in echo command."
  fi
}
