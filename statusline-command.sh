#!/bin/bash
# Status line: simplified percentage usage for each usage kind available on stdin
# (context window, 5h rate limit, 7d rate limit).

input=$(cat)

mapfile -t vals < <(echo "$input" | jq -r '.context_window.used_percentage // "", .rate_limits.five_hour.used_percentage // "", .rate_limits.seven_day.used_percentage // ""')
ctx=${vals[0]}
five=${vals[1]}
week=${vals[2]}

parts=()
[ -n "$ctx" ] && parts+=("$(printf 'ctx %.0f%%' "$ctx")")
[ -n "$five" ] && parts+=("$(printf 'session %.0f%%' "$five")")
[ -n "$week" ] && parts+=("$(printf 'weekly %.0f%%' "$week")")

sep=$'\033[2m|\033[0m'

out=""
for p in "${parts[@]}"; do
    if [ -z "$out" ]; then
        out="$p"
    else
        out="$out $sep $p"
    fi
done

printf '\033[2m%s\033[0m' "$out"
