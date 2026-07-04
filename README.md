# my-agy-statusline

A statusline for the [Google Antigravity CLI](https://github.com/google-antigravity/antigravity-cli) (`agy`). It combines the rolling quota tracking from [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) with the agent metrics and state indicators from the [official example](https://github.com/google-antigravity/antigravity-cli/tree/main/examples/statusline), then adds a few things neither has: responsive layout tiers, smart auto-hiding, and plan tier display.

No Python, no Node. Just a PowerShell script on Windows and a bash script everywhere else.

---

## Screenshots

> **To capture these:** open a terminal at the width shown, run `agy`, and screenshot the prompt.

**Wide terminal (>= 120 columns):** everything on one line.

<!-- screenshot: wide layout -->
<!-- terminal width: 120+ columns, any active session -->

**Medium terminal (>= 100 columns):** two-line box layout.

<!-- screenshot: medium layout -->
<!-- terminal width: 100–119 columns, any active session -->

**Narrow terminal (< 100 columns):** four-line split layout.

<!-- screenshot: narrow layout -->
<!-- terminal width: 70–99 columns, active session with artifacts/subagents -->

**Tool use state:**

<!-- screenshot: tool_use state -->
<!-- trigger: start a session and use any tool -->

---

## Layouts

The script reads `terminal_width` from the agy payload and picks a layout automatically.

**Wide (>= 120 cols)**
```
⚙ WORKING / Gemini 2.5 Pro / my-project (main*)  │  ctx ████░·········· 30.0% · artifacts 2 · subagents 1
plan: Google AI Pro
gemini 5h ●●●○○○○○○○  28%  ⟳ 18:00
gemini 7d ●●○○○○○○○○  15%  ⟳ jul 11, 08:00
```

**Medium (>= 100 cols)**
```
╭─ ⚙ WORKING / Gemini 2.5 Pro / my-project (main*)
╰─ ctx ████░·········· 30.0% · artifacts 2 · subagents 1
plan: Google AI Pro
gemini 5h ●●●○○○○○○○  28%  ⟳ 18:00
gemini 7d ●●○○○○○○○○  15%  ⟳ jul 11, 08:00
```

**Narrow (< 100 cols)**
```
╭─ ⚙ WORKING / Gemini 2.5 Pro
├─ my-project (main*)
├─ ctx ████░·········· 30.0%
╰─ artifacts 2 · subagents 1 · tasks 0 · sandbox ON
plan: Google AI Pro
gemini 5h ●●●○○○○○○○  28%  ⟳ 18:00
gemini 7d ●●○○○○○○○○  15%  ⟳ jul 11, 08:00
```

---

## State indicators

| State | Badge |
|---|---|
| idle | `● READY` |
| thinking | `◆ THINKING` |
| working | `⚙ WORKING` |
| tool use | `🔧 TOOL` |
| other | `⏳ <STATE>` |

---

## Installation

**Windows (PowerShell)**

```powershell
powershell -NoProfile -File ./bin/install.ps1
```

Copies the script to `~/.gemini/statusline.ps1` and updates `~/.gemini/antigravity-cli/settings.json`.

**macOS / Linux (bash)**

```bash
bash ./bin/install.sh
```

Copies the script to `~/.gemini/statusline.sh` and updates `~/.gemini/antigravity-cli/settings.json`.

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

| Option | Default | What it does |
|---|---|---|
| `show_quota` | `true` | Show 5h and weekly quota bars |
| `show_additional_stats` | `true` | Show artifacts, subagents, tasks, sandbox |
| `hide_zero_stats` | `true` | Hide stats that are zero |
| `show_state_indicator` | `true` | Show the state badge |

---

## Dependencies

| Platform | Requirements |
|---|---|
| Windows | PowerShell 5.1+, no external dependencies |
| macOS / Linux | bash, jq |

The `.sh` script handles both GNU `date` (Linux) and BSD `date` (macOS) for reset time formatting.

---

## Credits

- [Ranteck/agy-statusline](https://github.com/Ranteck/agy-statusline) for the quota tracking approach
- [antigravity-cli examples](https://github.com/google-antigravity/antigravity-cli/tree/main/examples/statusline) for the original statusline structure
