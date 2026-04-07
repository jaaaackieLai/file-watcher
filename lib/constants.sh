# lib/constants.sh - Constants, colors, and global state

[[ -n "${_FW_CONSTANTS_LOADED:-}" ]] && return
readonly _FW_CONSTANTS_LOADED=1

readonly FW_VERSION="0.3.0"
readonly FW_GITHUB_REPO="jaaaackieLai/file-watcher"
readonly FW_GITHUB_PAGES_BASE="https://jaaaackielai.github.io/file-watcher"
readonly FW_GITHUB_RAW_BASE="https://raw.githubusercontent.com/${FW_GITHUB_REPO}/main"

# ---- Colors and styles ----
readonly RESET=$'\033[0m'
readonly BOLD=$'\033[1m'
readonly DIM=$'\033[2m'
readonly REVERSE=$'\033[7m'
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly BLUE=$'\033[34m'
readonly CYAN=$'\033[36m'
readonly WHITE=$'\033[37m'
readonly GRAY=$'\033[90m'

# ---- Tree characters ----
readonly T_BRANCH=$'\xe2\x94\x9c\xe2\x94\x80\xe2\x94\x80'  # ├──
readonly T_LAST=$'\xe2\x94\x94\xe2\x94\x80\xe2\x94\x80'      # └──
readonly T_PIPE=$'\xe2\x94\x82'                                # │
readonly T_DIR_ICON='/'

# ---- Defaults ----
DEFAULT_TREE_DEPTH=3
DEFAULT_POLL_INTERVAL=2
MAX_TREE_DEPTH=8

# ---- State (mutable) ----
WATCH_DIR=""
TREE_DEPTH=$DEFAULT_TREE_DEPTH
SHOW_HIDDEN=0
SCROLL_OFFSET=0
SELECTED=0
DIRTY=1
RUNNING=true
TERM_ROWS=24
TERM_COLS=80

# File entries: parallel arrays
FILE_PATHS=()
FILE_TYPES=()    # "d" or "f"
FILE_DEPTHS=()
FILE_NAMES=()
FILE_COUNT=0

# Expanded directories: only these dirs show children in the tree
EXPANDED_DIRS=()
