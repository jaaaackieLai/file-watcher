# lib/render.sh - TUI rendering (buffered output)

[[ -n "${_FW_RENDER_LOADED:-}" ]] && return
readonly _FW_RENDER_LOADED=1

draw_header() {
    buf_cursor_to 1 1
    buf_clear_line
    buf_printf "${BOLD}${CYAN} file-watcher${RESET} ${DIM}v%s${RESET}" "$FW_VERSION"

    local display_dir
    display_dir=$(truncate_text "$WATCH_DIR" $(( TERM_COLS - 16 )))
    buf_cursor_to 2 1
    buf_clear_line
    buf_printf " ${DIM}path:${RESET} %s" "$display_dir"

    buf_cursor_to 3 1
    buf_clear_line
    local sep=""
    local max_w=$(( TERM_COLS - 2 ))
    local c
    for (( c = 0; c < max_w; c++ )); do sep+=$'\xe2\x94\x80'; done
    buf_printf " ${DIM}%s${RESET}" "$sep"
}

draw_tree() {
    local first_row=4
    local last_row=$(( TERM_ROWS - 3 ))
    local visible_lines=$(( last_row - first_row + 1 ))

    if (( FILE_COUNT == 0 )); then
        buf_cursor_to "$first_row" 1
        buf_clear_line
        buf_printf "  ${DIM}(empty)${RESET}"
        local r
        for (( r = first_row + 1; r <= last_row; r++ )); do
            buf_cursor_to "$r" 1
            buf_clear_line
        done
        return
    fi

    # Clamp scroll offset
    if (( SELECTED < SCROLL_OFFSET )); then
        SCROLL_OFFSET=$SELECTED
    elif (( SELECTED >= SCROLL_OFFSET + visible_lines )); then
        SCROLL_OFFSET=$(( SELECTED - visible_lines + 1 ))
    fi
    if (( SCROLL_OFFSET < 0 )); then
        SCROLL_OFFSET=0
    fi

    local row=$first_row
    local i
    for (( i = SCROLL_OFFSET; i < FILE_COUNT && row <= last_row; i++ )); do
        buf_cursor_to "$row" 1
        buf_clear_line

        local type="${FILE_TYPES[$i]}"
        local depth="${FILE_DEPTHS[$i]}"
        local name="${FILE_NAMES[$i]}"

        # Build indent
        local indent=""
        local d
        for (( d = 0; d < depth; d++ )); do
            indent+="  "
        done

        # Icon and name
        local display_name=""
        if [[ "$name" == ".." ]]; then
            display_name="${DIM}../${RESET}"
        elif [[ "$type" == "d" ]]; then
            display_name="${BOLD}${BLUE}${name}/${RESET}"
        else
            display_name="$name"
        fi

        local max_name_len=$(( TERM_COLS - ${#indent} - 4 ))
        if (( ${#name} + 1 > max_name_len )) && [[ "$name" != ".." ]]; then
            local truncated
            truncated=$(truncate_text "$name" "$max_name_len")
            if [[ "$type" == "d" ]]; then
                display_name="${BOLD}${BLUE}${truncated}/${RESET}"
            else
                display_name="$truncated"
            fi
        fi

        if (( i == SELECTED )); then
            buf_printf " ${REVERSE}%s%s${RESET}" "$indent" "$display_name"
        else
            buf_printf " %s%s" "$indent" "$display_name"
        fi

        row=$(( row + 1 ))
    done

    # Clear remaining rows
    for (( ; row <= last_row; row++ )); do
        buf_cursor_to "$row" 1
        buf_clear_line
    done
}

draw_footer() {
    # Separator
    local sep_row=$(( TERM_ROWS - 2 ))
    buf_cursor_to "$sep_row" 1
    buf_clear_line
    local sep=""
    local max_w=$(( TERM_COLS - 2 ))
    local c
    for (( c = 0; c < max_w; c++ )); do sep+=$'\xe2\x94\x80'; done
    buf_printf " ${DIM}%s${RESET}" "$sep"

    # Status line: depth, hidden, count
    local status_row=$(( TERM_ROWS - 1 ))
    buf_cursor_to "$status_row" 1
    buf_clear_line
    local hidden_label="off"
    (( SHOW_HIDDEN )) && hidden_label="on"
    buf_printf " ${DIM}depth:${RESET}%d  ${DIM}hidden:${RESET}%s  ${DIM}files:${RESET}%d" \
        "$TREE_DEPTH" "$hidden_label" "$FILE_COUNT"

    # Scroll indicator on right
    if (( FILE_COUNT > 0 )); then
        local pos_text="$(( SELECTED + 1 ))/${FILE_COUNT}"
        local col=$(( TERM_COLS - ${#pos_text} - 1 ))
        buf_cursor_to "$status_row" "$col"
        buf_printf "${DIM}%s${RESET}" "$pos_text"
    fi

    # Key hints
    local keys_row=$TERM_ROWS
    buf_cursor_to "$keys_row" 1
    buf_clear_line
    buf_printf " ${DIM}[j/k]${RESET} nav  ${GREEN}[Enter]${RESET} open  ${DIM}[Bksp]${RESET} up  ${DIM}[+/-]${RESET} depth  ${DIM}[.]${RESET} hidden  ${DIM}[q]${RESET} quit"
}

render() {
    get_term_size
    _RENDER_BUF=""

    draw_header
    draw_tree
    draw_footer

    buf_flush
}
