#!/bin/bash
# Status line: simplified percentage usage for each usage kind available on stdin
# (context window, 5h rate limit, 7d rate limit), plus model + effort on the right.

input=$(cat)

mapfile -t vals < <(echo "$input" | jq -r '.context_window.used_percentage // "", .rate_limits.five_hour.used_percentage // "", .rate_limits.seven_day.used_percentage // "", .model.display_name // "", .effort.level // ""')
ctx=${vals[0]}
five=${vals[1]}
week=${vals[2]}
model=${vals[3]}
effort=${vals[4]}

# ctx is the only bold segment; session/weekly stay dim (not bold).
parts=()
[ -n "$ctx" ] && parts+=("$(printf '\033[1mctx %.0f%%\033[0m' "$ctx")")
[ -n "$five" ] && parts+=("$(printf '\033[2msession %.0f%%\033[0m' "$five")")
[ -n "$week" ] && parts+=("$(printf '\033[2mweekly %.0f%%\033[0m' "$week")")

sep=$'\033[2m|\033[0m'

left=""
for p in "${parts[@]}"; do
    if [ -z "$left" ]; then
        left="$p"
    else
        left="$left $sep $p"
    fi
done

right=""
[ -n "$model" ] && right=$'\033[2m'"$model"$'\033[0m'
if [ -n "$effort" ]; then
    effort=$'\033[2m'"$effort"$'\033[0m'
    if [ -n "$right" ]; then
        right="$right $sep $effort"
    else
        right="$effort"
    fi
fi

if [ -z "$right" ]; then
    printf '%s' "$left"
    exit 0
fi

cols=$(tput cols 2>/dev/null || echo 0)
if [ "$cols" -gt 0 ]; then
    # Right-align using visible (escape-stripped) lengths.
    left_len=$(printf '%s' "$left" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
    right_len=$(printf '%s' "$right" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
    # Claude Code indents the statusline by a few columns, so a full-width
    # line gets truncated by the renderer — reserve a margin.
    pad=$((cols - left_len - right_len - 4))
    [ "$pad" -lt 1 ] && pad=1
    printf '%s%*s%s' "$left" "$pad" "" "$right"
elif [ -n "$left" ]; then
    printf '%s %s %s' "$left" "$sep" "$right"
else
    printf '%s' "$right"
fi
