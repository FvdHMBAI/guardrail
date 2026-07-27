#!/bin/bash
# GuardRail CLI
# Pre-execution security guards for AI coding agents.
# License: MIT

set -euo pipefail

VERSION="0.2.4"
REAL_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")/.." && pwd)"

# Colors
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  R=$'\033[0;31m' G=$'\033[0;32m' Y=$'\033[0;33m' B=$'\033[1m' D=$'\033[2m' Z=$'\033[0m'
else
  R="" G="" Y="" B="" D="" Z=""
fi

usage() {
  cat << EOF
GuardRail v$VERSION - Pre-execution security guards for AI coding agents

Usage: guardrail <command> [options]

Commands:
  init                Install GuardRail into Claude Code
  test                Run regression tests
  pentest             Run security PEN-test against all guards
  status              Show active guards and recent activity
  audit               Generate audit report
  compliance-report   Generate EU AI Act compliance report (Pro)
  new                 Create a new guard from template
  upgrade             Learn about GuardRail Pro
  version             Show version

Options:
  -h, --help    Show this help message
  -v, --version Show version

Examples:
  npx guardrail-agent init    Install guards
  guardrail test                          Run all tests
  guardrail status                        Check guard status
  guardrail audit --days 30               Audit report for last 30 days
  guardrail compliance-report             EU AI Act compliance report (Pro)
  guardrail compliance-report --format md --output report.md

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
  local CLAUDE_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}"
  local INSTALL_DIR="$CLAUDE_DIR/hooks/guardrail"
  local SETTINGS_FILE="$CLAUDE_DIR/settings.json"
  local PRE_BASH="$INSTALL_DIR/dispatchers/pre-bash.sh"

  echo ""
  echo "  ${B}GuardRail${Z} ${D}v$VERSION${Z}"
  echo ""

  if [ -d "$INSTALL_DIR/guards/core" ]; then
    local core_count
    core_count=$(find "$INSTALL_DIR/guards/core" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ${G}$core_count${Z} core guards active"
  else
    echo "  ${R}0${Z} core guards ${D}(run guardrail init)${Z}"
  fi

  if [ -x "$PRE_BASH" ] && [ -f "$SETTINGS_FILE" ] \
    && jq -e --arg command "$PRE_BASH" \
      '.hooks.PreToolUse[]?.hooks[]? | select(.command == $command)' \
      "$SETTINGS_FILE" >/dev/null 2>&1 \
    && [ "$(printf '%s' '{"session_id":"status-check","tool_input":{"command":"git push origin main"}}' |
      bash "$PRE_BASH" | jq -r '.hookSpecificOutput.permissionDecision // "missing"')" = "deny" ]; then
    echo "  ${G}Enforcement verified${Z} (registered hook and deny probe)"
  else
    echo "  ${R}Enforcement not verified${Z} (run guardrail init)"
  fi

  if [ -d "$INSTALL_DIR/guards/pro" ]; then
    local pro_count
    pro_count=$(find "$INSTALL_DIR/guards/pro" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    [ "$pro_count" -gt 0 ] && echo "  ${G}$pro_count${Z} pro guards active" || echo "  ${D}0${Z} pro guards"
  else
    echo "  ${D}0${Z} pro guards ${D}(guardrail upgrade --key ...)${Z}"
  fi

  if [ -d "$INSTALL_DIR/guards/custom" ]; then
    local custom_count
    custom_count=$(find "$INSTALL_DIR/guards/custom" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    [ "$custom_count" -gt 0 ] && echo "  ${G}$custom_count${Z} custom guards"
  fi

  echo ""

  local AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-$HOME/.guardrail/audit.log}"
  if [ -f "$AUDIT_LOG" ]; then
    local total blocked
    total=$(wc -l < "$AUDIT_LOG" | tr -d ' ')
    blocked=$(grep -c "blocked" "$AUDIT_LOG" 2>/dev/null || echo 0)
    echo "  ${D}Audit:${Z} ${B}$blocked${Z} blocked / $total total"
    echo ""
    echo "  ${D}Recent:${Z}"
    tail -5 "$AUDIT_LOG" 2>/dev/null | while IFS= read -r line; do
      if echo "$line" | grep -q "blocked"; then
        echo "  ${R}x${Z} $line"
      else
        echo "  ${G}+${Z} $line"
      fi
    done
  else
    echo "  ${D}No audit events yet.${Z}"
  fi
  echo ""
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
Learn more: https://guardrail.promptandbuild.de

COMPEOF
        return ;;
      *) shift ;;
    esac
  done

  local AUDIT_LOG="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"

  echo "GuardRail Audit Report"
  echo "======================"
  echo "Period: last $days days"
  echo "Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
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
Learn more: https://guardrail.promptandbuild.de

PROEOF
    return
  fi

  local INSTALL_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}/hooks/guardrail"
  local GUARDS_DIR="$INSTALL_DIR/guards/core"
  local LIB_DIR="$INSTALL_DIR/lib"
  local P=0 F=0

  echo ""
  echo "  ${B}GuardRail PEN-Test${Z} ${D}v$VERSION${Z}"
  echo ""

  # Phase 1: Syntax check
  echo "  ${D}Phase 1: Syntax${Z}"
  if [ ! -d "$GUARDS_DIR" ]; then
    echo "  ${R}ERROR${Z} Guards not installed. Run ${B}guardrail init${Z} first."
    exit 1
  fi
  for g in "$GUARDS_DIR"/*.sh; do
    [ -f "$g" ] || continue
    if bash -n "$g" 2>/dev/null; then
      P=$((P+1))
    else
      F=$((F+1)); echo "  ${R}x${Z} $(basename "$g") syntax error"
    fi
  done
  echo "  ${G}+${Z} $P guards passed syntax check"
  echo ""

  # Phase 2: Dispatcher check
  echo "  ${D}Phase 2: Dispatchers${Z}"
  for d in "$INSTALL_DIR/dispatchers"/*.sh; do
    [ -f "$d" ] || continue
    if bash -n "$d" 2>/dev/null; then
      P=$((P+1)); echo "  ${G}+${Z} $(basename "$d")"
    else
      F=$((F+1)); echo "  ${R}x${Z} $(basename "$d") syntax error"
    fi
  done
  echo ""

  # Phase 3: Guard simulation
  echo "  ${D}Phase 3: Attack Simulation${Z}"

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
      P=$((P+1)); echo "  ${R}x BLOCKED${Z} $desc"
    elif [ "$expect" = "PASS" ] && [ "$result" != "DENY" ]; then
      P=$((P+1)); echo "  ${G}+ ALLOWED${Z} ${D}$desc${Z}"
    else
      F=$((F+1)); echo "  ${Y}! FAIL${Z}   $desc ${D}(expected $expect, got $result)${Z}"
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
  if [ "$F" -gt 0 ]; then
    echo "  ${R}${B}$F FAILED${Z}  ${G}$P passed${Z}"
    echo ""
    echo "  Some security gates failed. Review the output above."
    exit 1
  fi
  echo "  ${G}${B}All $P tests passed.${Z}"
  echo ""
  echo "  ${D}Advanced PEN-testing (50+ attack patterns): guardrail pentest --pro${Z}"
  echo ""
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
  - 48+ advanced guards from real production incidents
  - PII Shield: scans agent outputs for personal data (10 EU countries)
  - Audit Trail: structured JSONL logging of all agent actions
  - Compliance Reporter: EU AI Act article mapping and reports
  - Multi-step attack detection
  - Script content analysis and injection prevention
  - Agent self-bypass prevention
  - PEN-test framework (50+ attack patterns)
  - Priority support and updates

Pricing:
  EUR 29/dev/month
  EUR 4,900 one-time compliance kit

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

cmd_compliance_report() {
  local from_date="" to_date="" format="md" output_file=""
  local audit_dir="${GUARDRAIL_AUDIT_DIR:-$HOME/.guardrail/audit}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --from) from_date="$2"; shift 2 ;;
      --to) to_date="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --output|-o) output_file="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$to_date" ] && to_date=$(date +%Y-%m-%d)
  [ -z "$from_date" ] && from_date=$(date -d "-30 days" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null || echo "2026-01-01")

  source "$SCRIPT_DIR/lib/guardrail-license.sh" 2>/dev/null
  if ! _guardrail_check_pro_license 2>/dev/null; then
    echo ""
    echo "  ${B}GuardRail Compliance Report${Z} requires a Pro license."
    echo ""
    echo "  Includes EU AI Act article mapping, compliance scoring,"
    echo "  incident documentation, and exportable reports."
    echo ""
    echo "  Get Pro: ${B}https://guardrail.promptandbuild.de${Z}"
    echo ""
    return
  fi

  source "$SCRIPT_DIR/lib/eu-ai-act-mapping.sh" 2>/dev/null

  if [ ! -d "$audit_dir" ]; then
    echo "No audit data found at $audit_dir"
    echo "Audit Trail guard must be active to generate compliance reports."
    return 1
  fi

  local total_events=0 total_blocked=0 total_warned=0 total_allowed=0
  local -A guard_counts guard_blocked

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local ts guard decision
    ts=$(echo "$line" | jq -r '.timestamp // ""' 2>/dev/null)
    [ -z "$ts" ] && continue
    local event_date="${ts:0:10}"
    [[ "$event_date" < "$from_date" ]] && continue
    [[ "$event_date" > "$to_date" ]] && continue

    guard=$(echo "$line" | jq -r '.guard // "unknown"' 2>/dev/null)
    decision=$(echo "$line" | jq -r '.decision // "allow"' 2>/dev/null)

    total_events=$((total_events + 1))
    guard_counts[$guard]=$(( ${guard_counts[$guard]:-0} + 1 ))

    case "$decision" in
      blocked|deny) total_blocked=$((total_blocked + 1)); guard_blocked[$guard]=$(( ${guard_blocked[$guard]:-0} + 1 )) ;;
      warned|warn) total_warned=$((total_warned + 1)) ;;
      *) total_allowed=$((total_allowed + 1)) ;;
    esac
  done < <(cat "$audit_dir"/audit-*.jsonl 2>/dev/null)

  local guard_text_log="${GUARDRAIL_AUDIT_LOG:-./guardrail-audit.log}"
  if [ -f "$guard_text_log" ] && [ "$total_events" -eq 0 ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local event_date
      event_date=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
      [ -z "$event_date" ] && continue
      [[ "$event_date" < "$from_date" ]] && continue
      [[ "$event_date" > "$to_date" ]] && continue
      total_events=$((total_events + 1))
      if echo "$line" | grep -q "blocked"; then
        total_blocked=$((total_blocked + 1))
      else
        total_allowed=$((total_allowed + 1))
      fi
    done < "$guard_text_log"
  fi

  local active_guards=0
  for gdir in "$SCRIPT_DIR/guards/core" "$SCRIPT_DIR/guards/pro" "$SCRIPT_DIR/guards/custom"; do
    [ -d "$gdir" ] && active_guards=$((active_guards + $(find "$gdir" -name "*.sh" 2>/dev/null | wc -l)))
  done

  local coverage_score=0
  local articles_covered=0
  local articles_total=5
  local -A seen_articles
  for guard in "${!EU_AI_ACT_MAPPING[@]}"; do
    local article
    article=$(_guardrail_get_article "$guard")
    [ "$article" = "Unmapped" ] && continue
    local art_words=($article)
    local art_key="${art_words[0]} ${art_words[1]}"
    if [ -z "${seen_articles[$art_key]:-}" ]; then
      seen_articles[$art_key]=1
      articles_covered=$((articles_covered + 1))
    fi
  done
  [ "$articles_total" -gt 0 ] && coverage_score=$((articles_covered * 100 / articles_total))

  _emit() {
    if [ -n "$output_file" ]; then
      echo "$1" >> "$output_file"
    else
      echo "$1"
    fi
  }

  [ -n "$output_file" ] && > "$output_file"

  _emit "# GuardRail EU AI Act Compliance Report"
  _emit ""
  _emit "**Generated:** $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  _emit "**Period:** $from_date to $to_date"
  _emit "**GuardRail Version:** $VERSION"
  _emit ""
  _emit "---"
  _emit ""
  _emit "## 1. Executive Summary"
  _emit ""
  _emit "| Metric | Value |"
  _emit "|--------|-------|"
  _emit "| Active Guards | $active_guards |"
  _emit "| Total Events | $total_events |"
  _emit "| Threats Blocked | $total_blocked |"
  _emit "| Warnings Issued | $total_warned |"
  _emit "| EU AI Act Coverage | ${coverage_score}% ($articles_covered/$articles_total articles) |"
  _emit ""
  _emit "## 2. EU AI Act Article Mapping"
  _emit ""
  _emit "| Article | Title | Guards | Status |"
  _emit "|---------|-------|--------|--------|"

  for art_key in "Art. 9" "Art. 10" "Art. 12" "Art. 14" "Art. 15"; do
    local art_info="${EU_AI_ACT_ARTICLES[$art_key]:-}"
    local art_title art_desc
    art_title=$(echo "$art_info" | cut -d'|' -f1)
    local matching_guards=""
    local guard_count=0
    for guard in "${!EU_AI_ACT_MAPPING[@]}"; do
      local g_article
      g_article=$(_guardrail_get_article "$guard")
      if [[ "$g_article" == "$art_key"* ]]; then
        [ -n "$matching_guards" ] && matching_guards="$matching_guards, "
        matching_guards="$matching_guards$guard"
        guard_count=$((guard_count + 1))
      fi
    done
    local status_icon
    if [ "$guard_count" -gt 0 ]; then
      status_icon="COVERED"
    else
      status_icon="GAP"
    fi
    _emit "| $art_key | $art_title | ${matching_guards:-none} | $status_icon |"
  done

  _emit ""
  _emit "## 3. Guard Activity"
  _emit ""

  if [ ${#guard_counts[@]} -gt 0 ]; then
    _emit "| Guard | Events | Blocked | Compliance Role |"
    _emit "|-------|--------|---------|-----------------|"
    for guard in "${!guard_counts[@]}"; do
      local article
      article=$(_guardrail_get_article "$guard")
      _emit "| $guard | ${guard_counts[$guard]} | ${guard_blocked[$guard]:-0} | $article |"
    done
  else
    _emit "No structured audit events in this period. Ensure the Audit Trail guard is active."
  fi

  _emit ""
  _emit "## 4. Incidents (Blocked Threats)"
  _emit ""

  local incident_count=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local ts guard decision cmd_val
    ts=$(echo "$line" | jq -r '.timestamp // ""' 2>/dev/null)
    [ -z "$ts" ] && continue
    local event_date="${ts:0:10}"
    [[ "$event_date" < "$from_date" ]] && continue
    [[ "$event_date" > "$to_date" ]] && continue
    decision=$(echo "$line" | jq -r '.decision // ""' 2>/dev/null)
    [ "$decision" != "blocked" ] && [ "$decision" != "deny" ] && continue
    guard=$(echo "$line" | jq -r '.guard // "unknown"' 2>/dev/null)
    cmd_val=$(echo "$line" | jq -r '.command // ""' 2>/dev/null | head -c 80)
    incident_count=$((incident_count + 1))
    [ "$incident_count" -le 20 ] && _emit "- **$ts** [$guard] Blocked: \`$cmd_val\`"
  done < <(cat "$audit_dir"/audit-*.jsonl 2>/dev/null)

  [ "$incident_count" -eq 0 ] && _emit "No blocked threats in this period."
  [ "$incident_count" -gt 20 ] && _emit "- ... and $((incident_count - 20)) more"

  _emit ""
  _emit "## 5. Recommendations"
  _emit ""

  local has_recs=0
  if [ "$active_guards" -lt 20 ]; then
    _emit "- **Increase guard coverage:** Only $active_guards guards active. Consider enabling Pro guards for comprehensive protection."
    has_recs=1
  fi
  if [ "$coverage_score" -lt 100 ]; then
    _emit "- **EU AI Act gaps:** $((articles_total - articles_covered)) articles not fully covered. Review guard configuration."
    has_recs=1
  fi
  if [ "$total_events" -eq 0 ]; then
    _emit "- **Enable Audit Trail:** No audit events recorded. Activate the audit trail guard for compliance evidence."
    has_recs=1
  fi
  [ "$has_recs" -eq 0 ] && _emit "No recommendations. Guard coverage and audit trail are comprehensive."

  _emit ""
  _emit "---"
  _emit ""
  _emit "*This report was generated by GuardRail v$VERSION. It documents AI agent governance*"
  _emit "*measures and their mapping to EU AI Act requirements. This report supports but does*"
  _emit "*not replace a formal compliance assessment by qualified professionals.*"

  if [ -n "$output_file" ]; then
    echo ""
    echo "  ${G}Report saved to:${Z} $output_file"
    echo ""
  fi
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
  compliance-report) shift; cmd_compliance_report "$@" ;;
  version)  cmd_version ;;
  -v|--version) cmd_version ;;
  -h|--help|"") usage ;;
  *)
    echo "Unknown command: $1"
    echo "Run 'guardrail --help' for usage."
    exit 1
    ;;
esac
