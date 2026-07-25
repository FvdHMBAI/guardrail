#!/bin/bash
# GuardRail CLI
# Pre-execution security guards for AI coding agents.
# License: MIT

set -euo pipefail

VERSION="0.1.1"
REAL_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")/.." && pwd)"

usage() {
  cat << EOF
GuardRail v$VERSION - Pre-execution security guards for AI coding agents

Usage: guardrail <command> [options]

Commands:
  init       Install GuardRail into Claude Code
  test       Run regression tests
  pentest    Run security PEN-test against all guards
  status     Show active guards and recent activity
  audit      Generate audit report
  new        Create a new guard from template
  upgrade    Learn about GuardRail Pro
  version    Show version

Options:
  -h, --help    Show this help message
  -v, --version Show version

Examples:
  npx guardrail-agent init    Install guards
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

  if [ -d "$INSTALL_DIR/guards/pro" ]; then
    local pro_count
    pro_count=$(find "$INSTALL_DIR/guards/pro" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo "Pro guards:    $pro_count"
  else
    echo "Pro guards:    not installed (guardrail upgrade --key ...)"
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
  local days=7 compliance=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --days) days="$2"; shift 2 ;;
      --compliance)
        cat << 'COMPEOF'
GuardRail Pro Compliance Audit
==============================

Compliance audit with EU AI Act article mapping and PDF export
is available in GuardRail Pro.

Includes:
  - Guard-to-Article mapping (Art. 9, 10, 12, 14, 15)
  - Risk classification per guard
  - Compliance coverage percentage
  - PDF report for auditors and regulators
  - Evidence trail with timestamps

Available with GuardRail Pro subscription.
Learn more: https://guardrail.dev/pro

COMPEOF
        return ;;
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

cmd_pentest() {
  local pro_flag=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --pro) pro_flag=1; shift ;;
      *) shift ;;
    esac
  done

  if [ -n "$pro_flag" ]; then
    cat << 'PROEOF'
GuardRail Pro PEN-Test
======================

Pro PEN-Test includes:
  - 50+ attack patterns from real production incidents
  - Profile escape testing (database, docker, remote, deploy)
  - Bypass persistence checks (gate files, skip flags)
  - Multi-step attack sequence simulation
  - JSON compliance report for auditors

Available with GuardRail Pro subscription.
Learn more: https://guardrail.dev/pro

