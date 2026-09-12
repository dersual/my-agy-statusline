# 1. Script Linters and Formatters

Date: 2026-09-11  
Status: accepted  

## Context

`my-agy-statusline` provides dual implementations in pure Bash (`.sh`) and PowerShell (`.ps1`) with zero external runtime dependencies (no Node.js, Python, or Rust). Without automated tooling, code style drifts across edits and platform-specific hazards (Bash unquoted word-splitting, PowerShell pipeline output leakage, Unicode encoding corruption) risk introducing regressions.

## Decision

We adopt **ShellCheck** and **shfmt** for Bash, and **PSScriptAnalyzer** for PowerShell, enforcing a uniform **4-space indentation** across both languages. Static analysis and formatting are orchestrated via native task runners in `tasks/` (`lint.sh`, `format.sh`, `lint.ps1`, `format.ps1`) and validated in CI on `ubuntu-latest` via `.github/workflows/lint.yml`.

## Considered Options

- **Node.js / Husky / lint-staged:** Rejected to preserve the repository's zero-dependency footprint.
- **Google Shell 2-space indentation:** Rejected to maintain indentation parity with the PowerShell codebase and avoid full-file diff rewrites.

## Consequences

- Task runners in `tasks/` act as the single source of truth for invocation flags and exit code bridging across local development, AI agents, and CI.
- PowerShell formatters explicitly enforce UTF-8 without BOM to protect Unicode box-drawing glyphs from Windows PowerShell 5.1 encoding defaults.
- ShellCheck and PSScriptAnalyzer provide machine-readable feedback for automated developer and agent remediation.
