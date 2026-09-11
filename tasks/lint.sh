#!/usr/bin/env bash
set -euo pipefail

# Project root resolution
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "--- Linting Bash scripts (ShellCheck) ---"
files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find bin tasks tests -name "*.sh" -print0 2>/dev/null)

if [ ${#files[@]} -eq 0 ]; then
    echo "No .sh files found to lint."
    exit 0
fi

shellcheck "${files[@]}"

echo "--- Checking Bash formatting (shfmt) ---"
shfmt -d -i 4 -ci "${files[@]}"

echo "All Bash scripts passed linting and format checks."
