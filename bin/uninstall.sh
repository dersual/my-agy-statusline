#!/bin/bash
# Uninstaller script for macOS and Linux (Bash)
# Reverts settings.json statusLine configuration and removes installed files.
set -euo pipefail

GEMINI_DIR="$HOME/.gemini"
DEST_SCRIPT="$GEMINI_DIR/statusline.sh"
CONFIG_FILE="$GEMINI_DIR/statusline.json"
SETTINGS_FILE="$GEMINI_DIR/antigravity-cli/settings.json"

echo "Uninstalling Unified AGY Statusline..."

# 1. Update settings.json statusLine using jq
if [ -f "$SETTINGS_FILE" ]; then
    if command -v jq &>/dev/null; then
        temp_settings=$(mktemp)
        jq '.statusLine = {type: "", command: "", enabled: false}' "$SETTINGS_FILE" > "$temp_settings"
        mv "$temp_settings" "$SETTINGS_FILE"
        echo "Reverted settings.json statusLine configuration."
    else
        echo "Warning: jq is not installed. Could not update settings.json automatically."
    fi
fi

# 2. Remove script file
if [ -f "$DEST_SCRIPT" ]; then
    rm "$DEST_SCRIPT"
    echo "Removed script file: $DEST_SCRIPT"
fi

# 3. Inform user about configuration file
if [ -f "$CONFIG_FILE" ]; then
    echo "Note: Configuration file left at $CONFIG_FILE to preserve your settings."
fi

echo "Uninstall complete!"
