#!/bin/bash
# Adversarial installer and rollback tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT=$(mktemp -d /tmp/guardrail-installer-adversarial.XXXXXX)
trap 'rm -rf "$TMP_ROOT"' EXIT
PASS=0

ok() {
  PASS=$((PASS + 1))
}

# A corrupt settings file must fail and restore the prior installation exactly.
CLAUDE_DIR="$TMP_ROOT/corrupt-settings"
mkdir -p "$CLAUDE_DIR/hooks/guardrail"
printf '%s\n' 'previous-installation' > "$CLAUDE_DIR/hooks/guardrail/sentinel"
printf '%s\n' '{not-json' > "$CLAUDE_DIR/settings.json"
if GUARDRAIL_CLAUDE_DIR="$CLAUDE_DIR" bash "$ROOT/install.sh" >/dev/null 2>&1; then
  echo "FAIL: installer accepted corrupt settings.json"
  exit 1
fi
grep -qx 'previous-installation' "$CLAUDE_DIR/hooks/guardrail/sentinel"
grep -qx '{not-json' "$CLAUDE_DIR/settings.json"
ok

# Missing mandatory source guards must fail before an existing install changes.
BROKEN_SOURCE="$TMP_ROOT/broken-source"
cp -a "$ROOT/." "$BROKEN_SOURCE/"
rm -f "$BROKEN_SOURCE/guards/core/basic_pii_gate.sh"
CLAUDE_DIR="$TMP_ROOT/missing-guard"
mkdir -p "$CLAUDE_DIR/hooks/guardrail"
printf '%s\n' 'previous-installation' > "$CLAUDE_DIR/hooks/guardrail/sentinel"
printf '%s\n' '{}' > "$CLAUDE_DIR/settings.json"
if GUARDRAIL_CLAUDE_DIR="$CLAUDE_DIR" bash "$BROKEN_SOURCE/install.sh" >/dev/null 2>&1; then
  echo "FAIL: installer accepted a missing mandatory guard"
  exit 1
fi
grep -qx 'previous-installation' "$CLAUDE_DIR/hooks/guardrail/sentinel"
ok

# A successful install must register all hooks and prove both deny and allow.
CLAUDE_DIR="$TMP_ROOT/success"
mkdir -p "$CLAUDE_DIR"
printf '%s\n' '{}' > "$CLAUDE_DIR/settings.json"
GUARDRAIL_CLAUDE_DIR="$CLAUDE_DIR" bash "$ROOT/install.sh" >/dev/null
PRE_BASH="$CLAUDE_DIR/hooks/guardrail/dispatchers/pre-bash.sh"
jq -e --arg command "$PRE_BASH" \
  '.hooks.PreToolUse[]?.hooks[]? | select(.command == $command)' \
  "$CLAUDE_DIR/settings.json" >/dev/null
dangerous=$(printf '%s' '{"session_id":"installer-test","tool_input":{"command":"git push origin main"}}' |
  bash "$PRE_BASH" | jq -r '.hookSpecificOutput.permissionDecision')
safe=$(printf '%s' '{"session_id":"installer-test","tool_input":{"command":"npm test"}}' |
  bash "$PRE_BASH" | jq -r '.hookSpecificOutput.permissionDecision')
test "$dangerous" = "deny"
test "$safe" = "allow"
ok

printf 'Adversarial installer suite: passed=%s failed=0 total=%s\n' "$PASS" "$PASS"