PROEOF
    return
  fi

  local INSTALL_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}/hooks/guardrail"
  local GUARDS_DIR="$INSTALL_DIR/guards/core"
  local LIB_DIR="$INSTALL_DIR/lib"
  local P=0 F=0

  echo "GuardRail PEN-Test v$VERSION"
  echo "==========================="
  echo ""

  # Phase 1: Syntax check
  echo "Phase 1: Syntax Check"
  if [ ! -d "$GUARDS_DIR" ]; then
    echo "  ERROR: Guards not installed. Run 'guardrail init' first."
    exit 1
  fi
  for g in "$GUARDS_DIR"/*.sh; do
    [ -f "$g" ] || continue
    if bash -n "$g" 2>/dev/null; then
      P=$((P+1))
    else
      F=$((F+1)); echo "  FAIL: $(basename "$g") has syntax errors"
    fi
  done
  echo "  $P guards passed syntax check"
  echo ""

  # Phase 2: Dispatcher check
  echo "Phase 2: Dispatcher Wiring"
  for d in "$INSTALL_DIR/dispatchers"/*.sh; do
    [ -f "$d" ] || continue
    if bash -n "$d" 2>/dev/null; then
      P=$((P+1)); echo "  OK: $(basename "$d")"
    else
      F=$((F+1)); echo "  FAIL: $(basename "$d") has syntax errors"
    fi
  done
  echo ""

  # Phase 3: Guard simulation
  echo "Phase 3: Security Gate Simulation"

  _pen_pre() {
    local gf="$1" fn="$2" cmd="$3"
    (
      source "$LIB_DIR/guardrail-common.sh" 2>/dev/null
      source "$GUARDS_DIR/$gf" 2>/dev/null
      CMD="$cmd"; CMD_SHELL="$cmd"; SESSION_ID="pentest-$$"; OUTPUT=""; FILE_PATH=""
      R=""
      deny() { R="DENY"; }; allow_with_msg() { R="ALLOW"; }; warn() { R="WARN"; }
      $fn 2>/dev/null; echo "${R:-PASS}"
    )
  }

  _pen_check() {
    local name="$1" expect="$2" result="$3" desc="$4"
    if [ "$expect" = "DENY" ] && [ "$result" = "DENY" ]; then
      P=$((P+1))
    elif [ "$expect" = "PASS" ] && [ "$result" != "DENY" ]; then
      P=$((P+1))
    else
      F=$((F+1)); echo "  FAIL: [$name] $desc (expected $expect, got $result)"
    fi
  }

  # Test each core guard with 2 attacks + 1 false positive
  if [ -f "$GUARDS_DIR/main_push_guard.sh" ]; then
    r=$(_pen_pre main_push_guard.sh hook_main_push_guard "git push origin main")
    _pen_check main_push DENY "$r" "push to main"
    r=$(_pen_pre main_push_guard.sh hook_main_push_guard "git push --force origin feat")
    _pen_check main_push DENY "$r" "force push"
    r=$(_pen_pre main_push_guard.sh hook_main_push_guard "git push origin develop")
    _pen_check main_push PASS "$r" "push develop (FP)"
  fi

  if [ -f "$GUARDS_DIR/destructive_path_guard.sh" ]; then
    r=$(_pen_pre destructive_path_guard.sh hook_destructive_path_guard "rm -rf /etc")
    _pen_check destr DENY "$r" "rm -rf /etc"
    r=$(_pen_pre destructive_path_guard.sh hook_destructive_path_guard "rm file.txt")
    _pen_check destr PASS "$r" "rm single file (FP)"
  fi

  if [ -f "$GUARDS_DIR/firewall_flush_guard.sh" ]; then
    r=$(_pen_pre firewall_flush_guard.sh hook_firewall_flush_guard "iptables -F")
    _pen_check fw DENY "$r" "iptables flush"
    r=$(_pen_pre firewall_flush_guard.sh hook_firewall_flush_guard "ufw allow 80")
    _pen_check fw PASS "$r" "ufw allow (FP)"
  fi

  if [ -f "$GUARDS_DIR/service_protection_guard.sh" ]; then
    r=$(_pen_pre service_protection_guard.sh hook_service_protection_guard "systemctl stop docker")
    _pen_check svc DENY "$r" "stop docker"
    r=$(_pen_pre service_protection_guard.sh hook_service_protection_guard "systemctl restart myapp")
    _pen_check svc PASS "$r" "restart myapp (FP)"
  fi

  echo ""
  echo "==========================="
  echo "  Passed: $P   Failed: $F"
  echo "==========================="
  if [ "$F" -gt 0 ]; then
    echo ""
    echo "Some security gates failed. Review the output above."
    exit 1
  fi
  echo ""
  echo "All security gates passed."
  echo ""
  echo "For advanced PEN-testing (50+ attack patterns, profile escapes,"
  echo "bypass persistence checks): guardrail pentest --pro"
}

cmd_new() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: guardrail new <guard_name>"
    echo ""
    echo "Creates a new guard template with matching test file."
    echo ""
    echo "Example:"
    echo "  guardrail new block_npm_global"
    exit 1
  fi

  local INSTALL_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}/hooks/guardrail"
  local CUSTOM_DIR="$INSTALL_DIR/guards/custom"
  local GUARD_FILE="$CUSTOM_DIR/${name}.sh"
  local TEST_FILE="$CUSTOM_DIR/${name}_test.sh"

  mkdir -p "$CUSTOM_DIR"

  if [ -f "$GUARD_FILE" ]; then
    echo "Guard already exists: $GUARD_FILE"
    exit 1
  fi

  cat > "$GUARD_FILE" << GUARDEOF
#!/bin/bash
# GuardRail Custom Guard: $name
# TODO: Describe what this guard protects against.
# License: MIT
#
# Type: pre-bash (rename with post_ prefix for post-bash, edit_ for post-edit)
# Shared vars: \$CMD, \$CMD_SHELL, \$SESSION_ID
# Shared fns: deny(), warn(), guardrail_audit()

hook_${name}() {
  # TODO: Replace with your pattern
  if echo "\$CMD_SHELL" | grep -qE 'YOUR_DANGEROUS_PATTERN'; then
    guardrail_audit "$name" "blocked" "\$(echo "\$CMD_SHELL" | head -c 60)"
    deny "${name^^}: Explain why this is blocked. Suggest alternative."
    return
  fi
}
GUARDEOF

  cat > "$TEST_FILE" << TESTEOF
#!/bin/bash
# Tests for $name
# Run: bash $TEST_FILE

SCRIPT_DIR="\$(cd "\$(dirname "\$0")/../.." && pwd)"
source "\$SCRIPT_DIR/lib/guardrail-common.sh"
source "\$(dirname "\$0")/${name}.sh"

P=0; F=0
CMD=""; CMD_SHELL=""; SESSION_ID="test-\$\$"; OUTPUT=""; R=""
deny() { R="DENY: \$1"; }

echo "Tests for $name"
echo "========================="

# True positive: must block
CMD="YOUR_DANGEROUS_COMMAND"; CMD_SHELL="\$CMD"; R=""
hook_${name}
if echo "\$R" | grep -q "DENY"; then echo "  OK: blocks dangerous command"; P=\$((P+1))
else echo "  FAIL: should block dangerous command"; F=\$((F+1)); fi

# False positive: must pass
CMD="safe command here"; CMD_SHELL="\$CMD"; R=""
hook_${name}
if echo "\$R" | grep -q "DENY"; then echo "  FAIL: should allow safe command"; F=\$((F+1))
else echo "  OK: allows safe command"; P=\$((P+1)); fi

echo ""
echo "Passed: \$P  Failed: \$F"
[ "\$F" -eq 0 ] && echo "ALL PASSED" || exit 1
TESTEOF

  chmod +x "$GUARD_FILE" "$TEST_FILE"

  echo "Guard created:"
  echo "  Guard: $GUARD_FILE"
  echo "  Test:  $TEST_FILE"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $GUARD_FILE -- replace YOUR_DANGEROUS_PATTERN"
  echo "  2. Edit $TEST_FILE -- add your test commands"
  echo "  3. Run: bash $TEST_FILE"
  echo "  4. Guard loads automatically on next command"
}

cmd_upgrade() {
  local license_key=""
  local api_url="${GUARDRAIL_API_URL:-https://license.guardrail.promptandbuild.de}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --key) license_key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ -z "$license_key" ]; then
    cat << 'EOF'
GuardRail Pro
=============

40+ advanced guards derived from real production incidents.

What's included:
  - Advanced PII detection (15+ leak vectors)
  - Multi-step attack detection
  - Script content analysis
  - Supply chain security (npm audit, license compliance)
  - Infrastructure protection guards
  - Agent self-bypass prevention
  - PEN-test framework (50+ attack patterns)
  - EU AI Act compliance reports (PDF)
  - Priority support and updates

Pricing:
  EUR 20/dev/month
  EUR 5,000 one-time compliance kit

Usage:
  guardrail upgrade --key GR-PRO-XXXXXX-XXXXXX-XXXXXX-XXXXXX

Get your key: https://guardrail.promptandbuild.de
Contact:      frederik@frederikvonderheyden.de

EOF
    return
  fi

  local INSTALL_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}/hooks/guardrail"
  local PRO_DIR="$INSTALL_DIR/guards/pro"

  echo "GuardRail Pro Upgrade v$VERSION"
  echo "================================"
  echo ""
  echo "Validating license key..."

  local validate_response
  validate_response=$(curl -sf -X POST "$api_url/api/license/validate" \
    -H 'Content-Type: application/json' \
    -d "{\"key\":\"$license_key\"}" 2>&1)

  if [ $? -ne 0 ]; then
    echo "  ERROR: Could not reach license server."
    echo "  Check your internet connection and try again."
    echo ""
    echo "  If the problem persists: frederik@frederikvonderheyden.de"
    exit 1
  fi

  local valid
  valid=$(echo "$validate_response" | grep -o '"valid":true')

  if [ -z "$valid" ]; then
    local error
    error=$(echo "$validate_response" | grep -o '"error":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "  ERROR: ${error:-License key not valid}"
    exit 1
  fi

  echo "  License valid."
  echo ""
  echo "Downloading Pro guards..."

  local tmp_tar
  tmp_tar=$(mktemp /tmp/guardrail-pro-XXXXXX.tar.gz)

  local http_code
  http_code=$(curl -sf -o "$tmp_tar" -w '%{http_code}' \
    "$api_url/api/guards/download" \
    -H "Authorization: Bearer $license_key")

  if [ "$http_code" != "200" ] || [ ! -s "$tmp_tar" ]; then
    rm -f "$tmp_tar"
    echo "  ERROR: Download failed (HTTP $http_code)."
    echo "  Contact: frederik@frederikvonderheyden.de"
    exit 1
  fi

  echo "  Downloaded."
  echo ""
  echo "Installing Pro guards..."

  mkdir -p "$PRO_DIR"

  if ! tar -xzf "$tmp_tar" -C "$PRO_DIR" 2>/dev/null; then
    rm -f "$tmp_tar"
    echo "  ERROR: Failed to extract guards package."
    exit 1
  fi

  rm -f "$tmp_tar"

  local pro_count
  pro_count=$(find "$PRO_DIR" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

  # Save license key for future validations
  echo "$license_key" > "$INSTALL_DIR/.license-key"
  chmod 600 "$INSTALL_DIR/.license-key"

  echo "  $pro_count Pro guards installed to $PRO_DIR"
  echo ""
  echo "================================"
  echo "  GuardRail Pro is active."
  echo "  Pro guards load automatically on next command."
  echo ""
  echo "  Run 'guardrail status' to verify."
  echo "  Run 'guardrail pentest' to test all guards."
  echo "================================"
}

cmd_version() {
  echo "guardrail v$VERSION"
}

# Main dispatch
case "${1:-}" in
  init)     shift; cmd_init "$@" ;;
  test)     shift; cmd_test "$@" ;;
  pentest)  shift; cmd_pentest "$@" ;;
  status)   shift; cmd_status "$@" ;;
  audit)    shift; cmd_audit "$@" ;;
  new)      shift; cmd_new "$@" ;;
  upgrade)  shift; cmd_upgrade "$@" ;;
  version)  cmd_version ;;
  -v|--version) cmd_version ;;
  -h|--help|"") usage ;;
  *)
    echo "Unknown command: $1"
    echo "Run 'guardrail --help' for usage."
    exit 1
    ;;
esac
