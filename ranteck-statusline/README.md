# agy-statusline

Status line for the **Antigravity CLI** (`agy`) — displays the active model, session context usage, working directory/git branch, and real-time quota consumption.

## What it shows

```
Claude Sonnet 4.6 (Thinking) │ ✍️  27% │ my-project (main*) │ Google AI Pro

claude 5h ●●○○○○○○○○  21% ⟳ 20:40
claude 7d ●○○○○○○○○○  16% ⟳ jul 4, 20:57
```

| Field                | Description                                                |
| -------------------- | ---------------------------------------------------------- |
| Model                | Active model for the current session                       |
| `✍️ %`               | Context window usage for the current session               |
| Directory (branch\*) | Working directory + git branch (`*` = uncommitted changes) |
| Plan                 | Account tier (Google AI Pro, etc.)                         |
| `claude/gemini 5h`   | 5-hour rolling quota for the active model pool             |
| `claude/gemini 7d`   | Weekly quota for the active model pool                     |

> The quota pool shown (`claude` or `gemini`) is automatically detected based on the active model — no configuration needed.

## Requirements

- [`jq`](https://jqlang.github.io/jq/) — for JSON parsing
- `git` — for branch info
- `agy` (Antigravity CLI) installed and configured

## Installation

```bash
git clone https://github.com/your-username/agy-statusline
cd agy-statusline
bash bin/install.sh
```

Restart `agy` to see the status line.

## Uninstall

```bash
bash bin/uninstall.sh
```

This restores your previous statusline (if any) and removes the `statusLine` entry from `settings.json`.

## Project structure

```
agy-statusline/
├── bin/
│   ├── statusline.sh   # Main script (copied to ~/.gemini/)
│   ├── install.sh      # Installer
│   └── uninstall.sh    # Uninstaller
└── README.md
```

## How it works

`agy` runs the command configured under `statusLine` in `settings.json`, passing the current session state as JSON via stdin. The script parses it and returns ANSI-colored text for the terminal.

The installer configures the following in `~/.gemini/antigravity-cli/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "bash \"$HOME/.gemini/statusline.sh\"",
  "enabled": true
}
```

You can also toggle the status line at any time from within `agy` using `/statusline`.
