#!/usr/bin/env bash
set -euo pipefail

# Project root resolution
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "--- Formatting Bash scripts (shfmt) ---"
THIS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

files=()
while IFS= read -r -d '' file; do
    abs_path="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    if [ "$abs_path" != "$THIS_SCRIPT" ]; then
        files+=("$file")
    fi
done < <(find bin tasks tests -name "*.sh" -print0 2>/dev/null)

if [ ${#files[@]} -eq 0 ]; then
    echo "No .sh files found to format."
    exit 0
fi

shfmt -w -i 4 -ci "${files[@]}"

echo "✓ Formatted ${#files[@]} Bash script(s)."
