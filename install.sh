#!/usr/bin/env bash
set -euo pipefail

# install.sh - Install file-watcher
#
# Layout:
#   ${INSTALL_PREFIX}/share/file-watcher/   # all program files
#   ${INSTALL_PREFIX}/bin/file-watcher       # symlink

readonly INSTALL_PREFIX="${INSTALL_PREFIX:-${HOME}/.local}"
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

BIN_DIR="${INSTALL_PREFIX}/bin"
DATA_DIR="${INSTALL_PREFIX}/share/file-watcher"

install_files() {
    local use_sudo="$1"
    local cmd=""
    if $use_sudo; then cmd="sudo"; else cmd=""; fi

    $cmd mkdir -p "$DATA_DIR"
    $cmd mkdir -p "${DATA_DIR}/lib"
    $cmd mkdir -p "$BIN_DIR"

    $cmd cp "${SCRIPT_DIR}/file-watcher" "${DATA_DIR}/file-watcher"
    $cmd chmod +x "${DATA_DIR}/file-watcher"
    $cmd cp "${SCRIPT_DIR}/lib/"*.sh "${DATA_DIR}/lib/"

    $cmd ln -sf "${DATA_DIR}/file-watcher" "${BIN_DIR}/file-watcher"
}

echo "Installing file-watcher to ${DATA_DIR}..."

mkdir -p "$BIN_DIR" 2>/dev/null || true
mkdir -p "$DATA_DIR" 2>/dev/null || true

if [[ -w "$BIN_DIR" || ! -d "$BIN_DIR" ]] && [[ -w "$(dirname "$DATA_DIR")" || ! -d "$(dirname "$DATA_DIR")" ]]; then
    install_files false
else
    echo "Need sudo to write to ${INSTALL_PREFIX}"
    install_files true
fi

echo ""
echo "Installed successfully!"
echo "  Files:   ${DATA_DIR}/"
echo "  Symlink: ${BIN_DIR}/file-watcher -> ${DATA_DIR}/file-watcher"
echo ""
echo "Usage: file-watcher [directory]"
