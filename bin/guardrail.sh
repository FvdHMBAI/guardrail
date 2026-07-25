#!/bin/bash
# GuardRail CLI
# Pre-execution security guards for AI coding agents.
# License: MIT

set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  cat << EOF
GuardRail v$VERSION - Pre-execution security guards for AI coding agents

Usage: guardrail <command> [options]

Commands:
  init       Install GuardRail into Claude Code
  test       Run regression tests
  status     Show active guards and recent activity
  audit      Generate audit report
  version    Show version

Options:
  -h, --help    Show this help message
  -v, --version Show version

Examples:
  npx guardrail init          Install guards
  guardrail test              Run all tests
  guardrail status            Check guard status
  guardrail audit --days 30   Audit report for last 30 days

EOF
}

cmd_init() {
  bash "$SCRIPT_DIR/install.sh" "$@"
}

cmd_test() {
  if [ -f "$SCRIPT_DIR/tests/regression.sh" ]; then
    bash "$SCRIPT_DIR/tests/regression.sh" "$@"
  else
    echo "No tests found at $SCRIPT_DIR/tests/regression.sh"
    exit 1
  fi
}

cmd_status() {
  local INSTALL_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}/hooks/guardrail"

  echo "GuardRail v$VERSION Status"
  echo "========================"
  echo ""

  # Count guards
  if [ -d "$INSTALL_DIR/guards/core" ]; then
    local core_count
    core_count=$(find "$INSTALL_DIR/guards/core" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo "Core guards:   $core_count"
  else
    echo "Core guards:   not installed"
  fi

  if [ -d "$INSTALL_DIR/guards/custom" ]; then
    local custom_count
    custom_count=$(find "$INSTALL_DIR/guards/custom" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo "Custom guards: $custom_count"
  fi

  echo ""

  # Show recent audit activity
  local AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"
  if [ -f "$AUDIT_LOG" ]; then
    local total blocked
    total=$(wc -l < "$AUDIT_LOG" | tr -d ' ')
    blocked=$(grep -c "blocked" "$AUDIT_LOG" 2>/dev/null || echo 0)
    echo "Audit log: $AUDIT_LOG"
    echo "  Total events:  $total"
    echo "  Blocked:       $blocked"
    echo ""
    echo "Last 5 events:"
    tail -5 "$AUDIT_LOG" 2>/dev/null | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo "No audit log found."
  fi
}

cmd_audit() {
  local days=7
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"

  echo "GuardRail Audit Report"
  echo "======================"
  echo "Period: last $days days"
  echo "Generated: $(date -Iseconds)"
  echo ""

  if [ ! -f "$AUDIT_LOG" ]; then
    echo "No audit log found at $AUDIT_LOG"
    exit 0
  fi

  local cutoff
  cutoff=$(date -d "-$days days" +%Y-%m-%d 2>/dev/null || date -v-${days}d +%Y-%m-%d 2>/dev/null || echo "2000-01-01")

  echo "## Summary"
  local total blocked allowed
  total=$(awk -v d="$cutoff" '$2 >= d' "$AUDIT_LOG" 2>/dev/null | wc -l | tr -d ' ')
  blocked=$(awk -v d="$cutoff" '$2 >= d' "$AUDIT_LOG" 2>/dev/null | grep -c "blocked" || echo 0)
  allowed=$(awk -v d="$cutoff" '$2 >= d' "$AUDIT_LOG" 2>/dev/null | grep -c "approved\|allowed" || echo 0)
  echo "  Total events: $total"
  echo "  Blocked:      $blocked"
  echo "  Allowed:      $allowed"
  echo ""

  echo "## Top Blocking Guards"
  awk -v d="$cutoff" '$2 >= d && /blocked/' "$AUDIT_LOG" 2>/dev/null | \
    awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}' | \
    sort | uniq -c | sort -rn | head -10 | \
    while read -r count guard; do
      echo "  $count  $guard"
    done
  echo ""

  echo "## Recent Blocks"
  grep "blocked" "$AUDIT_LOG" 2>/dev/null | tail -10 | while IFS= read -r line; do
    echo "  $line"
  done
}

cmd_version() {
  echo "guardrail v$VERSION"
}

# Main dispatch
case "${1:-}" in
  init)     shift; cmd_init "$@" ;;
  test)     shift; cmd_test "$@" ;;
  status)   shift; cmd_status "$@" ;;
  audit)    shift; cmd_audit "$@" ;;
  version)  cmd_version ;;
  -v|--version) cmd_version ;;
  -h|--help|"") usage ;;
  *)
    echo "Unknown command: $1"
    echo "Run 'guardrail --help' for usage."
    exit 1
    ;;
esac
