#!/bin/bash

input=$(cat)
echo "$input" > /tmp/statusline-input.json

# Run a command with a time limit. macOS has no timeout(1) unless coreutils is
# installed, so fall back to running the command directly.
run_limited() {
  local secs=$1; shift
  if [[ -n "$TIMEOUT_BIN" ]]; then
    "$TIMEOUT_BIN" "$secs" "$@"
  else
    "$@"
  fi
}
TIMEOUT_BIN=$(command -v timeout || command -v gtimeout || true)

MODEL=$(echo "$input" | jq -r '.model.id')

# Print text with a per-character rainbow gradient (256-color).
rainbow() {
  local text=$1 colors=(196 208 226 46 51 33 129) i=0 ch
  while IFS= read -r -n1 ch; do
    [[ -z "$ch" ]] && continue
    printf '\e[1;38;5;%dm%s' "${colors[i % ${#colors[@]}]}" "$ch"
    ((i++))
  done <<< "$text"
  printf '\e[0m'
}

# Color the model name by tier: Fable rainbow, Opus red, Sonnet yellow,
# Haiku green. Matching is case-insensitive so it works on both the
# display_name ("Opus 5") and the id ("claude-opus-5[1m]").
color_model() {
  local name=$1 lower
  lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    *fable*)  rainbow "$name" ;;
    *opus*)   printf '\e[91m%s\e[0m' "$name" ;;
    *sonnet*) printf '\e[93m%s\e[0m' "$name" ;;
    *haiku*)  printf '\e[32m%s\e[0m' "$name" ;;
    *)        printf '%s' "$name" ;;
  esac
}

# Color the effort level: max rainbow, xhigh red, high orange, medium yellow,
# low green.
color_effort() {
  local effort=$1
  case "$effort" in
    max)    rainbow "$effort" ;;
    xhigh)  printf '\e[91m%s\e[0m' "$effort" ;;
    high)   printf '\e[38;5;214m%s\e[0m' "$effort" ;;
    medium) printf '\e[93m%s\e[0m' "$effort" ;;
    low)    printf '\e[32m%s\e[0m' "$effort" ;;
    *)      printf '%s' "$effort" ;;
  esac
}

# Color a percentage label using thresholds: >90 red, >80 orange, >70 yellow
color_pct() {
  local pct=$1
  if [[ "$pct" -gt 90 ]]; then
    printf '\e[91m%s%%\e[0m' "$pct"
  elif [[ "$pct" -gt 80 ]]; then
    printf '\e[38;5;214m%s%%\e[0m' "$pct"
  elif [[ "$pct" -gt 70 ]]; then
    printf '\e[93m%s%%\e[0m' "$pct"
  else
    printf '%s%%' "$pct"
  fi
}

# Color the context-usage group by absolute token count: yellow once we cross
# 100k tokens, red at 200k+. (Token thresholds so they trigger consistently on
# large windows, e.g. the 1M-token context.)
color_ctx() {
  local pct=$1 tokens=$2 text=$3
  if (( tokens >= 200000 )); then
    printf '\e[91m%s\e[0m' "$text"
  elif (( tokens >= 100000 )); then
    printf '\e[93m%s\e[0m' "$text"
  else
    printf '%s' "$text"
  fi
}

# Format time-until-reset from a Unix epoch timestamp (seconds).
# Returns "Xd Yh", "Xh Ym", or "Xm" depending on magnitude.
format_until() {
  local reset_epoch=$1
  [[ -z "$reset_epoch" || "$reset_epoch" == "null" ]] && return
  local now_epoch diff days hours mins
  now_epoch=$(date "+%s")
  diff=$(( reset_epoch - now_epoch ))
  (( diff < 0 )) && diff=0
  days=$(( diff / 86400 ))
  hours=$(( (diff % 86400) / 3600 ))
  mins=$(( (diff % 3600) / 60 ))
  if (( days > 0 )); then
    printf '%dd %dh' "$days" "$hours"
  elif (( hours > 0 )); then
    printf '%dh %dm' "$hours" "$mins"
  else
    printf '%dm' "$mins"
  fi
}

# Context window % and token count (rounded to nearest 1k)
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_TOKENS_RAW=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
CTX_TOKENS="$(( (CTX_TOKENS_RAW + 500) / 1000 ))k"

# Rate limits (absent when not Pro/Max or before first API call)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Effort level. Prefer the live value in the payload; settings.json only holds
# the saved default, so it goes stale after a mid-session /effort change.
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
[[ -z "$EFFORT" ]] && EFFORT=$(jq -r '.effortLevel // "medium"' ~/.claude/settings.json 2>/dev/null)

# Determine working directory
CWD=$(echo "$input" | jq -r '.cwd // empty')
[[ -z "$CWD" ]] && CWD=$(pwd)

