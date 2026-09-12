# Coding Standards

Engineering conventions and quality standards for this codebase. Automated tooling handles syntax; this document defines structure, boundaries, error handling, and slop prevention across our PowerShell (`.ps1`) and Bash/POSIX shell (`.sh`) implementations.

## 1. Structure & Simplicity (Code Judo)

- **Zero Useless Indirection:** Do not create identity wrappers, single-use classes, or pass-through helpers. Inline until genuine reuse emerges (Rule of Three).
- **Flat Control Flow:** Prefer early returns, guard clauses, and pattern matching. Avoid deep nesting (> 2 levels).
- **File & Module Scope:** Keep scripts focused and manageable. Break helper scripts or distinct phases into clear, cohesive responsibilities.
- **Canonical Layering:** Separate input parsing (reading JSON payload from stdin and user config from disk), layout selection, and terminal string formatting/rendering.
- **Contract & Alias Stability:** Maintain behavioral parity between `statusline.ps1` and `statusline.sh`. Preserve configuration keys (`~/.gemini/statusline.json`) and CLI argument behavior without breaking changes.
- **Automated Syntax & Formatting:** Formatting is automated across both languages via `tasks/format.*` using uniform 4-space indentation (`shfmt -i 4 -ci` and `Invoke-Formatter`). Static analysis is enforced via `tasks/lint.*` (`shellcheck` and `PSScriptAnalyzer`).

## 2. Types & Invariants

- **No Type Escapes / Unchecked Values:** In PowerShell, use explicit types and validate parameter bounds where appropriate. In Bash/sh, always quote variables (`"$var"`) to avoid word splitting and globbing errors.
- **Parse at the Boundary:** Validate and sanitize untrusted external inputs (stdin payload from `agy`, configuration files, terminal width) at the entry point. Provide resilient defaults when fields or files are missing.
- **Data Shapes:** Prefer simple dictionaries / hashtables and associative structures over deep or complicated object hierarchies.

## 3. Anti-Slop (Clean AI Output)

- **No Narration Comments:** Never write comments explaining *what* code does (e.g., `# print output` or `# parse json`). Comment only non-obvious *why* (terminal escape codes, Windows console encoding quirks, cross-platform POSIX differences).
- **Preserve Navigation Banners:** Structural section headers (e.g., `# ── QUOTA CALCULATIONS ──` or `# ── RENDERING ──`) that aid visual scanning in scripts are welcome.
- **Natural, Humanized Prose:** Keep documentation, commit messages, and PR descriptions concise, direct, and free of chatbot filler, inflated claims, or marketing fluff.
- **No Paranoia Guards:** Avoid wrapping trusted internal logic in defensive catch-all blocks that silently swallow errors or hide broken state. Fail fast or handle specific edge cases cleanly.
- **Preserve Local Idioms:** Follow idiomatic PowerShell conventions in `.ps1` and idiomatic POSIX/Bash conventions in `.sh`. Do not introduce unnecessary external dependencies (like Python or Node).

## 4. Tests

- **Public Seams & Invariants:** Test observable end-to-end status line output across all layout tiers (Narrow, Medium, Wide) and states (Ready, Thinking, Done, Error, Cancelled).
- **No Tautological Tests:** Avoid tests that assert implementation internals. Test input JSON fixture to output terminal text.
- **Avoid Excessive Mocking:** Rely on fixture data in `tests/fixtures/` and execute the scripts directly with native test runners (`test_ps1.ps1` and `test_sh.sh`).
