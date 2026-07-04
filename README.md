# Unified Cross-Platform AGY Statusline

A customizable, dynamic, and adaptive statusline for the Google Antigravity CLI (`agy`). It merges the rolling quota tracking of `Ranteck/agy-statusline` with the rich agent metrics, state indicators, and automatic layout adaptability of the official `antigravity-cli` example.

Designed using **SOLID principles**, it operates with **zero external language runtimes** (no Python or Node.js required) by providing native shell scripts for all major operating systems.

---

## Features

1. **Fully Adaptive Terminal Width Layout**:
   - **Wide Terminals (`>= 120` columns)**: Combines all details, state badges, context window size, and active metrics on a single sleek line, with quota tracking below.
   - **Medium Terminals (`>= 80` columns)**: Formats metrics in a bordered box layout.
   - **Narrow Terminals (`< 80` columns)**: Arranges elements in a compact, multi-line vertical stack to avoid text wrapping.

2. **Real-time Rolling Quota Tracking**:
   - Displays rolling 5-hour and weekly (7-day) quotas with visual progress bars.
   - Automatically detects the active model pool (`claude` vs. `gemini`) and renders the correct quota.
   - Computes reset times in your local timezone.

3. **Smart Auto-Hiding (Zero-Noise)**:
   - Elements like `artifacts`, `subagents`, and background `tasks` are automatically hidden when their count is `0`. They dynamically appear as soon as they become active.

4. **100% Configurable**:
   - Customize behavior via a simple `~/.gemini/statusline.json` file. No script editing is required.

---

## Installation

### For Windows (PowerShell)
1. Open PowerShell and run the installer script:
   ```powershell
   powershell -NoProfile -File ./bin/install.ps1
   ```
   *This will copy the script to `~/.gemini/statusline.ps1` and configure your `~/.gemini/antigravity-cli/settings.json` to run it.*

### For macOS & Linux (Bash)
1. Open your terminal and run the installer script:
   ```bash
   bash ./bin/install.sh
   ```
   *This will copy the script to `~/.gemini/statusline.sh` and update your `~/.gemini/antigravity-cli/settings.json`.*

---

## Configuration

An optional configuration file is supported at `~/.gemini/statusline.json`. You can create or edit this file to toggle specific features:

```json
{
  "show_quota": true,
  "show_additional_stats": true,
  "hide_zero_stats": true,
  "show_state_indicator": true
}
```

### Options:
* **`show_quota`** (`true`/`false`): Toggle 5-hour and weekly quota progress bars.
* **`show_additional_stats`** (`true`/`false`): Master toggle for artifacts, subagents, background tasks, and sandbox status.
* **`hide_zero_stats`** (`true`/`false`): When `true`, hides metrics whose count is `0`.
* **`show_state_indicator`** (`true`/`false`): Toggle the state badge (e.g. `● READY`, `◆ THINKING`, `⚙ WORKING`).

---

## Technical Details & Dependencies

* **Windows**: Works natively using built-in PowerShell 5.1+ and `.NET` assemblies. Zero dependencies.
* **macOS & Linux**: Uses `bash` and `jq` (required). Handles date conversions automatically for both GNU `date` (Linux) and BSD `date` (macOS).
* **CI Testing**: Cross-platform correctness is validated on every push across Ubuntu, macOS, and Windows via GitHub Actions.
