#!/bin/bash
# Verifies that the npm tarball (what `npx guardrail-agent init` downloads)
# installs and activates GuardRail in a clean HOME.
#
# Background: from v0.3.0 to v0.4.6 the regression suite shipped inside the
# tarball required guards/premium/, which package.json "files" excludes. The
# installer ran the suite, it failed, and install.sh rolled GuardRail back.
# Every npm user got "Regression tests failed" and no active guards.
# This test runs on the packed tarball, not on the checkout, so it catches
# anything the published package cannot satisfy.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d /tmp/guardrail-npm-pack.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
P=0; F=0
ok() { P=$((P+1)); }
fail() { F=$((F+1)); echo "  FAIL: $1"; }

echo "=== GuardRail npm tarball install test ==="

TARBALL=$(cd "$TMP" && npm pack "$ROOT" --pack-destination "$TMP" 2>/dev/null | tail -1)
if [ -n "$TARBALL" ] && [ -f "$TMP/$TARBALL" ]; then ok; else fail "npm pack produced no tarball"; echo "=== Results: Passed=$P Failed=$F ==="; exit 1; fi

mkdir -p "$TMP/pkg" "$TMP/home/.claude"
tar -xzf "$TMP/$TARBALL" -C "$TMP/pkg" --strip-components=1

# 1. The free package must not ship premium guards.
if [ ! -d "$TMP/pkg/guards/premium" ]; then ok; else fail "tarball contains guards/premium"; fi

# 2. install.sh from the tarball must succeed in a clean HOME.
if HOME="$TMP/home" \
   GUARDRAIL_CLAUDE_DIR="$TMP/home/.claude" \
   GUARDRAIL_LOG_DIR="$TMP/home/.guardrail/logs" \
   GUARDRAIL_AUDIT_LOG="$TMP/home/.guardrail/audit.log" \
   bash "$TMP/pkg/install.sh" >"$TMP/install.log" 2>&1; then
  ok
else
  fail "install.sh from tarball failed"
  sed 's/^/    /' "$TMP/install.log" | tail -8
fi

# 3. The dispatcher must exist and be registered in settings.json.
D="$TMP/home/.claude/hooks/guardrail/dispatchers/pre-bash.sh"
if [ -f "$D" ]; then ok; else fail "dispatcher missing after install"; fi
if jq -e --arg c "$D" '.hooks | to_entries | any(.value[]?.hooks[]?.command == $c)' \
     "$TMP/home/.claude/settings.json" >/dev/null 2>&1; then
  ok
else
  fail "settings.json does not register the pre-bash dispatcher"
fi

# 4. The installed dispatcher must deny a push to a protected branch.
DECISION=$(printf '%s' '{"session_id":"npm-pack","tool_input":{"command":"git push origin main"}}' \
  | HOME="$TMP/home" bash "$D" 2>/dev/null \
  | jq -r '.hookSpecificOutput.permissionDecision // "missing"')
if [ "$DECISION" = "deny" ]; then ok; else fail "installed dispatcher did not deny the protected push (got: $DECISION)"; fi

echo "=== Results: Passed=$P Failed=$F ==="
[ "$F" -eq 0 ]
