#!/bin/bash
# GuardRail Core Guard: npm_audit_guard
# Warns on npm install to run npm audit afterward.
# License: MIT
#
# Shared vars: $CMD
# Shared fns: warn()

hook_npm_audit_guard() {
  echo "$CMD" | grep -qE 'npm\s+(install|add|i)\b' || return 0
  echo "$CMD" | grep -qE 'npm\s+ci\b' && return 0
  local pkg; pkg=$(echo "$CMD" | grep -oP 'npm\s+(install|add|i)\s+\K[a-zA-Z@][a-zA-Z0-9@/_.-]+' | head -1)
  if [ -n "$pkg" ]; then
    warn "NPM-AUDIT: After installing '$pkg', run 'npm audit'. Block High/Critical CVEs. Check license: 'npm info $pkg license'."
  fi
}
