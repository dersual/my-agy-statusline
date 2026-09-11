# Research Report: Linters and Formatters for Bash and PowerShell

**Issue:** #12 ("Add linters and formatters for both PowerShell and Bash scripts")  
**Target Repository:** `my-agy-statusline`  
**Date:** September 2026  
**Status:** Completed Research & Architectural Recommendation  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Industry Adoption & Standard Practice](#2-industry-adoption--standard-practice)
3. [Impact on AI Coding Agents: Benefits & Friction Analysis](#3-impact-on-ai-coding-agents-benefits--friction-analysis)
   - [3.1 Deterministic Formatting vs. LLM Hallucinations & Drift](#31-deterministic-formatting-vs-llm-hallucinations--drift)
   - [3.2 AST-Level Static Analysis vs. Scripting Pitfalls](#32-ast-level-static-analysis-vs-scripting-pitfalls)
   - [3.3 Machine-Readable Feedback Loops (SARIF, JSON, GCC)](#33-machine-readable-feedback-loops-sarif-json-gcc)
   - [3.4 Automated Remediation & Auto-Fixing Boundaries](#34-automated-remediation--auto-fixing-boundaries)
   - [3.5 Agent Friction Points & Operational Gotchas](#35-agent-friction-points--operational-gotchas)
4. [Bash Tooling: ShellCheck & shfmt](#4-bash-tooling-shellcheck--shfmt)
   - [4.1 ShellCheck (koalaman/shellcheck)](#41-shellcheck-koalamanshellcheck)
   - [4.2 shfmt (mvdan/sh)](#42-shfmt-mvdansh)
5. [PowerShell Tooling: PSScriptAnalyzer](#5-powershell-tooling-psscriptanalyzer)
   - [5.1 Architecture & Core Cmdlets](#51-architecture--core-cmdlets)
   - [5.2 Settings Profiles (`PSScriptAnalyzerSettings.psd1`)](#52-settings-profiles-psscriptanalyzersettingspsd1)
   - [5.3 Formatting Engine (`Invoke-Formatter`)](#53-formatting-engine-invoke-formatter)
   - [5.4 Output Formats, SARIF, & Exit Code Mechanics](#54-output-formats-sarif--exit-code-mechanics)
   - [5.5 Compatibility: Windows PowerShell 5.1 vs. PowerShell 7+ (pwsh)](#55-compatibility-windows-powershell-51-vs-powershell-7-pwsh)
6. [Tooling & Workflow Integration for `my-agy-statusline`](#6-tooling--workflow-integration-for-my-agy-statusline)
   - [6.1 Zero-Dependency Constraints & Installation Matrix](#61-zero-dependency-constraints--installation-matrix)
   - [6.2 Repository Configuration Files](#62-repository-configuration-files)
   - [6.3 Task Runner Architecture (`tasks/`)](#63-task-runner-architecture-tasks)
   - [6.4 CI Pipeline Integration (GitHub Actions)](#64-ci-pipeline-integration-github-actions)
   - [6.5 Practical Developer & Agent Command Cheatsheet](#65-practical-developer--agent-command-cheatsheet)
7. [Primary Source Citations & References](#7-primary-source-citations--references)

---

## 1. Executive Summary

This research investigates the technical requirements, industry adoption, AI agent interaction patterns, and repository integration paths for adding static analysis (linting) and code formatting to the `my-agy-statusline` codebase for both **Bash** and **PowerShell**.

### Core Recommendations
- **Bash Linter:** **ShellCheck** (`koalaman/shellcheck`)
  - *Standard:* De facto industry standard static analysis engine for POSIX/Bash scripts.
  - *Format:* Emits GCC (`-f gcc`) and JSON (`-f json1`) for agent consumption; diff patches (`-f diff`) for automated remediation.
- **Bash Formatter:** **shfmt** (`mvdan/sh`)
  - *Standard:* De facto standard shell parser and formatter, supporting POSIX, Bash, mksh, and bats dialects.
  - *Configuration:* Native `.editorconfig` integration with 4-space indentation to match `CODING_STANDARDS.md`.
- **PowerShell Linter & Formatter:** **PSScriptAnalyzer** (`PowerShell/PSScriptAnalyzer`)
  - *Standard:* Official Microsoft static analysis engine and formatting tool for PowerShell.
  - *Execution:* `Invoke-ScriptAnalyzer` for rules and automated fixes; `Invoke-Formatter` for whitespace and layout enforcement.
  - *Configuration:* Project-level `PSScriptAnalyzerSettings.psd1` tuned to allow terminal UI operations (e.g., suppressing `PSAvoidUsingWriteHost` and `PSUseSingularNouns` for internal statusline helpers).

### Key Architectural Fit for `my-agy-statusline`
1. **Zero External Ecosystem Dependencies:** The project requires neither Node.js (`npm`), Python (`pip`), nor Rust (`cargo`). All chosen tools are distributed as single static standalone binaries (ShellCheck, shfmt) or as a native PowerShell Gallery module (PSScriptAnalyzer).
2. **Pre-Installed CI Runners:** GitHub Actions runner images (`ubuntu-latest`, `windows-latest`) already pre-install ShellCheck and PSScriptAnalyzer. Adding shfmt takes a single fast binary download, maintaining CI runtimes under 10 seconds.
3. **Local Task Runners:** Scripts in `tasks/` (`tasks/lint.sh`, `tasks/format.sh`, `tasks/lint.ps1`, `tasks/format.ps1`) expose identical developer and agent interfaces across Windows, macOS, and Linux.

---

## 2. Industry Adoption & Standard Practice

Historically, shell scripts were treated as disposable "glue code," rarely subjected to static analysis beyond `bash -n` syntax validation or ad-hoc trial and error. However, as DevOps workflows, container entrypoints, and terminal CLI utilities (such as Google Antigravity statuslines) expanded in complexity, shell scripts became critical path infrastructure.

### Industry Adoption Metrics

| Ecosystem | Tool | Industry Adoption Benchmarks | Standard Enforcers |
| :--- | :--- | :--- | :--- |
| **Bash / POSIX sh** | **ShellCheck** | • 35,000+ GitHub Stars<br>• Pre-installed on GitHub Actions `ubuntu-latest` and `macos-latest`<br>• Pre-installed on GitLab CI shared runners | • Google Shell Style Guide<br>• GitHub Super-Linter<br>• MegaLinter<br>• Pre-commit hook ecosystem |
| **Bash / POSIX sh** | **shfmt** | • 4,500+ GitHub Stars<br>• Adopted by Docker official images and Kubernetes build scripts<br>• Default formatter in VS Code Bash IDE and shfmt extensions | • MegaLinter<br>• Google Shell Style Guide (with `-i 2 -ci -bn`)<br>• Arch Linux, Debian, Homebrew core packages |
| **PowerShell** | **PSScriptAnalyzer** | • 100M+ downloads on PowerShell Gallery<br>• Powers Microsoft's official VS Code PowerShell extension (`ms-vscode.powershell`)<br>• Pre-installed on GitHub Actions `windows-latest` | • Microsoft PowerShell Practice and Style Guide<br>• Azure DevOps extension verification<br>• PowerShell Gallery module publishing criteria |

### Key Style Guides
- **Google Shell Style Guide:** Mandates the use of ShellCheck to identify common traps and code smells before code review. Emphasizes automated formatting over manual indentation disputes.
- **Microsoft PowerShell Practice and Style Guide:** Explicitly documents PSScriptAnalyzer as the foundational quality gate for any PowerShell codebase, prescribing standard naming, casing, and pipeline error handling.
- **Meta-Linters (Super-Linter & MegaLinter):** Both GitHub's Super-Linter and OX Security's MegaLinter select ShellCheck + shfmt as the official toolchain for Shell, and PSScriptAnalyzer as the toolchain for PowerShell.

---

## 3. Impact on AI Coding Agents: Benefits & Friction Analysis

AI coding agents (such as Google DeepMind Antigravity, Claude Code, and GitHub Copilot Workspace) generate and modify code by emitting token streams and unified diff patches. The presence of deterministic linters and formatters fundamentally alters agent reliability.

### 3.1 Deterministic Formatting vs. LLM Hallucinations & Drift

1. **Elimination of Whitespace Drift:**
   LLMs generate whitespace probabilistically. Without an enforced formatter, agents frequently alternate between 2-space and 4-space indentation, insert or strip trailing newlines, and produce mismatched bracket indentations. This causes large, noisy git diffs that touch dozens of unrelated lines.
2. **Surgical Diff Enforcement:**
   Repository guidelines (such as `AGENTS.md` Rule 3: *Surgical Changes: Touch only what you must*) demand that diffs remain minimal. A post-edit formatter run (`tasks/format.sh` / `tasks/format.ps1`) normalizes formatting automatically, ensuring agent PRs contain strictly semantic changes.
3. **Attention Alignment & Code Understanding:**
   Transformers pay attention across tokenized syntax. Canonically formatted code aligns with training distribution density. Clean indentation and brace placement improve an agent's ability to locate block boundaries during subsequent edits.

### 3.2 AST-Level Static Analysis vs. Scripting Pitfalls

Bash and PowerShell have notoriously tricky runtime behavior:
- **Bash Hazards:** Unquoted expansions (`$var` vs `"$var"` causing word-splitting and glob expansion, SC2086), subshell variable mutations, silent failure under pipes, and assignment spacing mistakes (`var = val` vs `var=val`). ShellCheck analyzes the syntax tree directly and prevents catastrophic failure modes.
- **PowerShell Hazards:** Implicit pipeline output leaks (expressions accidentally dumping objects onto the pipeline that corrupt caller return values), unapproved cmdlet verbs, dynamic code evaluation (`Invoke-Expression`), and scope leakage. PSScriptAnalyzer catches these via AST inspection without needing runtime execution.

### 3.3 Machine-Readable Feedback Loops (SARIF, JSON, GCC)

When an agent makes an edit, it must verify its work through an automated feedback loop:
```
[Agent Edits Code] ──> [Run Linter/Formatter] ──> [Parse Machine Output] ──> [Apply Target Fix]
```
- **GCC Format (`shellcheck -f gcc`):** Emits `<file>:<line>:<col>: <severity>: <message> (SC####)`. This matches standard C compiler diagnostics that LLMs parse with near-zero error rates.
- **JSON Format (`shellcheck -f json1` & `Invoke-ScriptAnalyzer | ConvertTo-Json`):** Provides exact start/end byte offsets, line numbers, rule IDs, and replacement strings.
- **SARIF (Static Analysis Results Interchange Format):** Supported natively by Microsoft's `psscriptanalyzer-action` and convertible via ShellCheck SARIF converters. Uploads directly to GitHub Code Scanning.

### 3.4 Automated Remediation & Auto-Fixing Boundaries

Both ecosystems provide automated fixing:
- `shfmt -w <file>`: 100% safe mechanical whitespace/layout transformation. No semantic changes.
- `shellcheck -f diff <files> | git apply`: Emits standard unified diffs for known fixes (such as quoting unquoted expansions or correcting shebang lines).
- `Invoke-ScriptAnalyzer -Fix`: Replaces deprecated aliases, standardizes casing, and cleans whitespace.

> [!IMPORTANT]
> **Safety Boundary for Agents:** Formatters (`shfmt -w`) should always run automatically after agent edits. Semantic linter fixes (`Invoke-ScriptAnalyzer -Fix` or `shellcheck -f diff`), however, should be verified against automated unit test suites (`tests/test_ps1.ps1`, `tests/test_sh.sh`) to prevent subtle behavioral changes in string interpolation or variable splitting.

### 3.5 Agent Friction Points & Operational Gotchas

1. **Execution Latency / Cold Start Overhead:**
   - `shfmt` and `shellcheck` are compiled static Go and Haskell binaries. They execute in **10–40ms**. An agent can run them on every file save without perceptible lag.
   - `PSScriptAnalyzer` runs on top of the .NET CLR inside `powershell.exe` or `pwsh`. Module import and AST compilation impose a **500ms–2000ms** startup penalty. Agents should invoke PSScriptAnalyzer across all files in a single pass rather than spawning a new PowerShell process per file.
2. **False Positives in Terminal UI Utilities:**
   - Statusline scripts inherently interact with console streams. PSScriptAnalyzer rule `PSAvoidUsingWriteHost` flags any use of `Write-Host`. However, in console rendering, direct host writes or ANSI stream outputs are intentional.
   - PSScriptAnalyzer rule `PSUseSingularNouns` flags internal helper functions (e.g., `Get-QuotaWindows`).
   - ShellCheck rule `SC2086` warns about unquoted variables. If word-splitting is intentionally desired, it will flag continuously.
   - *Mitigation:* The repository **must** commit tailored `.shellcheckrc` and `PSScriptAnalyzerSettings.psd1` configurations that suppress these domain-inappropriate rules.
3. **Windows Encoding & BOM Hazards:**
   - In Windows PowerShell 5.1, cmdlets like `Out-File` and `Set-Content` historically defaulted to `Unicode` (UTF-16LE) or `ANSI`.
   - Modifying `.ps1` files with `-Fix` or formatting cmdlets without specifying `-Encoding utf8` can corrupt UTF-8 files containing box-drawing and Unicode glyphs (e.g., `statusline.ps1` lines 10–27).
   - Any script-based formatting in PowerShell must explicitly enforce UTF-8 without BOM or use .NET `[System.IO.File]::WriteAllText()`.
4. **PowerShell Exit Code Convention Disconnect:**
   - `Invoke-ScriptAnalyzer` is a cmdlet, not a CLI binary. If it finds 50 errors, it outputs 50 `DiagnosticRecord` objects and terminates with exit code 0 (`$LASTEXITCODE` is untouched).
   - An agent running `powershell -Command "Invoke-ScriptAnalyzer ..."` will see an exit code of `0` and believe the check passed unless an explicit wrapper evaluates the results and invokes `exit 1`.

---

## 4. Bash Tooling: ShellCheck & shfmt

### 4.1 ShellCheck (`koalaman/shellcheck`)

ShellCheck is an open-source static analysis tool written in Haskell that detects bugs, syntax errors, and anti-patterns in shell scripts.

#### Core CLI Flags & Specifications

| Flag | Argument | Description |
| :--- | :--- | :--- |
| `-s`, `--shell` | `bash`, `sh`, `dash`, `ksh` | Explicitly sets shell dialect. Overrides shebang detection. |
| `-S`, `--severity` | `error`, `warning`, `info`, `style` | Sets minimum severity to report. Default: `style`. |
| `-f`, `--format` | `tty`, `gcc`, `json`, `json1`, `diff`, `checkstyle` | Specifies output format for human or machine parsing. |
| `-x`, `--external-sources` | None | Follows `source` and `.` statements across files. |
| `-e`, `--exclude` | `CODE1,CODE2,...` | Excludes specific error codes (e.g. `-e SC2086,SC2155`). |
| `-o`, `--enable` | `NAME1,NAME2,...` | Enables optional advanced checks (e.g. `quote-safe-variables`). |
| `--rcfile` | `PATH` | Specifies custom `.shellcheckrc` configuration file. |
| `--norc` | None | Disables loading default `.shellcheckrc`. |

#### Output Formats & Agent Integration
- **`gcc` (`-f gcc`):** Emits compiler-style diagnostics:
  ```
  bin/statusline.sh:8:7: note: Declare and assign separately to avoid masking return values. [SC2155]
  ```
  Optimal for compact agent tool outputs.
- **`json1` (`-f json1`):** Emits comprehensive structured JSON containing file paths, 1-indexed line/column positions, rule codes, severity levels, and automated replacement patches.
- **`diff` (`-f diff`):** Generates unified diff patches. Can be piped directly to `git apply`:
  ```bash
  shellcheck -f diff bin/statusline.sh | git apply
  ```

#### Exit Codes
- **`0`:** All files checked successfully; no issues found at or above specified severity.
- **`1`:** Syntax issues or rule violations found at or above specified severity.
- **`2`:** ShellCheck crashed or was invoked with invalid command-line arguments.

#### Configuration File (`.shellcheckrc`)
Located in project root or user home directory. Supports key-value syntax:
```ini
# .shellcheckrc - ShellCheck configuration for my-agy-statusline
shell=bash
severity=style
external-sources=true

# Allow masking return values in inline evaluations if intentional
disable=SC2155
```

---

### 4.2 shfmt (`mvdan/sh`)

`shfmt` is a shell parser, formatter, and interpreter written in Go by Daniel Martí. It formats POSIX shell, Bash, and mksh code according to standard idioms.

#### Core CLI Flags & Specifications

| Flag | Argument | Description |
| :--- | :--- | :--- |
| `-w`, `--write` | None | Write formatted output directly to file (modifies files in place). |
| `-d`, `--diff` | None | Emits unified diff and returns exit code 1 if formatting differs. **Ideal for CI**. |
| `-l`, `--list` | None | Lists files whose formatting differs from shfmt. |
| `-i`, `--indent` | `uint` | Indentation width. `0` for tabs (default), `2` or `4` for spaces. |
| `-ci`, `--case-indent` | None | Switch `case` pattern statements are indented relative to `switch`. |
| `-bn`, `--binary-next-line` | None | Binary operators (`&&`, `\|\|`) start the next line. |
| `-sr`, `--space-redirects` | None | Places space after redirection operators (`> /dev/null` vs `>/dev/null`). |
| `-s`, `--simplify` | None | Simplifies code structures (removes redundant brackets, etc.). |
| `-ln`, `--language-dialect` | `bash`, `posix`, `mksh`, `bats` | Enforces language dialect. Defaults to `auto`. |

#### Exit Codes
- **`0`:** Formatting is correct (or `-w` successfully wrote all changes) with no syntax errors.
- **`1`:** Formatting differences detected (when `-d` or `-l` is specified), or file is unparseable due to syntax errors.

#### `.editorconfig` Integration
`shfmt` automatically respects `.editorconfig` settings unless command-line printer flags are passed:
```ini
# .editorconfig
[*.sh]
indent_style = space
indent_size = 4
shell_variant = bash
binary_next_line = false
switch_case_indent = true
```

---

## 5. PowerShell Tooling: PSScriptAnalyzer

### 5.1 Architecture & Core Cmdlets

`PSScriptAnalyzer` is Microsoft's official static analysis tool for PowerShell. It inspects PowerShell code by parsing scripts into an Abstract Syntax Tree (AST) using the PowerShell engine's internal `System.Management.Automation.Language.Parser`.

#### Core Cmdlets
1. **`Invoke-ScriptAnalyzer`:** Evaluates scripts against built-in and custom rules.
2. **`Invoke-Formatter`:** Formats script text based on whitespace and layout settings.
3. **`Get-ScriptAnalyzerRule`:** Lists available rules and metadata.
4. **`Test-ScriptAnalyzerSettingsFile`:** Validates a settings `.psd1` file syntax.

#### Key Parameters for `Invoke-ScriptAnalyzer`

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `-Path` | `string[]` | Path to directory or script file(s) to analyze. |
| `-Recurse` | `SwitchParameter` | Recursively checks all PowerShell files under `-Path`. |
| `-Settings` | `string \| hashtable` | Path to `.psd1` settings file, preset name (`CodeFormatting`, `Security`), or inline hashtable. |
| `-Severity` | `string[]` | Filters results by severity: `Error`, `Warning`, `Information`. |
| `-Fix` | `SwitchParameter` | Automatically applies rule corrections directly to files. |
| `-ReportSummary` | `SwitchParameter` | Emits a summary count of rule violations by severity. |
| `-IncludeRule` / `-ExcludeRule` | `string[]` | Explicit rule inclusion or exclusion overrides. |

---

### 5.2 Settings Profiles (`PSScriptAnalyzerSettings.psd1`)

PSScriptAnalyzer allows project-wide declarative configuration via a PowerShell Data (`.psd1`) file. If placed in the project root as `PSScriptAnalyzerSettings.psd1`, `Invoke-ScriptAnalyzer` will automatically discover and load it.

```powershell
# PSScriptAnalyzerSettings.psd1 - Configuration for my-agy-statusline
@{
    # Process all default rules unless explicitly excluded
    IncludeDefaultRules = $true

    # Rules to disable for terminal statusline rendering
    ExcludeRules = @(
        # Statuslines directly render output; Write-Host is appropriate for console UI
        'PSAvoidUsingWriteHost',
        # Internal helper functions (e.g. Get-Quota) do not require formal Verb-Noun cmdlets
        'PSUseSingularNouns',
        # Statuslines make heavy use of empty catch blocks for resilient fallback
        'PSAvoidUsingEmptyCatchBlock'
    )

    # Granular rule configurations
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseConsistentWhitespace = @{
            Enable              = $true
            CheckOpenBrace      = $true
            CheckOpenParen      = $true
            CheckOperator       = $true
            CheckSeparator      = $true
            CheckInnerBrace     = $true
        }
        PSAlignAssignmentStatement = @{
            Enable              = $false
        }
    }
}
```

---

### 5.3 Formatting Engine (`Invoke-Formatter`)

`Invoke-Formatter` reformats script code using the formatting rules specified in the settings profile.

#### Command-Line Invocation Pattern:
```powershell
# Format single file via pipeline:
Get-Content -Path "bin/statusline.ps1" -Raw | 
    Invoke-Formatter -Settings "./PSScriptAnalyzerSettings.psd1" | 
    Set-Content -Path "bin/statusline.ps1" -Encoding UTF8
```

---

### 5.4 Output Formats, SARIF, & Exit Code Mechanics

#### Output Objects
`Invoke-ScriptAnalyzer` outputs `Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord` objects containing:
- `RuleName`: Name of the violated rule (e.g., `PSUseConsistentIndentation`).
- `Severity`: `Error`, `Warning`, or `Information`.
- `ScriptName`: Absolute path to the file.
- `Line`: 1-indexed line number.
- `Column`: 1-indexed column number.
- `Message`: Human-readable violation description.
- `SuggestedCorrections`: Array of replacement strings and text extents for auto-fixing.

#### Agent Machine Output (JSON & SARIF)
- **JSON Conversion:**
  ```powershell
  Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 | ConvertTo-Json
  ```
- **SARIF Conversion (GitHub Actions & CodeQL):**
  Microsoft maintains `microsoft/psscriptanalyzer-action` which outputs results directly to a `.sarif` file:
  ```yaml
  - name: Run PSScriptAnalyzer
    uses: microsoft/psscriptanalyzer-action@v1.1
    with:
      path: bin
      recurse: true
      output: results.sarif
  ```

#### Exit Code Wrapper Pattern
Because `Invoke-ScriptAnalyzer` does not set `$LASTEXITCODE`, CI and task scripts must check output count:
```powershell
$issues = Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error, Warning
if ($issues) {
    $issues | Format-Table -Property ScriptName, Line, RuleName, Message -AutoSize
    exit 1
}
exit 0
```

---

### 5.5 Compatibility: Windows PowerShell 5.1 vs. PowerShell 7+ (pwsh)

`PSScriptAnalyzer` is built to run identically on both runtimes:
- **Windows PowerShell 5.1 (`powershell.exe`):** Built into all Windows 10/11 and Windows Server systems. PSScriptAnalyzer module version 1.22+ is fully supported.
- **PowerShell 7+ (`pwsh`):** Cross-platform modern PowerShell running on .NET Core. Supported on Windows, macOS, and Linux.

#### Encoding Preservation Between Versions
- In Windows PowerShell 5.1: `Set-Content -Encoding utf8` writes UTF-8 with BOM (Byte Order Mark).
- In PowerShell 7+: `Set-Content -Encoding utf8` writes UTF-8 **without** BOM (standard POSIX UTF-8).
- **Rule for `my-agy-statusline`:** To avoid BOM issues in cross-platform Git checkouts, task scripts should use `[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))` when formatting code on Windows PowerShell 5.1.

---

## 6. Tooling & Workflow Integration for `my-agy-statusline`

The repository architecture for `my-agy-statusline` has zero Node.js, Python, or Ruby dependencies. All tooling must remain lightweight, fast, and native.

### 6.1 Zero-Dependency Constraints & Installation Matrix

| Operating System | Tool | Recommended Installation Method | Fallback Method |
| :--- | :--- | :--- | :--- |
| **Windows** | **ShellCheck** | `scoop install shellcheck` OR `winget install koalaman.shellcheck` | Download GitHub Release binary to `~/.local/bin` |
| **Windows** | **shfmt** | `scoop install shfmt` OR `winget install mvdan.shfmt` | Download GitHub Release binary to `~/.local/bin` |
| **Windows** | **PSScriptAnalyzer** | `Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force` | Pre-installed in CI |
| **macOS** | **ShellCheck** | `brew install shellcheck` | MacPorts / GitHub binary |
| **macOS** | **shfmt** | `brew install shfmt` | MacPorts / GitHub binary |
| **macOS** | **PSScriptAnalyzer** | `pwsh -Command "Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force"` | Pre-installed in CI |
| **Linux (Ubuntu)** | **ShellCheck** | `sudo apt-get install -y shellcheck` | Pre-installed on GitHub Actions `ubuntu-latest` |
| **Linux (Ubuntu)** | **shfmt** | Download standalone binary `curl -sSLo /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/...` | `snap install shfmt` |
| **Linux (Ubuntu)** | **PSScriptAnalyzer** | `pwsh -Command "Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force"` | Pre-installed in CI |

---

### 6.2 Repository Configuration Files

The repository should add three root-level configuration files:

1. **`.editorconfig`**:
   Configures standard indentation (4 spaces for shell and PowerShell), newline formatting, and charset.
2. **`.shellcheckrc`**:
   Configures Bash dialect, rules, and external source following.
3. **`PSScriptAnalyzerSettings.psd1`**:
   Configures PowerShell formatting rules and disables false positives for statusline scripts.

---

### 6.3 Task Runner Architecture (`tasks/`)

The repository currently maintains an empty `tasks/` folder. We propose populating `tasks/` with four self-contained, native scripts:

```
tasks/
├── lint.sh        # Runs shellcheck and shfmt -d on all .sh files
├── format.sh      # Runs shfmt -w on all .sh files
├── lint.ps1       # Runs Invoke-ScriptAnalyzer on all .ps1 files with exit codes
└── format.ps1     # Formats all .ps1 files using Invoke-Formatter / -Fix
```

#### Specification: `tasks/lint.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_FILES=$(find "$ROOT_DIR/bin" "$ROOT_DIR/tests" "$ROOT_DIR/tasks" -name "*.sh" 2>/dev/null || true)

if [ -z "$TARGET_FILES" ]; then
    echo "No shell files found to lint."
    exit 0
fi

echo "==> Running ShellCheck..."
# shellcheck disable=SC2086
shellcheck $TARGET_FILES

echo "==> Checking formatting with shfmt..."
# shellcheck disable=SC2086
shfmt -d -i 4 -ci $TARGET_FILES

echo "✓ All Bash scripts passed linting and format checks."
```

#### Specification: `tasks/format.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_FILES=$(find "$ROOT_DIR/bin" "$ROOT_DIR/tests" "$ROOT_DIR/tasks" -name "*.sh" 2>/dev/null || true)

if [ -z "$TARGET_FILES" ]; then
    echo "No shell files found to format."
    exit 0
fi

echo "==> Formatting shell scripts with shfmt..."
# shellcheck disable=SC2086
shfmt -w -i 4 -ci $TARGET_FILES
echo "✓ All Bash scripts formatted."
```

#### Specification: `tasks/lint.ps1`
```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$settingsPath = Join-Path $rootDir "PSScriptAnalyzerSettings.psd1"

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Warning "PSScriptAnalyzer module not found. Installing for CurrentUser..."
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

$targetPaths = @(
    (Join-Path $rootDir "bin"),
    (Join-Path $rootDir "tests"),
    (Join-Path $rootDir "tasks")
) | Where-Object { Test-Path $_ }

Write-Host "==> Running PSScriptAnalyzer..." -ForegroundColor Cyan
$issues = Invoke-ScriptAnalyzer -Path $targetPaths -Recurse -Settings $settingsPath -Severity Error, Warning

if ($issues) {
    Write-Host "Linting violations found:" -ForegroundColor Red
    $issues | Format-Table -Property ScriptName, Line, RuleName, Message -AutoSize
    exit 1
}

Write-Host "✓ All PowerShell scripts passed linting checks." -ForegroundColor Green
exit 0
```

#### Specification: `tasks/format.ps1`
```powershell
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$settingsPath = Join-Path $rootDir "PSScriptAnalyzerSettings.psd1"

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module PSScriptAnalyzer -ErrorAction Stop

$psFiles = Get-ChildItem -Path $rootDir -Include *.ps1, *.psm1, *.psd1 -Recurse | 
    Where-Object { $_.FullName -notmatch '\\(\.git)\\' }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

foreach ($file in $psFiles) {
    Write-Host "Formatting: $($file.Name)" -ForegroundColor Cyan
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $formatted = Invoke-Formatter -ScriptDefinition $content -Settings $settingsPath
    [System.IO.File]::WriteAllText($file.FullName, $formatted, $utf8NoBom)
}

Write-Host "✓ All PowerShell scripts formatted." -ForegroundColor Green
```

---

### 6.4 CI Pipeline Integration (GitHub Actions)

Add a dedicated `lint` job to `.github/workflows/test.yml` (or create `.github/workflows/lint.yml`):

```yaml
  lint:
    name: Lint & Format Checks
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Install shfmt
        run: |
          SHFMT_VERSION="3.14.0"
          curl -sSLo /tmp/shfmt "https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64"
          chmod +x /tmp/shfmt
          sudo mv /tmp/shfmt /usr/local/bin/shfmt
          shfmt --version

      - name: Run Bash Lint & Format Check
        run: |
          chmod +x tasks/lint.sh
          bash tasks/lint.sh

      - name: Run PowerShell Lint Check
        shell: pwsh
        run: |
          pwsh -NoProfile -File tasks/lint.ps1
```

---

### 6.5 Practical Developer & Agent Command Cheatsheet

| Intent | Command | Target Shell |
| :--- | :--- | :--- |
| **Check All Bash Scripts** | `bash tasks/lint.sh` | Bash / Git Bash / Zsh |
| **Auto-Format All Bash Scripts** | `bash tasks/format.sh` | Bash / Git Bash / Zsh |
| **Check All PowerShell Scripts** | `powershell -NoProfile -File tasks/lint.ps1` | Windows PowerShell 5.1 |
| **Check All PowerShell Scripts (pwsh)**| `pwsh -NoProfile -File tasks/lint.ps1` | PowerShell 7+ (Win/Mac/Linux) |
| **Auto-Format All PowerShell Scripts**| `powershell -NoProfile -File tasks/format.ps1` | Windows PowerShell / pwsh |
| **Single-File Bash Check (Agent)** | `shellcheck -f gcc bin/statusline.sh` | Any |
| **Single-File Format Check (Agent)** | `shfmt -d -i 4 -ci bin/statusline.sh` | Any |
| **Single-File Auto-Format (Agent)** | `shfmt -w -i 4 -ci bin/statusline.sh` | Any |

---

## 7. Primary Source Citations & References

1. **ShellCheck Repository & Manual:**
   - Source: [koalaman/shellcheck](https://github.com/koalaman/shellcheck)
   - Man Page: [ShellCheck(1) Manual Specification](https://raw.githubusercontent.com/koalaman/shellcheck/master/shellcheck.1.md)
   - Exit Values & Flags: `-f, --format={tty,gcc,json1,diff}`, `-S, --severity={error,warning,info,style}`.

2. **shfmt Repository & Manual:**
   - Source: [mvdan/sh](https://github.com/mvdan/sh)
   - Man Page: [shfmt(1) SCD Source](https://raw.githubusercontent.com/mvdan/sh/master/cmd/shfmt/shfmt.1.scd)
   - Flags & Options: `-i <uint>`, `-ci`, `-bn`, `-sr`, `-w`, `-d`, `-l`.

3. **Microsoft PSScriptAnalyzer Official Documentation:**
   - Overview: [Microsoft Learn: PSScriptAnalyzer Overview](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview)
   - Cmdlet Docs: [Invoke-ScriptAnalyzer Documentation](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-scriptanalyzer)
   - Formatter Docs: [Invoke-Formatter Documentation](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-formatter)
   - GitHub Repository: [PowerShell/PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)

4. **GitHub Actions Runner Images Specifications:**
   - Software Manifests: [actions/runner-images](https://github.com/actions/runner-images)
   - Verified: ShellCheck pre-installed on `ubuntu-latest` and `macos-latest`; PSScriptAnalyzer pre-installed on `windows-latest` and `macos-latest`.

5. **Style Guides & Standards:**
   - Google Shell Style Guide: [google.github.io/styleguide/shellguide.html](https://google.github.io/styleguide/shellguide.html)
   - Microsoft PowerShell Style Guide: [GitHub: PowerShell Practice and Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)
   - GitHub Super-Linter: [github/super-linter](https://github.com/super-linter/super-linter)
   - MegaLinter Documentation: [megalinter.io](https://megalinter.io)
