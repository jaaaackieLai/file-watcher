# lib/utils.sh - Terminal utilities and helpers

[[ -n "${_FW_UTILS_LOADED:-}" ]] && return
readonly _FW_UTILS_LOADED=1

die() {
    echo "Error: $1" >&2
    exit 1
}

cursor_hide() { printf '\033[?25l'; }
cursor_show() { printf '\033[?25h'; }
cursor_to()   { printf '\033[%d;%dH' "$1" "$2"; }
clear_screen() { printf '\033[2J\033[H'; }
clear_line()  { printf '\033[2K'; }
clear_below() { printf '\033[J'; }

get_term_size() {
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
}

# ---- Output buffering ----
_RENDER_BUF=""

buf_printf() {
    # shellcheck disable=SC2059
    _RENDER_BUF+="$(printf "$@")"
}

buf_cursor_to() {
    _RENDER_BUF+="$(printf '\033[%d;%dH' "$1" "$2")"
}

buf_clear_line() {
    _RENDER_BUF+=$'\033[2K'
}

buf_flush() {
    printf '%s' "$_RENDER_BUF"
    _RENDER_BUF=""
}

truncate_text() {
    local text="$1" max_len="$2"
    if (( ${#text} > max_len )); then
        echo "${text:0:$(( max_len - 1 ))}~"
    else
        echo "$text"
    fi
}
