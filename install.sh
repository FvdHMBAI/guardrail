#!/bin/bash
# GuardRail Installer
# Installs guards and hooks into Claude Code settings.
# License: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${GUARDRAIL_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
INSTALL_DIR="$CLAUDE_DIR/hooks/guardrail"

echo "GuardRail Installer v0.1.0"
echo "========================="
echo ""

# Check prerequisites
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed."
  echo "  macOS: brew install jq"
  echo "  Linux: sudo apt install jq"
  exit 1
fi

if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: Claude Code config directory not found at $CLAUDE_DIR"
  echo "  Make sure Claude Code is installed first."
  exit 1
fi

# Create installation directory
echo "Installing guards to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR/guards/core"
mkdir -p "$INSTALL_DIR/guards/custom"
mkdir -p "$INSTALL_DIR/dispatchers"
mkdir -p "$INSTALL_DIR/lib"

# Copy files
cp -r "$SCRIPT_DIR/guards/core/"*.sh "$INSTALL_DIR/guards/core/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/dispatchers/"*.sh "$INSTALL_DIR/dispatchers/"
cp -r "$SCRIPT_DIR/lib/"*.sh "$INSTALL_DIR/lib/"
cp "$SCRIPT_DIR/guardrail.config.sh" "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/dispatchers/"*.sh
chmod +x "$INSTALL_DIR/guards/core/"*.sh 2>/dev/null || true

GUARD_COUNT=$(find "$INSTALL_DIR/guards/core" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

# Update Claude Code settings
echo "Configuring Claude Code hooks ..."

if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Build hook entries
PRE_BASH="$INSTALL_DIR/dispatchers/pre-bash.sh"
POST_BASH="$INSTALL_DIR/dispatchers/post-bash.sh"
POST_EDIT="$INSTALL_DIR/dispatchers/post-edit.sh"

# Use jq to add hooks without overwriting existing ones
TEMP_SETTINGS=$(mktemp)
jq --arg pre "$PRE_BASH" --arg post "$POST_BASH" --arg edit "$POST_EDIT" '
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  .hooks.PostToolUse //= [] |

  # Add pre-bash dispatcher if not already present
  (if (.hooks.PreToolUse | map(select(.command == $pre)) | length) == 0
   then .hooks.PreToolUse += [{"matcher": "Bash", "command": $pre}]
   else . end) |

  # Add post-bash dispatcher if not already present
  (if (.hooks.PostToolUse | map(select(.command == $post)) | length) == 0
   then .hooks.PostToolUse += [{"matcher": "Bash", "command": $post}]
   else . end) |

  # Add post-edit dispatcher if not already present
  (if (.hooks.PostToolUse | map(select(.command == $edit)) | length) == 0
   then .hooks.PostToolUse += [{"matcher": "Write|Edit", "command": $edit}]
   else . end)
' "$SETTINGS_FILE" > "$TEMP_SETTINGS"

if [ -s "$TEMP_SETTINGS" ]; then
  mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
else
  rm -f "$TEMP_SETTINGS"
  echo "WARNING: Could not update settings.json. Add hooks manually."
fi

# Run regression tests
echo ""
echo "Running regression tests ..."
if [ -f "$SCRIPT_DIR/tests/regression.sh" ]; then
  if bash "$SCRIPT_DIR/tests/regression.sh"; then
    echo ""
    echo "All tests passed."
  else
    echo ""
    echo "WARNING: Some tests failed. Check the output above."
  fi
else
  echo "No regression tests found."
fi

echo ""
echo "========================="
echo "GuardRail installed successfully!"
echo "  $GUARD_COUNT core guards active"
echo "  Config: $INSTALL_DIR/guardrail.config.sh"
echo "  Audit log: $(grep GUARDRAIL_AUDIT_LOG "$INSTALL_DIR/guardrail.config.sh" | head -1 | grep -oP ':-[^}]+' | sed 's/^:-//')"
echo ""
echo "Next steps:"
echo "  1. Customize $INSTALL_DIR/guardrail.config.sh"
echo "  2. Add custom guards to $INSTALL_DIR/guards/custom/"
echo "  3. Run 'guardrail test' to verify"
echo "  4. Run 'guardrail status' to check active guards"
