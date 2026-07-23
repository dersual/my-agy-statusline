#!/bin/bash
# Installer script for macOS and Linux (Bash)
# Copies statusline.sh to ~/.gemini/ and updates settings.json statusLine command.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEMINI_DIR="$HOME/.gemini"
DEST_SCRIPT="$GEMINI_DIR/statusline.sh"
CONFIG_FILE="$GEMINI_DIR/statusline.json"
SETTINGS_FILE="$GEMINI_DIR/antigravity-cli/settings.json"

echo "Installing Unified AGY Statusline..."

# Precondition check: verify jq is installed since it is required by both the installer and statusline script
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is not installed. It is required to install and run the Unified AGY Statusline."
    echo "Please install jq using your package manager (e.g., 'brew install jq' on macOS or 'sudo apt install jq' on Debian/Ubuntu) and try again."
    exit 1
fi

# 1. Create .gemini directory if it doesn't exist
mkdir -p "$GEMINI_DIR"
echo "Ensured directory exists: $GEMINI_DIR"

# 2. Copy the script and make it executable
cp "$SCRIPT_DIR/statusline.sh" "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"
echo "Copied statusline.sh to: $DEST_SCRIPT"

# 3. Create default configuration if not present
if [ ! -f "$CONFIG_FILE" ]; then
    cat <<EOF > "$CONFIG_FILE"
{
  "show_quota": true,
  "show_additional_stats": true,
  "hide_zero_stats": true,
  "show_state_indicator": true
}
EOF
    echo "Created default configuration at: $CONFIG_FILE"
else
    echo "Configuration file already exists at $CONFIG_FILE (skipping override)."
fi

# 4. Update settings.json
MANUAL_SNIPPET="{\n  \"statusLine\": {\n    \"type\": \"command\",\n    \"command\": \"$DEST_SCRIPT\",\n    \"enabled\": true\n  }\n}"

if [ -f "$SETTINGS_FILE" ]; then
    if command -v jq &>/dev/null; then
        # Create temp file to avoid clobbering during stream read
        temp_settings=$(mktemp)
        if jq --arg cmd "$DEST_SCRIPT" '.statusLine = {type: "command", command: $cmd, enabled: true}' "$SETTINGS_FILE" > "$temp_settings"; then
            mv "$temp_settings" "$SETTINGS_FILE"
            echo "Successfully updated settings.json statusLine configuration!"
        else
            rm -f "$temp_settings"
            echo "Warning: Failed to update $SETTINGS_FILE with jq."
            echo "Please manually add the following configuration to $SETTINGS_FILE:"
            echo -e "$MANUAL_SNIPPET"
        fi
    else
        echo "Warning: jq is not installed. Could not update settings.json automatically."
        echo "Please manually add the following configuration to $SETTINGS_FILE:"
        echo -e "$MANUAL_SNIPPET"
    fi
else
    echo "Warning: settings.json not found at $SETTINGS_FILE. Please configure agy statusline manually."
    echo "Please manually add the following configuration to $SETTINGS_FILE:"
    echo -e "$MANUAL_SNIPPET"
fi
