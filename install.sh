#!/bin/bash
# GuardRail Installer
# Installs guards and hooks into Claude Code settings.
# License: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
INSTALL_DIR="$CLAUDE_DIR/hooks/guardrail"

# Colors
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  R=$'\033[0;31m' G=$'\033[0;32m' Y=$'\033[0;33m' B=$'\033[1m' D=$'\033[2m' Z=$'\033[0m'
else
  R="" G="" Y="" B="" D="" Z=""
fi

echo ""
echo "${B}  GuardRail${Z} ${D}v0.2.3${Z}"
echo "${D}  Pre-execution security for AI coding agents${Z}"
echo ""

# Check prerequisites
if ! command -v jq >/dev/null 2>&1; then
  echo "  ${R}ERROR${Z} jq is required but not installed."
  echo "    macOS: ${B}brew install jq${Z}"
  echo "    Linux: ${B}sudo apt install jq${Z}"
  exit 1
fi

if [ ! -d "$CLAUDE_DIR" ]; then
  echo "  ${R}ERROR${Z} Claude Code config directory not found at $CLAUDE_DIR"
  echo "    Make sure Claude Code is installed first."
  exit 1
fi

# Create installation directory
mkdir -p "$INSTALL_DIR/guards/core"
mkdir -p "$INSTALL_DIR/guards/custom"
mkdir -p "$INSTALL_DIR/dispatchers"
mkdir -p "$INSTALL_DIR/lib"

# Copy ONLY the 10 Core guards (not Premium guards that may exist locally)
CORE_GUARDS="main_push_guard basic_pii_gate basic_secret_detector destructive_path_guard firewall_flush_guard service_protection_guard mass_update_guard env_dump_detector basic_injection_scanner error_swallow_guard"
for guard in $CORE_GUARDS; do
  [ -f "$SCRIPT_DIR/guards/core/${guard}.sh" ] && cp "$SCRIPT_DIR/guards/core/${guard}.sh" "$INSTALL_DIR/guards/core/"
done
cp -r "$SCRIPT_DIR/dispatchers/"*.sh "$INSTALL_DIR/dispatchers/"
cp -r "$SCRIPT_DIR/lib/"*.sh "$INSTALL_DIR/lib/"
cp "$SCRIPT_DIR/guardrail.config.sh" "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/dispatchers/"*.sh
chmod +x "$INSTALL_DIR/guards/core/"*.sh 2>/dev/null || true

GUARD_COUNT=$(find "$INSTALL_DIR/guards/core" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

echo "  ${G}+${Z} Installed ${B}$GUARD_COUNT${Z} core guards"

# Update Claude Code settings
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

PRE_BASH="$INSTALL_DIR/dispatchers/pre-bash.sh"
POST_BASH="$INSTALL_DIR/dispatchers/post-bash.sh"
POST_EDIT="$INSTALL_DIR/dispatchers/post-edit.sh"

TEMP_SETTINGS=$(mktemp)
jq --arg pre "$PRE_BASH" --arg post "$POST_BASH" --arg edit "$POST_EDIT" '
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  .hooks.PostToolUse //= [] |
  (if (.hooks.PreToolUse | map(select(.command == $pre)) | length) == 0
   then .hooks.PreToolUse += [{"matcher": "Bash", "command": $pre}]
   else . end) |
  (if (.hooks.PostToolUse | map(select(.command == $post)) | length) == 0
   then .hooks.PostToolUse += [{"matcher": "Bash", "command": $post}]
   else . end) |
  (if (.hooks.PostToolUse | map(select(.command == $edit)) | length) == 0
   then .hooks.PostToolUse += [{"matcher": "Write|Edit", "command": $edit}]
   else . end)
' "$SETTINGS_FILE" > "$TEMP_SETTINGS"

if [ -s "$TEMP_SETTINGS" ]; then
  mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
  echo "  ${G}+${Z} Configured Claude Code hooks"
else
  rm -f "$TEMP_SETTINGS"
  echo "  ${Y}!${Z} Could not update settings.json. Add hooks manually."
fi

# Run regression tests quietly
if [ -f "$SCRIPT_DIR/tests/regression.sh" ]; then
  if bash "$SCRIPT_DIR/tests/regression.sh" > /dev/null 2>&1; then
    echo "  ${G}+${Z} All regression tests passed"
  else
    echo "  ${Y}!${Z} Some tests failed. Run ${B}guardrail test${Z} for details."
  fi
fi

echo ""
echo "  ${G}GuardRail is active.${Z} Every command is now guarded."
echo ""
echo "  ${D}Try it:${Z}  ${B}guardrail status${Z}"
echo "  ${D}Config:${Z} $INSTALL_DIR/guardrail.config.sh"
echo ""
