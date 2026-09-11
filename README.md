# my-agy-statusline

A statusline for the [Google Antigravity CLI](https://github.com/google-antigravity/antigravity-cli) (`agy`). It combines the rolling quota tracking from [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) with the agent metrics and state indicators from the [official example](https://github.com/google-antigravity/antigravity-cli/tree/main/examples/statusline), then adds responsive layout tiers, smart auto-hiding, and plan tier display.

No Python, no Node. Just a PowerShell script on Windows and a bash script everywhere else.

---

## Layouts

The script reads `terminal_width` from the agy payload and picks a layout automatically.

### Wide (>= 120 columns)

Everything on one line, quotas below.

![Wide layout](assets/wide-statusline.png)

```
● READY / Gemini 3.5 Flash (Low) / my-agy-statusline (main*)  │  ctx ░·············· 14.3% · artifacts 13
plan: Google AI Pro
gemini 5h ○○○○○○○○○○   0% ⟳ 21:22
gemini 7d ●●○○○○○○○○  19% ⟳ jul 7, 19:51
```

### Medium (>= 100 columns)

Two-line box layout.

![Medium layout](assets/medium-statusline.png)

```
╭─ ● READY / Claude Sonnet 4.6 (Thinking) / my-agy-statusline (main*)
╰─ ctx ████████·····  60.0% · artifacts 13
plan: Google AI Pro
claude 5h ●●●●●●●○○○  65% ⟳ 20:35
claude 7d ●●○○○○○○○○  22% ⟳ jul 11, 15:35
```

### Narrow (< 100 columns)

Four-line split — state and model on the first line, branch on the second, context bar on the third, stats on the fourth.

![Narrow layout](assets/narrow-statusline.png)

```
╭─ ● READY / Gemini 3.1 Pro (High)
├─ my-agy-statusline (main)
├─ ctx ░·············  14.3%
╰─ artifacts 13
plan: Google AI Pro
gemini 5h ○○○○○○○○○○   0% ⟳ 21:22
gemini 7d ●●○○○○○○○○  19% ⟳ jul 7, 19:51
```

---

## State indicators

| State    | Badge        |
| -------- | ------------ |
| idle     | `● READY`    |
| thinking | `◆ THINKING` |
| working  | `⚙ WORKING` |
| tool use | `🔧 TOOL`    |
| other    | `⏳ <STATE>` |

![Tool use state](assets/tool-use-statusline.png)

---

## Installation

**1. Clone the repo**

```bash
git clone https://github.com/dersual/my-agy-statusline.git
cd my-agy-statusline
```

**2. Run the installer**

On Windows (from PowerShell):

```powershell
./bin/install.ps1
```

On macOS / Linux:

```bash
chmod +x bin/install.sh
./bin/install.sh
```

Both scripts copy the statusline to `~/.gemini/` and update `~/.gemini/antigravity-cli/settings.json` to point to it. Restart `agy` after installing.

---

## Configuration

Optional. Create `~/.gemini/statusline.json` to override defaults:

```json
{
    "show_quota": true,
    "show_additional_stats": true,
    "hide_zero_stats": true,
    "show_state_indicator": true
}
```

| Option                  | Default | What it does                              |
| ----------------------- | ------- | ----------------------------------------- |
| `show_quota`            | `true`  | Show 5h and weekly quota bars             |
| `show_additional_stats` | `true`  | Show artifacts, subagents, tasks, sandbox |
| `hide_zero_stats`       | `true`  | Hide stats that are zero                  |
| `show_state_indicator`  | `true`  | Show the state badge                      |

---

## Dependencies

| Platform      | Requirements                              |
| ------------- | ----------------------------------------- |
| Windows       | PowerShell 5.1+, no external dependencies |
| macOS / Linux | bash, jq                                  |

The `.sh` script handles both GNU `date` (Linux) and BSD `date` (macOS) for reset time formatting.

---

## Development

Run the task scripts to check or format code before opening a pull request. You only need to run the tools for the scripts you changed (for example, if you only touch `.sh` files, you do not need PowerShell or `.ps1` formatters). GitHub Actions validates both platforms automatically on every pull request.

### On Linux / macOS

**Bash scripts:**

```bash
./tasks/lint.sh      # Run ShellCheck and check formatting
./tasks/format.sh    # Format Bash scripts with shfmt
```

**Tool installation:**

-   macOS: `brew install shellcheck shfmt`
-   Ubuntu / Debian: `sudo apt install shellcheck` (download `shfmt` from [github.com/mvdan/sh/releases](https://github.com/mvdan/sh/releases))

**Optional: PowerShell scripts (if editing `.ps1` files):**
Requires PowerShell (`pwsh`) and the PSScriptAnalyzer module (`Install-Module PSScriptAnalyzer`).

```bash
pwsh ./tasks/lint.ps1
pwsh ./tasks/format.ps1
```

### On Windows

**PowerShell scripts:**

```powershell
./tasks/lint.ps1      # Run PSScriptAnalyzer
./tasks/format.ps1    # Format PowerShell scripts
```

**Tool installation:**

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
```

**Optional: Bash scripts (if editing `.sh` files):**
Install ShellCheck and shfmt via winget, then run from Git Bash:

```powershell
winget install koalaman.shellcheck mvdan.shfmt
```

```bash
./tasks/lint.sh
./tasks/format.sh
```

GitHub Actions runs these lint and format checks on every push and pull request.

---

## Credits

-   [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) for the quota tracking approach
-   [antigravity-cli examples](https://github.com/google-antigravity/antigravity-cli/tree/main/examples/statusline) for the original statusline structure
