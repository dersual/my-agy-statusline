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

# ─── Configuration Constants ──────────────────────────────────────────────────
CONFIG_LAYOUT_WIDE_COLS=120
CONFIG_LAYOUT_MED_COLS=100
CONFIG_BAR_LEN_CTX=15
charSlash="/"
CONFIG_BAR_LEN_QUOTA=10
CONFIG_CTX_WARN_PCT=60
CONFIG_CTX_CRIT_PCT=90
CONFIG_QUOTA_INFO_PCT=50
CONFIG_QUOTA_WARN_PCT=70
CONFIG_QUOTA_CRIT_PCT=90

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

# ─── Fallback Git Branch Detection ───────────────────────────────────────────
if [ -z "$VCS_BRANCH" ] || [ "$VCS_BRANCH" = "null" ]; then
    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
        git_branch=$(git -C "$CWD" branch --show-current 2>/dev/null)
        if [ -n "$git_branch" ]; then
            VCS_BRANCH="$git_branch"
            git_status=$(git -C "$CWD" status --porcelain 2>/dev/null)
            if [ -n "$git_status" ]; then
                VCS_DIRTY="true"
            else
                VCS_DIRTY="false"
            fi
        fi
    fi
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge "$CONFIG_QUOTA_CRIT_PCT" ]; then printf "%b" "$FG_BRIGHT_RED"
    elif [ "$pct" -ge "$CONFIG_QUOTA_WARN_PCT" ]; then printf "%b" "$FG_BRIGHT_YELLOW"
    elif [ "$pct" -ge "$CONFIG_QUOTA_INFO_PCT" ]; then printf "%b" "$FG_BRIGHT_CYAN"
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

format_quota_line() {
    local label="$1"
    local rem="$2"
    local reset="$3"
    local style="$4"

    if [ -z "$rem" ] || [ "$rem" = "null" ]; then
        return 1
    fi

    local pct
    pct=$(echo "$rem" | awk '{printf "%.0f", (1 - $1) * 100}' 2>/dev/null || echo 0)
    local qBar
    qBar=$(build_quota_bar "$pct" "$CONFIG_BAR_LEN_QUOTA")
    local pct_fmt
    pct_fmt=$(printf "%3d" "$pct")
    local reset_fmt
    reset_fmt=$(format_reset_time "$reset" "$style")
    local pColor
    pColor=$(color_for_pct "$pct")
    
    local line="${FG_WHITE}${label}${R} ${qBar} ${pColor}${pct_fmt}%${R}"
    if [ -n "$reset_fmt" ]; then
        line+=" ${FG_GRAY}⟳${R} ${FG_WHITE}${reset_fmt}${R}"
    fi
    echo "$line"
    return 0
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

LINE1=""
for ((i=0; i<${#parts[@]}; i++)); do
    if [ "$i" -gt 0 ]; then
        LINE1+="${FG_GRAY} ${charSlash} ${R}"
    fi
    LINE1+="${parts[$i]}"
done

# ─── LINE 2: Context Bar & Stats ─────────────────────────────────────────────
PCT_INT=$(printf "%.0f" "$USED_PCT" 2>/dev/null || echo 0)
FILLED=$(( (PCT_INT * CONFIG_BAR_LEN_CTX) / 100 ))
REMAINDER=$(( (PCT_INT * CONFIG_BAR_LEN_CTX) % 100 ))

if [ "$PCT_INT" -ge "$CONFIG_CTX_CRIT_PCT" ]; then
    BAR_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge "$CONFIG_CTX_WARN_PCT" ]; then
    BAR_COLOR="$FG_BRIGHT_YELLOW"
else
    BAR_COLOR="$FG_BRIGHT_WHITE"
fi

BAR=""
for ((i=0; i<CONFIG_BAR_LEN_CTX; i++)); do
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
    if line_5h=$(format_quota_line "${pool_label} 5h" "$Q_5H_REM" "$Q_5H_RESET" "time"); then
        quota_lines+=("$line_5h")
    fi

    # Weekly Quota
    if line_wk=$(format_quota_line "${pool_label} 7d" "$Q_WK_REM" "$Q_WK_RESET" "datetime"); then
        quota_lines+=("$line_wk")
    fi
fi

if [ -n "$PLAN_TIER" ] && [ "$PLAN_TIER" != "null" ]; then
    quota_lines=("${FG_GRAY}plan:${R} ${FG_WHITE}${PLAN_TIER}${R}" "${quota_lines[@]}")
fi

# ─── Render Layout Based on Terminal Width ───────────────────────────────────
if [ "$COLS" -ge "$CONFIG_LAYOUT_WIDE_COLS" ]; then
    # Wide layout
    echo -e "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge "$CONFIG_LAYOUT_MED_COLS" ]; then
    # Medium layout
    echo -e "${FG_GRAY}╭─${R} ${LINE1}"
    echo -e "${FG_GRAY}╰─${R}${LINE2}"
else
    # Narrow layout: split into 4 structured lines
    parts_1a=()
    [ -n "$S" ] && parts_1a+=("$S")
    [ -n "$MODEL_NAME" ] && [ "$MODEL_NAME" != "null" ] && parts_1a+=("${FG_BRIGHT_MAGENTA}${I}${MODEL_NAME}${R}")
    
    LINE1A=""
    for ((i=0; i<${#parts_1a[@]}; i++)); do
        if [ "$i" -gt 0 ]; then
            LINE1A+="${FG_GRAY} ${charSlash} ${R}"
        fi
        LINE1A+="${parts_1a[$i]}"
    done
    
    LINE1B="$DBlock"
    LINE2A=" ${CTX}"
    
    stats_only=()
    for ((i=1; i<${#stat_parts[@]}; i++)); do
        stats_only+=("${stat_parts[$i]}")
    done
    
    if [ "${#stats_only[@]}" -gt 0 ]; then
        LINE2B=" "
        for ((i=0; i<${#stats_only[@]}; i++)); do
            if [ "$i" -gt 0 ]; then
                LINE2B+="$DOT"
            fi
              LINE2B+="${stats_only[$i]}"
        done
        
        echo -e "${FG_GRAY}╭─${R} ${LINE1A}"
        echo -e "${FG_GRAY}├─${R} ${LINE1B}"
        echo -e "${FG_GRAY}├─${R}${LINE2A}"
        echo -e "${FG_GRAY}╰─${R}${LINE2B}"
    else
        echo -e "${FG_GRAY}╭─${R} ${LINE1A}"
        echo -e "${FG_GRAY}├─${R} ${LINE1B}"
        echo -e "${FG_GRAY}╰─${R}${LINE2A}"
    fi
fi

for qLine in "${quota_lines[@]}"; do
    echo -e "$qLine"
done

# Add a trailing empty line for padding at the bottom of the terminal
echo ""

exit 0
