#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/../bin/statusline.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

# Back up user config if it exists
CONFIG_PATH="$HOME/.gemini/statusline.json"
CONFIG_BACKUP="$CONFIG_PATH.bak"
HAS_BACKUP=false

if [ -f "$CONFIG_PATH" ]; then
    cp "$CONFIG_PATH" "$CONFIG_BACKUP"
    HAS_BACKUP=true
fi

cleanup() {
    if [ "$HAS_BACKUP" = true ]; then
        mv "$CONFIG_BACKUP" "$CONFIG_PATH"
    elif [ -f "$CONFIG_PATH" ]; then
        rm "$CONFIG_PATH"
    fi
}
trap cleanup EXIT

run_test() {
    local fixture_name=$1
    local show_quota=$2
    local show_additional_stats=$3
    local hide_zero_stats=$4
    local show_state_indicator=$5

    echo -e "\n\033[36m[TEST] $fixture_name | Config: show_quota=$show_quota, show_additional_stats=$show_additional_stats, hide_zero_stats=$hide_zero_stats, show_state_indicator=$show_state_indicator\033[0m"

    mkdir -p "$(dirname "$CONFIG_PATH")"
    cat <<EOF > "$CONFIG_PATH"
{
  "show_quota": $show_quota,
  "show_additional_stats": $show_additional_stats,
  "hide_zero_stats": $hide_zero_stats,
  "show_state_indicator": $show_state_indicator
}
EOF

    local fixture_path="$FIXTURES_DIR/$fixture_name.json"
    if [ ! -f "$fixture_path" ]; then
        echo "Fixture not found: $fixture_path"
        exit 1
    fi

    cat "$fixture_path" | bash "$SCRIPT_PATH"
}

# Test Case 1: Default Config
run_test "idle" true true true true
run_test "active_working" true true true true
run_test "claude_quota" true true true true
run_test "gemini_quota" true true true true

# Test Case 2: Show all zero stats
run_test "idle" true true false true

# Test Case 3: Disable quota
run_test "claude_quota" false true true true

# Test Case 4: Disable additional stats
run_test "active_working" true false true true

# Test Case 5: Disable state indicator
run_test "active_working" true true true false

echo -e "\n\033[32m[SUCCESS] All statusline.sh tests completed!\033[0m"
