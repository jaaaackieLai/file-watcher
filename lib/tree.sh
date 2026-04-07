# lib/tree.sh - Directory scanning and tree building

[[ -n "${_FW_TREE_LOADED:-}" ]] && return
readonly _FW_TREE_LOADED=1

# _is_expanded: Check if a directory path is in EXPANDED_DIRS
_is_expanded() {
    local path="$1"
    local d
    for d in "${EXPANDED_DIRS[@]+"${EXPANDED_DIRS[@]}"}"; do
        [[ "$d" == "$path" ]] && return 0
    done
    return 1
}

# scan_directory: Populate FILE_PATHS/FILE_TYPES/FILE_DEPTHS/FILE_NAMES arrays
# Reads: WATCH_DIR, TREE_DEPTH, SHOW_HIDDEN, EXPANDED_DIRS
# Writes: FILE_PATHS, FILE_TYPES, FILE_DEPTHS, FILE_NAMES, FILE_COUNT
scan_directory() {
    FILE_PATHS=()
    FILE_TYPES=()
    FILE_DEPTHS=()
    FILE_NAMES=()
    FILE_COUNT=0

    # Add parent entry (..) unless at filesystem root
    local parent
    parent="$(dirname "$WATCH_DIR")"
    if [[ "$parent" != "$WATCH_DIR" ]]; then
        FILE_PATHS+=("$parent")
        FILE_TYPES+=("d")
        FILE_DEPTHS+=(0)
        FILE_NAMES+=("..")
    fi

    _scan_recursive "$WATCH_DIR" 0
    FILE_COUNT=${#FILE_PATHS[@]}
}

_scan_recursive() {
    local dir="$1" depth="$2"

    if (( depth > TREE_DEPTH )); then
        return
    fi

    local dirs=()
    local files=()

    local entry
    for entry in "$dir"/*; do
        [[ -e "$entry" ]] || continue
        local name="${entry##*/}"

        # Skip hidden files unless SHOW_HIDDEN
        if [[ "$name" == .* ]] && (( ! SHOW_HIDDEN )); then
            continue
        fi

        if [[ -d "$entry" ]]; then
            dirs+=("$entry")
        else
            files+=("$entry")
        fi
    done

    # Also scan hidden entries when SHOW_HIDDEN=1
    if (( SHOW_HIDDEN )); then
        for entry in "$dir"/.*; do
            [[ -e "$entry" ]] || continue
            local name="${entry##*/}"
            [[ "$name" == "." || "$name" == ".." ]] && continue

            if [[ -d "$entry" ]]; then
                # Avoid duplicates (already caught by *)
                local already=0
                local d
                for d in "${dirs[@]+"${dirs[@]}"}"; do
                    [[ "$d" == "$entry" ]] && { already=1; break; }
                done
                (( already )) || dirs+=("$entry")
            else
                local already=0
                local f
                for f in "${files[@]+"${files[@]}"}"; do
                    [[ "$f" == "$entry" ]] && { already=1; break; }
                done
                (( already )) || files+=("$entry")
            fi
        done
    fi

    # Sort directories and files by name
    IFS=$'\n' dirs=($(for d in "${dirs[@]+"${dirs[@]}"}"; do echo "$d"; done | sort)); unset IFS
    IFS=$'\n' files=($(for f in "${files[@]+"${files[@]}"}"; do echo "$f"; done | sort)); unset IFS

    # Add directories first (with recursive descent)
    local d
    for d in "${dirs[@]+"${dirs[@]}"}"; do
        [[ -z "$d" ]] && continue
        local name="${d##*/}"
        FILE_PATHS+=("$d")
        FILE_TYPES+=("d")
        FILE_DEPTHS+=("$depth")
        FILE_NAMES+=("$name")

        if _is_expanded "$d"; then
            _scan_recursive "$d" $(( depth + 1 ))
        fi
    done

    # Then files
    local f
    for f in "${files[@]+"${files[@]}"}"; do
        [[ -z "$f" ]] && continue
        local name="${f##*/}"
        FILE_PATHS+=("$f")
        FILE_TYPES+=("f")
        FILE_DEPTHS+=("$depth")
        FILE_NAMES+=("$name")
    done
}

# format_tree_line: Format a single tree entry for display
# Args: type depth name index total_at_same_level
# Returns: formatted string with tree characters and colors
format_tree_line() {
    local type="$1" depth="$2" name="$3" index="$4" total="$5"
    local indent=""

    local i
    for (( i = 0; i < depth; i++ )); do
        indent+="  "
    done

    local prefix=""
    if (( depth > 0 )); then
        if (( index == total - 1 )); then
            prefix="${T_LAST} "
        else
            prefix="${T_BRANCH} "
        fi
        # Adjust indent: replace last 2 spaces with prefix
        indent="${indent:0:$(( ${#indent} - 2 ))}"
    fi

    if [[ "$type" == "d" ]]; then
        printf '%s%s%s%s%s' "$indent" "$prefix" "${BOLD}${BLUE}" "${name}/" "${RESET}"
    else
        printf '%s%s%s' "$indent" "$prefix" "$name"
    fi
}