# Project name (repo root basename, or cwd basename)
REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$REPO_ROOT" ]]; then
  PROJECT=$(basename "$REPO_ROOT")
else
  PROJECT=$(basename "$CWD")
fi

# Worktree name (Claude-managed or manual git worktree)
WORKTREE_NAME=$(echo "$input" | jq -r '.worktree.name // empty')
if [[ -z "$WORKTREE_NAME" && -n "$REPO_ROOT" ]]; then
  GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null)
  GIT_COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
  [[ "$GIT_DIR" != "$GIT_COMMON_DIR" ]] && WORKTREE_NAME=$(basename "$CWD")
fi

# Branch
BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')
[[ -z "$BRANCH" ]] && BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)

# Branch color, matching the git segment in .oh-my-posh.json:
#   clean tree  -> green
#   dirty tree  -> magenta (untracked files count as dirty)
#   rebase      -> red "Rebase~" prefix
BRANCH_STR="$BRANCH"
if [[ -n "$BRANCH" && -n "$REPO_ROOT" ]]; then
  GIT_COMMON_DIR=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [[ -d "$GIT_COMMON_DIR/rebase-merge" || -d "$GIT_COMMON_DIR/rebase-apply" ]]; then
    BRANCH_STR=$(printf '\e[31mRebase~ %s\e[0m' "$BRANCH")
  elif [[ -n "$(run_limited 1 git -C "$CWD" status --porcelain 2>/dev/null)" ]]; then
    BRANCH_STR=$(printf '\e[35m%s\e[0m' "$BRANCH")
  else
    BRANCH_STR=$(printf '\e[32m%s\e[0m' "$BRANCH")
  fi
fi

# PR (clickable OSC 8 hyperlink, omitted if no open PR)
PR_STR=""
if [[ -n "$REPO_ROOT" ]]; then
  PR_JSON=$(run_limited 2 gh pr view --json number,url 2>/dev/null)
  if [[ -n "$PR_JSON" ]]; then
    PR_NUM=$(echo "$PR_JSON" | jq -r '.number')
    PR_URL=$(echo "$PR_JSON" | jq -r '.url')
    PR_STR=$(printf '\e]8;;%s\e\\#%s\e]8;;\e\\' "$PR_URL" "$PR_NUM")
  fi
fi

# Host segment, matching the detection in .oh-my-posh.json:
#   CODER_USER set     -> blue "🔧 <user>"
#   SSH_CONNECTION set -> yellow hostname
#   otherwise (local)  -> plain hostname
HOSTNAME_SHORT=$(hostname -s 2>/dev/null)
if [[ -n "$CODER_USER" ]]; then
  HOST_STR=$(printf '\e[34m🔧 %s\e[0m' "$CODER_USER")
elif [[ -n "$SSH_CONNECTION" ]]; then
  HOST_STR=$(printf '\e[33m%s\e[0m' "$HOSTNAME_SHORT")
else
  HOST_STR="$HOSTNAME_SHORT"
fi

# Line 1: hostname | repo[:worktree] branch [#PR] | session name
LINE1="${HOST_STR} | ${PROJECT}"
[[ -n "$WORKTREE_NAME" ]] && LINE1="${LINE1}:${WORKTREE_NAME}"
[[ -n "$BRANCH" ]] && LINE1="${LINE1} ${BRANCH_STR}"
[[ -n "$PR_STR" ]] && LINE1="${LINE1} ${PR_STR}"

SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty')
if [[ -n "$SESSION_NAME" ]]; then
  LINE1="${LINE1} | $(printf '\e[38;5;250m%s\e[0m' "$SESSION_NAME")"
fi
echo "$LINE1"

# Line 2: {ctx%} ({tokens}) | model · effort | {5h%} ({until}) | {7d%} ({until})
LINE2="$(color_ctx "$CTX_PCT" "$CTX_TOKENS_RAW" "${CTX_PCT}% (${CTX_TOKENS})")"
LINE2="${LINE2} | $(color_model "$MODEL") · $(color_effort "$EFFORT")"

if [[ -n "$FIVE_H" ]]; then
  FH_PCT=$(printf '%.0f' "$FIVE_H")
  FH_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
  FH_UNTIL=$(format_until "$FH_RESET")
  LINE2="${LINE2} | $(color_pct "$FH_PCT")${FH_UNTIL:+ ($FH_UNTIL)}"
fi

if [[ -n "$SEVEN_D" ]]; then
  SD_PCT=$(printf '%.0f' "$SEVEN_D")
  SD_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
  SD_UNTIL=$(format_until "$SD_RESET")
  LINE2="${LINE2} | $(color_pct "$SD_PCT")${SD_UNTIL:+ ($SD_UNTIL)}"
fi

# Session cost in USD
COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [[ -n "$COST_USD" ]]; then
  LINE2="${LINE2} | $(printf '$%.2f' "$COST_USD")"
fi

echo "$LINE2"
