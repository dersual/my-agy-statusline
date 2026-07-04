#!/bin/bash
set -f

# ─── Read Stdin ─────────────────────────────────────────────────────────────
input=$(cat)
if [ -z "$input" ]; then
    printf "agy"
    exit 0
fi

# ─── Parse JSON from stdin (Single jq pass for performance) ──────────────────
{
  read -r STATE
  read -r USED_PCT
  read -r VCS_BRANCH
  read -r VCS_DIRTY
  read -r SANDBOX
  read -r ARTIFACTS
  read -r SUBAGENTS
  read -r BG_TASKS
  read -r MODEL_NAME
  read -r MODEL_ID
  read -r PLAN_TIER
  read -r COLS
  read -r CWD
  read -r Q_3P_5H_REM
  read -r Q_3P_5H_RESET
  read -r Q_3P_WK_REM
  read -r Q_3P_WK_RESET
  read -r Q_GEM_5H_REM
  read -r Q_GEM_5H_RESET
  read -r Q_GEM_WK_REM
  read -r Q_GEM_WK_RESET
} <<< "$(
  jq -r '
    (.agent_state // "idle"),
    (.context_window.used_percentage // 0),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.sandbox.enabled // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.display_name // ""),
    (.model.id // ""),
    (.plan_tier // ""),
    (.terminal_width // 80),
    (.cwd // ""),
    (.quota["3p-5h"].remaining_fraction // "null"),
    (.quota["3p-5h"].reset_time // "null"),
    (.quota["3p-weekly"].remaining_fraction // "null"),
    (.quota["3p-weekly"].reset_time // "null"),
    (.quota["gemini-5h"].remaining_fraction // "null"),
    (.quota["gemini-5h"].reset_time // "null"),
    (.quota["gemini-weekly"].remaining_fraction // "null"),
    (.quota["gemini-weekly"].reset_time // "null")
  ' <<< "$input" 2>/dev/null || printf "idle\n0\n\nfalse\nfalse\n0\n0\n0\n\n\n\n80\n\nnull\nnull\nnull\nnull\nnull\nnull\nnull\nnull\n"
)"

# ─── Configuration Loader (Optional ~/.gemini/statusline.json) ───────────────
CONFIG_PATH="$HOME/.gemini/statusline.json"
show_quota=true
show_additional_stats=true
hide_zero_stats=true
show_state_indicator=true

if [ -f "$CONFIG_PATH" ]; then
    eval "$(jq -r '
      "show_quota=\(.show_quota // true);",
      "show_additional_stats=\(.show_additional_stats // true);",
      "hide_zero_stats=\(.hide_zero_stats // true);",
      "show_state_indicator=\(.show_state_indicator // true);"
    ' "$CONFIG_PATH" 2>/dev/null || true)"
fi

# ─── ANSI Colors & Formatting (Standard 16 colors) ───────────────────────────
R="\033[0m"         # Reset
B="\033[1m"         # Bold
D="\033[2m"         # Dim
I="\033[3m"         # Italic

FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_CYAN="\033[36m"
FG_MAGENTA="\033[35m"
FG_WHITE="\033[37m"
FG_GRAY="\033[90m"
FG_BRIGHT_RED="\033[91m"
FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"
FG_BRIGHT_BLUE="\033[94m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"
FG_BRIGHT_WHITE="\033[97m"

NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# Resolve CWD basename
if [ -z "$CWD" ] || [ "$CWD" = "null" ]; then
    CWD=$(pwd)
fi
DIRNAME=$(basename "$CWD")

# ─── Helpers ─────────────────────────────────────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "%b" "$FG_BRIGHT_RED"
    elif [ "$pct" -ge 70 ]; then printf "%b" "$FG_BRIGHT_YELLOW"
    elif [ "$pct" -ge 50 ]; then printf "%b" "$FG_BRIGHT_CYAN"
    else printf "%b" "$FG_BRIGHT_GREEN"
    fi
}

build_quota_bar() {
    local pct=$1
    local width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( (pct * width) / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done

    printf "%b" "${bar_color}${filled_str}${FG_GRAY}${empty_str}${R}"
}

format_reset_time() {
    local reset_iso=$1
    local style=$2  # "time" or "datetime"
    [ -z "$reset_iso" ] || [ "$reset_iso" = "null" ] && return

    local epoch=""
    if date -d "$reset_iso" +%s >/dev/null 2>&1; then
        epoch=$(date -d "$reset_iso" +%s 2>/dev/null)
    elif date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_iso" +%s >/dev/null 2>&1; then
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$reset_iso" +%s 2>/dev/null)
    elif date -j -f "%Y-%m-%dT%H:%M:%S%z" "$reset_iso" +%s >/dev/null 2>&1; then
        local clean_iso
        clean_iso=$(echo "$reset_iso" | sed 's/\([+-][0-9][0-9]\):\([0-9][0-9]\)/\1\2/')
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean_iso" +%s 2>/dev/null)
    fi

    [ -z "$epoch" ] && return

    local result=""
    if date --version >/dev/null 2>&1; then
        if [ "$style" = "time" ]; then
            result=$(date -d "@$epoch" +"%H:%M" 2>/dev/null)
        else
            result=$(date -d "@$epoch" +"%b %-d, %H:%M" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        fi
    else
        if [ "$style" = "time" ]; then
            result=$(date -r "$epoch" +"%H:%M" 2>/dev/null)
        else
            result=$(date -r "$epoch" +"%b %e, %H:%M" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/  */ /g')
        fi
    fi

    printf "%s" "$result"
}

# ─── LINE 1: State, Model, VCS Branch, Plan ──────────────────────────────────
S=""
if [ "$show_state_indicator" = true ]; then
    case "$STATE" in
        idle)     S="${FG_BRIGHT_GREEN}${B}● READY${R}" ;;
        thinking) S="${FG_BRIGHT_YELLOW}${B}◆ THINKING${R}" ;;
        working)  S="${FG_BRIGHT_CYAN}${B}⚙ WORKING${R}" ;;
        tool_use) S="${FG_BRIGHT_MAGENTA}${B}🔧 TOOL${R}" ;;
        *)        S="${FG_WHITE}${B}⏳ $(echo "$STATE" | tr '[:lower:]' '[:upper:]')${R}" ;;
    esac
fi

DBlock="${FG_BRIGHT_CYAN}${DIRNAME}${R}"
if [ -n "$VCS_BRANCH" ] && [ "$VCS_BRANCH" != "null" ]; then
    if [ "$VCS_DIRTY" = "true" ]; then
        DBlock+=" ${FG_BRIGHT_GREEN}(${FG_BRIGHT_RED}${VCS_BRANCH}${FG_BRIGHT_YELLOW}*${FG_BRIGHT_GREEN})${R}"
    else
        DBlock+=" ${FG_BRIGHT_GREEN}(${FG_BRIGHT_BLUE}${VCS_BRANCH}${FG_BRIGHT_GREEN})${R}"
    fi
fi

parts=()
[ -n "$S" ] && parts+=("$S")
[ -n "$MODEL_NAME" ] && [ "$MODEL_NAME" != "null" ] && parts+=("${FG_BRIGHT_MAGENTA}${I}${MODEL_NAME}${R}")
[ -n "$DBlock" ] && parts+=("$DBlock")
[ -n "$PLAN_TIER" ] && [ "$PLAN_TIER" != "null" ] && parts+=("${FG_GRAY}${PLAN_TIER}${R}")

LINE1=""
for ((i=0; i<${#parts[@]}; i++)); do
    if [ "$i" -gt 0 ]; then
        LINE1+="${FG_GRAY} ╱ ${R}"
    fi
    LINE1+="${parts[$i]}"
done

# ─── LINE 2: Context Bar & Stats ─────────────────────────────────────────────
BAR_LEN=15
PCT_INT=$(printf "%.0f" "$USED_PCT" 2>/dev/null || echo 0)
FILLED=$(( (PCT_INT * BAR_LEN) / 100 ))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

if [ "$PCT_INT" -ge 90 ]; then
    BAR_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge 60 ]; then
    BAR_COLOR="$FG_BRIGHT_YELLOW"
else
    BAR_COLOR="$FG_BRIGHT_WHITE"
fi

BAR=""
for ((i=0; i<BAR_LEN; i++)); do
    if [ "$i" -lt "$FILLED" ]; then
        BAR="${BAR}█"
    elif [ "$i" -eq "$FILLED" ]; then
        if [ "$REMAINDER" -ge 75 ]; then BAR="${BAR}▓"
        elif [ "$REMAINDER" -ge 50 ]; then BAR="${BAR}▒"
        elif [ "$REMAINDER" -ge 25 ]; then BAR="${BAR}░"
        else BAR="${BAR}·"
        fi
    else
        BAR="${BAR}·"
    fi
done

PCT_FMT=$(printf "%.1f" "$USED_PCT" 2>/dev/null || echo "0.0")
CTX="${FG_GRAY}ctx ${BAR_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"

stat_parts=()
stat_parts+=("$CTX")

if [ "$show_additional_stats" = true ]; then
    if [ "$hide_zero_stats" = false ] || [ "$ARTIFACTS" -gt 0 ]; then
        stat_parts+=("${FG_GRAY}artifacts ${NUM_COLOR}${ARTIFACTS}${R}")
    fi
    if [ "$hide_zero_stats" = false ] || [ "$SUBAGENTS" -gt 0 ]; then
        stat_parts+=("${FG_GRAY}subagents ${NUM_COLOR}${SUBAGENTS}${R}")
    fi
    if [ "$hide_zero_stats" = false ] || [ "$BG_TASKS" -gt 0 ]; then
        stat_parts+=("${FG_GRAY}tasks ${NUM_COLOR}${BG_TASKS}${R}")
    fi
    if [ "$SANDBOX" = "true" ]; then
        stat_parts+=("${FG_GRAY}sandbox ${FG_BRIGHT_GREEN}${B}ON${R}")
    elif [ "$hide_zero_stats" = false ]; then
        stat_parts+=("${FG_GRAY}sandbox off${R}")
    fi
fi

DOT="${FG_GRAY} · ${R}"
LINE2=" "
for ((i=0; i<${#stat_parts[@]}; i++)); do
    if [ "$i" -gt 0 ]; then
        LINE2+="$DOT"
    fi
    LINE2+="${stat_parts[$i]}"
done

# ─── Quota Progress Bars ─────────────────────────────────────────────────────
quota_lines=()

if [ "$show_quota" = true ]; then
    MODEL_ID_LOWER=$(echo "$MODEL_ID" | tr '[:upper:]' '[:lower:]')
    if echo "$MODEL_ID_LOWER" | grep -qiE 'claude|anthropic|3p'; then
        Q_5H_REM="$Q_3P_5H_REM"
        Q_5H_RESET="$Q_3P_5H_RESET"
        Q_WK_REM="$Q_3P_WK_REM"
        Q_WK_RESET="$Q_3P_WK_RESET"
        pool_label="claude"
    else
        Q_5H_REM="$Q_GEM_5H_REM"
        Q_5H_RESET="$Q_GEM_5H_RESET"
        Q_WK_REM="$Q_GEM_WK_REM"
        Q_WK_RESET="$Q_GEM_WK_RESET"
        pool_label="gemini"
    fi

    # 5h Quota
    if [ -n "$Q_5H_REM" ] && [ "$Q_5H_REM" != "null" ]; then
        pct=$(echo "$Q_5H_REM" | awk '{printf "%.0f", (1 - $1) * 100}' 2>/dev/null || echo 0)
        qBar=$(build_quota_bar "$pct" 10)
        pct_fmt=$(printf "%3d" "$pct")
        reset_fmt=$(format_reset_time "$Q_5H_RESET" "time")
        pColor=$(color_for_pct "$pct")
        
        qLine="${FG_WHITE}${pool_label} 5h${R} ${qBar} ${pColor}${pct_fmt}%${R}"
        [ -n "$reset_fmt" ] && qLine+=" ${FG_GRAY}⟳${R} ${FG_WHITE}${reset_fmt}${R}"
        quota_lines+=("$qLine")
    fi

    # Weekly Quota
    if [ -n "$Q_WK_REM" ] && [ "$Q_WK_REM" != "null" ]; then
        pct=$(echo "$Q_WK_REM" | awk '{printf "%.0f", (1 - $1) * 100}' 2>/dev/null || echo 0)
        qBar=$(build_quota_bar "$pct" 10)
        pct_fmt=$(printf "%3d" "$pct")
        reset_fmt=$(format_reset_time "$Q_WK_RESET" "datetime")
        pColor=$(color_for_pct "$pct")
        
        qLine="${FG_WHITE}${pool_label} 7d${R} ${qBar} ${pColor}${pct_fmt}%${R}"
        [ -n "$reset_fmt" ] && qLine+=" ${FG_GRAY}⟳${R} ${FG_WHITE}${reset_fmt}${R}"
        quota_lines+=("$qLine")
    fi
fi

# ─── Render Layout Based on Terminal Width ───────────────────────────────────
if [ "$COLS" -ge 120 ]; then
    # Wide layout
    echo -e "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge 80 ]; then
    # Medium layout
    echo -e "${FG_GRAY}╭─${R} ${LINE1}"
    echo -e "${FG_GRAY}╰─${R}${LINE2}"
else
    # Narrow layout
    echo -e "${LINE1}"
    echo -e "${LINE2}"
fi

for qLine in "${quota_lines[@]}"; do
    echo -e "$qLine"
done

# Add a trailing empty line for padding at the bottom of the terminal
echo ""

exit 0
