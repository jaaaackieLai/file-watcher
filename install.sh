#!/usr/bin/env bash
set -euo pipefail

# install.sh - Install file-watcher
#
# Usage:
#   Local:  bash install.sh
#   Remote: curl -fsSL https://jaaaackielai.github.io/file-watcher/install.sh | bash
#
# Layout:
#   ${INSTALL_PREFIX}/share/file-watcher/   # all program files
#   ${INSTALL_PREFIX}/bin/file-watcher       # symlink

readonly INSTALL_PREFIX="${INSTALL_PREFIX:-${HOME}/.local}"
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd || echo "")"
readonly GITHUB_REPO="jaaaackieLai/file-watcher"
readonly GITHUB_PAGES_BASE="https://jaaaackielai.github.io/file-watcher"
readonly LIB_FILES=(
    constants.sh
    input.sh
    render.sh
    tree.sh
    utils.sh
)

BIN_DIR="${INSTALL_PREFIX}/bin"
DATA_DIR="${INSTALL_PREFIX}/share/file-watcher"

# ─── Uninstall ────────────────────────────────────────────────────────

do_uninstall() {
    echo "Uninstalling file-watcher..."

    local need_sudo=false
    if [[ -d "$DATA_DIR" && ! -w "$DATA_DIR" ]] || [[ -L "${BIN_DIR}/file-watcher" && ! -w "$BIN_DIR" ]]; then
        need_sudo=true
    fi

    if $need_sudo; then
        sudo rm -rf "$DATA_DIR"
        sudo rm -f "${BIN_DIR}/file-watcher"
    else
        rm -rf "$DATA_DIR"
        rm -f "${BIN_DIR}/file-watcher"
    fi

    echo "Uninstalled successfully."
}

if [[ "${1:-}" == "--uninstall" ]]; then
    do_uninstall
    exit 0
fi

# ─── Install ──────────────────────────────────────────────────────────

SOURCE_DIR=""
TMP_SOURCE_DIR=""

echo "file-watcher installer"
echo "======================"
echo ""

download_from_github() {
    local target_dir="$1"
    mkdir -p "${target_dir}/lib"

    curl -fsSL "${GITHUB_PAGES_BASE}/file-watcher" -o "${target_dir}/file-watcher"
    chmod +x "${target_dir}/file-watcher"

    local f=""
    for f in "${LIB_FILES[@]}"; do
        curl -fsSL "${GITHUB_PAGES_BASE}/lib/${f}" -o "${target_dir}/lib/${f}"
    done
}

# Determine source (local clone or remote)
if [[ -n "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/file-watcher" && -d "${SCRIPT_DIR}/lib" ]]; then
    SOURCE_DIR="${SCRIPT_DIR}"
else
    TMP_SOURCE_DIR="$(mktemp -d)"
    echo "Downloading from GitHub..."
    download_from_github "$TMP_SOURCE_DIR"
    SOURCE_DIR="${TMP_SOURCE_DIR}"
fi

echo "Installing file-watcher to ${DATA_DIR}..."

install_files() {
    local use_sudo="$1"
    local cmd=""
    if $use_sudo; then cmd="sudo"; else cmd=""; fi

    $cmd mkdir -p "$DATA_DIR"
    $cmd mkdir -p "${DATA_DIR}/lib"
    $cmd mkdir -p "$BIN_DIR"

    $cmd cp "${SOURCE_DIR}/file-watcher" "${DATA_DIR}/file-watcher"
    $cmd chmod +x "${DATA_DIR}/file-watcher"
    $cmd cp "${SOURCE_DIR}/lib/"*.sh "${DATA_DIR}/lib/"

    $cmd ln -sf "${DATA_DIR}/file-watcher" "${BIN_DIR}/file-watcher"
}

mkdir -p "$BIN_DIR" 2>/dev/null || true
mkdir -p "$DATA_DIR" 2>/dev/null || true

if [[ -w "$BIN_DIR" || ! -d "$BIN_DIR" ]] && [[ -w "$(dirname "$DATA_DIR")" || ! -d "$(dirname "$DATA_DIR")" ]]; then
    install_files false
else
    echo "Need sudo to write to ${INSTALL_PREFIX}"
    install_files true
fi

if [[ -n "$TMP_SOURCE_DIR" ]]; then
    rm -rf "$TMP_SOURCE_DIR"
fi

echo ""
echo "Installed successfully!"
echo "  Files:   ${DATA_DIR}/"
echo "  Symlink: ${BIN_DIR}/file-watcher -> ${DATA_DIR}/file-watcher"
echo ""
echo "Make sure ~/.local/bin is in your PATH:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
echo ""
echo "Usage: file-watcher [directory]"
