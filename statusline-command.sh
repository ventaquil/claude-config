#!/usr/bin/env bash
set -Eeuo pipefail
# Claude Code statusline: context / 5h / 7d usage % from stdin JSON on the left, model + effort on the right.

error_handler() {
    printf 'statusline: line %s: %s exited %s\n' "$2" "$3" "$1" >&2
}
trap 'error_handler "$?" "${LINENO}" "${BASH_COMMAND}"' ERR

main() {
    local input
    input=$(cat)

    local -a vals
    mapfile -t vals < <(echo "$input" | jq -r '.context_window.used_percentage // "", .rate_limits.five_hour.used_percentage // "", .rate_limits.seven_day.used_percentage // "", .model.display_name // "", .effort.level // ""' 2>/dev/null || true)

    local ctx=${vals[0]:-}
    local five=${vals[1]:-}
    local week=${vals[2]:-}
    local model=${vals[3]:-}
    local effort=${vals[4]:-}

    # ctx is the only bold segment; session/weekly stay dim (not bold).
    # A non-numeric value drops only its own segment instead of aborting the line under set -e.
    local -a parts=()
    local seg
    if [[ -n "$ctx" ]] && seg=$(printf '\033[1mctx %.0f%%\033[0m' "$ctx" 2>/dev/null); then parts+=("$seg"); fi
    if [[ -n "$five" ]] && seg=$(printf '\033[2msession %.0f%%\033[0m' "$five" 2>/dev/null); then parts+=("$seg"); fi
    if [[ -n "$week" ]] && seg=$(printf '\033[2mweekly %.0f%%\033[0m' "$week" 2>/dev/null); then parts+=("$seg"); fi

    local sep=$'\033[2m|\033[0m'

    local left=""
    local p
    for p in "${parts[@]}"; do
        if [[ -z "$left" ]]; then
            left="$p"
        else
            left="$left $sep $p"
        fi
    done

    local right=""
    [[ -n "$model" ]] && right=$'\033[2m'"$model"$'\033[0m'
    if [[ -n "$effort" ]]; then
        effort=$'\033[2m'"$effort"$'\033[0m'
        if [[ -n "$right" ]]; then
            right="$right $sep $effort"
        else
            right="$effort"
        fi
    fi

    if [[ -z "$right" ]]; then
        printf '%s' "$left"
        return 0
    fi

    local cols
    cols=$(tput cols 2>/dev/null || echo 0)
    if [[ "$cols" -gt 0 ]]; then
        # Right-align using visible (escape-stripped) lengths.
        local left_len right_len pad
        left_len=$(printf '%s' "$left" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
        right_len=$(printf '%s' "$right" | sed 's/\x1b\[[0-9;]*m//g' | wc -m)
        # Claude Code indents the statusline by a few columns, so a full-width
        # line gets truncated by the renderer — reserve a margin.
        pad=$((cols - left_len - right_len - 4))
        [[ "$pad" -lt 1 ]] && pad=1
        printf '%s%*s%s' "$left" "$pad" "" "$right"
    elif [[ -n "$left" ]]; then
        printf '%s %s %s' "$left" "$sep" "$right"
    else
        printf '%s' "$right"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
