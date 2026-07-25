#!/bin/bash
# GuardRail Core Guard: license_compliance_guard
# Blocks packages with viral licenses (GPL, AGPL, SSPL).
# License: MIT
#
# Shared vars: $CMD
# Shared fns: deny(), warn()

hook_license_compliance_guard() {
  echo "$CMD" | grep -qE 'npm\s+(install|add|i)\s+[a-zA-Z@]' || return 0
  local pkg; pkg=$(echo "$CMD" | grep -oP 'npm\s+(install|add|i)\s+\K[a-zA-Z@][a-zA-Z0-9@/_.-]+' | head -1)
  [ -z "$pkg" ] && return 0
  case "$pkg" in @radix-ui/*|@types/*|typescript|next|react|react-dom|tailwindcss|zod|zustand) return 0 ;; esac

  local license; license=$(npm info "$pkg" license 2>/dev/null | head -1)
  if [ -z "$license" ]; then
    warn "LICENSE-CHECK: Could not determine license for '$pkg'. Check manually before using."
    return 0
  fi

  local _allowed="${GUARDRAIL_ALLOWED_LICENSES:-MIT Apache-2.0 ISC BSD-2-Clause BSD-3-Clause 0BSD Unlicense CC0-1.0 BlueOak-1.0.0}"
  case "$license" in
    *GPL*|*AGPL*|*SSPL*|*EUPL*|*OSL*|*CPAL*)
      deny "LICENSE-BLOCK: Package '$pkg' has license '$license' (viral/copyleft). Viral licenses are NOT allowed in commercial SaaS products. Find an alternative."
      ;;
    *)
      for _lic in $_allowed; do [ "$license" = "$_lic" ] && return 0; done
      warn "LICENSE-NOTE: Package '$pkg' has unknown license '$license'. Check if commercially usable."
      ;;
  esac
}
