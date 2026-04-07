# lib/input.sh - Keyboard input reading and handling

[[ -n "${_FW_INPUT_LOADED:-}" ]] && return
readonly _FW_INPUT_LOADED=1

read_key() {
    local key
    IFS= read -r -s -n 1 -t "$DEFAULT_POLL_INTERVAL" key 2>/dev/null || { echo "TIMEOUT"; return; }

    if [[ "$key" == $'\x1b' ]]; then
        local seq1 seq2
        IFS= read -r -s -n 1 -t 0.1 seq1 2>/dev/null || true
        IFS= read -r -s -n 1 -t 0.1 seq2 2>/dev/null || true
        case "${seq1}${seq2}" in
            '[A') echo "UP" ;;
            '[B') echo "DOWN" ;;
            *)    echo "ESC" ;;
        esac
    elif [[ "$key" == "" ]]; then
        echo "ENTER"
    elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
        echo "BACKSPACE"
    elif [[ "$key" == $'\t' ]]; then
        echo "TAB"
    else
        echo "$key"
    fi
}

handle_input() {
    local key
    key=$(read_key)

    case "$key" in
        UP|k)
            if (( FILE_COUNT > 0 )); then
                SELECTED=$(( (SELECTED - 1 + FILE_COUNT) % FILE_COUNT ))
                DIRTY=1
            fi
            ;;
        DOWN|j)
            if (( FILE_COUNT > 0 )); then
                SELECTED=$(( (SELECTED + 1) % FILE_COUNT ))
                DIRTY=1
            fi
            ;;
        TAB)
            if (( FILE_COUNT > 0 )); then
                SELECTED=$(( (SELECTED + 1) % FILE_COUNT ))
                DIRTY=1
            fi
            ;;
        ENTER)
            # If selected is a directory, enter it
            if (( FILE_COUNT > 0 )) && [[ "${FILE_TYPES[$SELECTED]}" == "d" ]]; then
                WATCH_DIR="${FILE_PATHS[$SELECTED]}"
                SELECTED=0
                SCROLL_OFFSET=0
                scan_directory
                DIRTY=1
            fi
            ;;
        BACKSPACE)
            # Go to parent directory
            local parent
            parent="$(dirname "$WATCH_DIR")"
            if [[ "$parent" != "$WATCH_DIR" ]]; then
                WATCH_DIR="$parent"
                SELECTED=0
                SCROLL_OFFSET=0
                scan_directory
                DIRTY=1
            fi
            ;;
        +|=)
            if (( TREE_DEPTH < MAX_TREE_DEPTH )); then
                TREE_DEPTH=$(( TREE_DEPTH + 1 ))
                scan_directory
                DIRTY=1
            fi
            ;;
        -|_)
            if (( TREE_DEPTH > 1 )); then
                TREE_DEPTH=$(( TREE_DEPTH - 1 ))
                # Clamp selected
                if (( SELECTED >= FILE_COUNT )); then
                    SELECTED=$(( FILE_COUNT > 0 ? FILE_COUNT - 1 : 0 ))
                fi
                scan_directory
                if (( SELECTED >= FILE_COUNT )); then
                    SELECTED=$(( FILE_COUNT > 0 ? FILE_COUNT - 1 : 0 ))
                fi
                DIRTY=1
            fi
            ;;
        .)
            SHOW_HIDDEN=$(( ! SHOW_HIDDEN ))
            scan_directory
            SELECTED=0
            SCROLL_OFFSET=0
            DIRTY=1
            ;;
        r)
            scan_directory
            DIRTY=1
            ;;
        g)
            # Go to top
            SELECTED=0
            SCROLL_OFFSET=0
            DIRTY=1
            ;;
        G)
            # Go to bottom
            if (( FILE_COUNT > 0 )); then
                SELECTED=$(( FILE_COUNT - 1 ))
                DIRTY=1
            fi
            ;;
        q|ESC)
            RUNNING=false
            ;;
        TIMEOUT)
            # Auto-refresh on timeout
            scan_directory
            DIRTY=1
            ;;
    esac
}
