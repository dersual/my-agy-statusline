#!/bin/bash
set -e

STATUSLINE_DEST="$HOME/.gemini/statusline.sh"
STATUSLINE_BACKUP="${STATUSLINE_DEST}.bak"
SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"

blue='\033[38;2;0;153;255m'
green='\033[38;2;0;175;80m'
yellow='\033[38;2;230;200;0m'
dim='\033[2m'
reset='\033[0m'

ok()   { echo -e "  ${green}✓${reset} $1"; }
warn() { echo -e "  ${yellow}!${reset} $1"; }

echo
echo -e "  ${blue}agy-statusline uninstaller${reset}"
echo -e "  ${dim}──────────────────────────${reset}"
echo

# Restore backup or remove
if [ -f "$STATUSLINE_BACKUP" ]; then
    cp "$STATUSLINE_BACKUP" "$STATUSLINE_DEST"
    rm "$STATUSLINE_BACKUP"
    ok "Restored previous statusline from backup"
elif [ -f "$STATUSLINE_DEST" ]; then
    rm "$STATUSLINE_DEST"
    ok "Removed ${dim}statusline.sh${reset}"
else
    warn "No statusline found — nothing to remove"
fi

# Clean settings.json
if [ -f "$SETTINGS_FILE" ]; then
    tmp=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    ok "Removed statusLine from ${dim}settings.json${reset}"
fi

echo
echo -e "  ${green}Done!${reset} Restart agy to apply changes."
echo