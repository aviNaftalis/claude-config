#!/bin/bash
# Rich Claude Code statusline.
# Reads Claude Code status JSON from stdin, emits a single colored line.

set -u

INPUT=$(cat)

# --- parse fields (jq with defaults) ---
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "?"')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // "?"')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.project_dir // ""')
LINES_ADD=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // 0')
OUTPUT_STYLE=$(echo "$INPUT" | jq -r '.output_style.name // ""')
VERSION=$(echo "$INPUT" | jq -r '.version // ""')

# --- token / rate-limit fields ---
CTX_USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty')
FIVE_HR_PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_HR_RESET=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_DAY_PCT=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_DAY_RESET=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- helper: format seconds-until-reset compactly (e.g. "2h14m", "3d7h", "42m") ---
fmt_eta() {
  local target="$1" now delta d h m
  now=$(date +%s)
  delta=$(( target - now ))
  if [ "$delta" -le 0 ]; then echo "now"; return; fi
  d=$(( delta / 86400 ))
  h=$(( (delta % 86400) / 3600 ))
  m=$(( (delta % 3600) / 60 ))
  if   [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else                       echo "${m}m"
  fi
}

# --- colors ---
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_BLUE=$'\033[38;5;39m'
C_CYAN=$'\033[38;5;45m'
C_GREEN=$'\033[38;5;42m'
C_YELLOW=$'\033[38;5;220m'
C_ORANGE=$'\033[38;5;172m'
C_RED=$'\033[38;5;203m'
C_PURPLE=$'\033[38;5;141m'
C_GRAY=$'\033[38;5;244m'

# --- cwd shortened (basename, or ~ prefix) ---
CWD_SHORT="$CWD"
[ -n "$CWD" ] && CWD_SHORT="${CWD/#$HOME/\~}"

# --- git info ---
GIT_SEG=""
if command -v git >/dev/null 2>&1 && [ -d "$CWD" ]; then
  BRANCH=$(git -C "$CWD" symbolic-ref --short HEAD 2>/dev/null || git -C "$CWD" rev-parse --short HEAD 2>/dev/null || true)
  if [ -n "$BRANCH" ]; then
    DIRTY=""
    if ! git -C "$CWD" diff --quiet --ignore-submodules 2>/dev/null || \
       ! git -C "$CWD" diff --cached --quiet --ignore-submodules 2>/dev/null; then
      DIRTY="${C_YELLOW}*${C_RESET}"
    fi
    UNTRACKED=$(git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null | head -1)
    [ -n "$UNTRACKED" ] && DIRTY="${DIRTY}${C_RED}?${C_RESET}"
    # ahead/behind vs upstream
    AB=$(git -C "$CWD" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null || echo "")
    AHEAD_BEHIND=""
    if [ -n "$AB" ]; then
      BEHIND=$(echo "$AB" | awk '{print $1}')
      AHEAD=$(echo "$AB" | awk '{print $2}')
      [ "${AHEAD:-0}" -gt 0 ] 2>/dev/null && AHEAD_BEHIND="${AHEAD_BEHIND}${C_GREEN}↑${AHEAD}${C_RESET}"
      [ "${BEHIND:-0}" -gt 0 ] 2>/dev/null && AHEAD_BEHIND="${AHEAD_BEHIND}${C_RED}↓${BEHIND}${C_RESET}"
    fi
    GIT_SEG=" ${C_PURPLE} ${BRANCH}${C_RESET}${DIRTY}${AHEAD_BEHIND}"
  fi
fi

# --- lines changed ---
LINES_SEG=""
if [ "${LINES_ADD:-0}" != "0" ] || [ "${LINES_DEL:-0}" != "0" ]; then
  LINES_SEG=" ${C_GREEN}+${LINES_ADD}${C_RESET}${C_GRAY}/${C_RESET}${C_RED}-${LINES_DEL}${C_RESET}"
fi

# --- context window used % ---
CTX_SEG=""
if [ -n "$CTX_USED_PCT" ]; then
  CTX_INT=$(printf '%.0f' "$CTX_USED_PCT")
  if   [ "$CTX_INT" -ge 85 ]; then CTX_COLOR="$C_RED"
  elif [ "$CTX_INT" -ge 60 ]; then CTX_COLOR="$C_ORANGE"
  elif [ "$CTX_INT" -ge 30 ]; then CTX_COLOR="$C_YELLOW"
  else                              CTX_COLOR="$C_GREEN"
  fi
  CTX_SEG=" ${CTX_COLOR}ctx:${CTX_INT}%${C_RESET}"
fi

# --- rate limit segments ---
FIVE_HR_SEG=""
if [ -n "$FIVE_HR_PCT" ]; then
  PCT=$(printf '%.0f' "$FIVE_HR_PCT")
  if   [ "$PCT" -ge 85 ]; then RL_COLOR="$C_RED"
  elif [ "$PCT" -ge 60 ]; then RL_COLOR="$C_ORANGE"
  else                          RL_COLOR="$C_CYAN"
  fi
  FIVE_HR_ETA=""
  [ -n "$FIVE_HR_RESET" ] && FIVE_HR_ETA="${C_DIM}→$(fmt_eta "$FIVE_HR_RESET")${C_RESET}"
  FIVE_HR_SEG=" ${RL_COLOR}5h:${PCT}%${C_RESET}${FIVE_HR_ETA}"
fi

SEVEN_DAY_SEG=""
if [ -n "$SEVEN_DAY_PCT" ]; then
  PCT=$(printf '%.0f' "$SEVEN_DAY_PCT")
  if   [ "$PCT" -ge 85 ]; then RL_COLOR="$C_RED"
  elif [ "$PCT" -ge 60 ]; then RL_COLOR="$C_ORANGE"
  else                          RL_COLOR="$C_CYAN"
  fi
  SEVEN_DAY_ETA=""
  [ -n "$SEVEN_DAY_RESET" ] && SEVEN_DAY_ETA="${C_DIM}→$(fmt_eta "$SEVEN_DAY_RESET")${C_RESET}"
  SEVEN_DAY_SEG=" ${RL_COLOR}7d:${PCT}%${C_RESET}${SEVEN_DAY_ETA}"
fi

# --- caveman badge ---
CAVE_SEG=""
CAVE_FLAG="$HOME/.claude/.caveman-active"
if [ -f "$CAVE_FLAG" ]; then
  MODE=$(cat "$CAVE_FLAG" 2>/dev/null)
  [ -z "$MODE" ] && MODE="full"
  SUFFIX=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
  CAVE_SEG=" ${C_ORANGE}[CAVEMAN:${SUFFIX}]${C_RESET}"
fi

# --- output style badge (if not default) ---
STYLE_SEG=""
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ] && [ "$OUTPUT_STYLE" != "null" ]; then
  STYLE_SEG=" ${C_CYAN}[${OUTPUT_STYLE}]${C_RESET}"
fi

# --- final line ---
printf '%b %s%b  %b%s%b%b%b%b%b%b%b%b%b%b' \
  "${C_BLUE}${C_BOLD}" "$MODEL" "${C_RESET}" \
  "${C_CYAN}" "$CWD_SHORT" "${C_RESET}" \
  "${GIT_SEG}" \
  "$CTX_SEG" "$FIVE_HR_SEG" "$SEVEN_DAY_SEG" \
  "$LINES_SEG" "$CAVE_SEG" "$STYLE_SEG"
