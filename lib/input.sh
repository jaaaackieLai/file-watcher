# lib/input.sh - Keyboard input reading and handling

[[ -n "${_FW_INPUT_LOADED:-}" ]] && return
readonly _FW_INPUT_LOADED=1

# _find_dir_in_direction: Find the next directory index in given direction
# Args: direction (1=forward, -1=backward)
# Reads: SELECTED, FILE_TYPES, FILE_COUNT
# Outputs: target index (stays at SELECTED if no dirs found)
_find_dir_in_direction() {
    local direction="$1"
    local i="$SELECTED"
    local count=0
    while (( count < FILE_COUNT )); do
        i=$(( (i + direction + FILE_COUNT) % FILE_COUNT ))
        if [[ "${FILE_TYPES[$i]}" == "d" ]]; then
            echo "$i"
            return
        fi
        count=$(( count + 1 ))
    done
    echo "$SELECTED"
}

# _set_expanded_for: Set EXPANDED_DIRS to target path and its ancestors
# Args: target_path
# Reads: WATCH_DIR
# Writes: EXPANDED_DIRS
_set_expanded_for() {
    local target="$1"
    # Only expand paths under WATCH_DIR
    if [[ "$target" != "$WATCH_DIR"/* ]]; then
        EXPANDED_DIRS=()
        return
    fi
    EXPANDED_DIRS=("$target")
    local current="$target"
    while [[ "$current" != "$WATCH_DIR" ]]; do
        current="$(dirname "$current")"
        [[ "$current" == "$WATCH_DIR" ]] && break
        EXPANDED_DIRS+=("$current")
    done
}

# _select_path: Find a path in FILE_PATHS and set SELECTED to its index
# Args: path
# Writes: SELECTED
_select_path() {
    local path="$1"
    local i
    for (( i = 0; i < FILE_COUNT; i++ )); do
        if [[ "${FILE_PATHS[$i]}" == "$path" ]]; then
            SELECTED=$i
            return
        fi
    done
    SELECTED=0
}

# _navigate_to_dir: Move selection to next/prev directory, expand it, re-scan
# Args: direction (1=forward, -1=backward)
_navigate_to_dir() {
    local direction="$1"
    if (( FILE_COUNT == 0 )); then
        return
    fi
    local target_idx
    target_idx=$(_find_dir_in_direction "$direction")
    if (( target_idx == SELECTED )); then
        return
    fi
    local target_path="${FILE_PATHS[$target_idx]}"
    _set_expanded_for "$target_path"
    scan_directory
    _select_path "$target_path"
    DIRTY=1
}

# _init_selection: Select the first real directory (skip ..) and expand it
_init_selection() {
    if (( FILE_COUNT == 0 )); then
        return
    fi
    # Find first directory that is not ..
    local i
    for (( i = 0; i < FILE_COUNT; i++ )); do
        if [[ "${FILE_TYPES[$i]}" == "d" && "${FILE_NAMES[$i]}" != ".." ]]; then
            local target_path="${FILE_PATHS[$i]}"
            _set_expanded_for "$target_path"
            scan_directory
            _select_path "$target_path"
            return
        fi
    done
    SELECTED=0
}

# _clamp_selected: After re-scan, ensure SELECTED points to a directory
_clamp_selected() {
    if (( FILE_COUNT == 0 )); then
        SELECTED=0
        return
    fi
    if (( SELECTED >= FILE_COUNT )); then
        SELECTED=$(( FILE_COUNT - 1 ))
    fi
    # If current selection is not a dir, find nearest dir
    if [[ "${FILE_TYPES[$SELECTED]}" != "d" ]]; then
        local i
        for (( i = 0; i < FILE_COUNT; i++ )); do
            if [[ "${FILE_TYPES[$i]}" == "d" ]]; then
                SELECTED=$i
                return
            fi
        done
        SELECTED=0
    fi
}

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
            '[C') echo "RIGHT" ;;
            '[D') echo "LEFT" ;;
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
            _navigate_to_dir -1
            ;;
        DOWN|j)
            _navigate_to_dir 1
            ;;
        TAB)
            _navigate_to_dir 1
            ;;
        ENTER)
            # If selected is a directory, enter it
            if (( FILE_COUNT > 0 )) && [[ "${FILE_TYPES[$SELECTED]}" == "d" ]]; then
                WATCH_DIR="${FILE_PATHS[$SELECTED]}"
                SELECTED=0
                SCROLL_OFFSET=0
                EXPANDED_DIRS=()
                scan_directory
                _init_selection
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
                EXPANDED_DIRS=()
                scan_directory
                _init_selection
                DIRTY=1
            fi
            ;;
        +|=)
            if (( TREE_DEPTH < MAX_TREE_DEPTH )); then
                TREE_DEPTH=$(( TREE_DEPTH + 1 ))
                scan_directory
                _clamp_selected
                DIRTY=1
            fi
            ;;
        -|_)
            if (( TREE_DEPTH > 1 )); then
                TREE_DEPTH=$(( TREE_DEPTH - 1 ))
                scan_directory
                _clamp_selected
                DIRTY=1
            fi
            ;;
        .)
            SHOW_HIDDEN=$(( ! SHOW_HIDDEN ))
            EXPANDED_DIRS=()
            scan_directory
            SELECTED=0
            SCROLL_OFFSET=0
            _init_selection
            DIRTY=1
            ;;
        r)
            local prev_path=""
            if (( FILE_COUNT > 0 )); then
                prev_path="${FILE_PATHS[$SELECTED]}"
            fi
            scan_directory
            if [[ -n "$prev_path" ]]; then
                _select_path "$prev_path"
            fi
            DIRTY=1
            ;;
        g)
            # Go to first directory
            if (( FILE_COUNT > 0 )); then
                SELECTED=$(( FILE_COUNT - 1 ))
                local first
                first=$(_find_dir_in_direction 1)
                local target_path="${FILE_PATHS[$first]}"
                _set_expanded_for "$target_path"
                scan_directory
                _select_path "$target_path"
                SCROLL_OFFSET=0
                DIRTY=1
            fi
            ;;
        G)
            # Go to last directory
            if (( FILE_COUNT > 0 )); then
                SELECTED=0
                local last
                last=$(_find_dir_in_direction -1)
                local target_path="${FILE_PATHS[$last]}"
                _set_expanded_for "$target_path"
                scan_directory
                _select_path "$target_path"
                DIRTY=1
            fi
            ;;
        q|ESC)
            RUNNING=false
            ;;
        TIMEOUT)
            # Auto-refresh on timeout (preserve selection)
            local prev_path=""
            if (( FILE_COUNT > 0 )); then
                prev_path="${FILE_PATHS[$SELECTED]}"
            fi
            scan_directory
            if [[ -n "$prev_path" ]]; then
                _select_path "$prev_path"
            fi
            DIRTY=1
            ;;
    esac
}
