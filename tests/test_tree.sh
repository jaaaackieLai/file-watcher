#!/usr/bin/env bash
# tests/test_tree.sh - Unit tests for tree.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/constants.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/tree.sh"

PASS=0
FAIL=0
TEST_TMPDIR=""

setup() {
    TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    [[ -n "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
}

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
        echo "FAIL: ${msg:-assertion}"
        echo "  expected: '$expected'"
        echo "  actual:   '$actual'"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" msg="${3:-}"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$(( PASS + 1 ))
    else
        FAIL=$(( FAIL + 1 ))
        echo "FAIL: ${msg:-assert_contains}"
        echo "  expected to contain: '$needle'"
        echo "  in: '$haystack'"
    fi
}

# ---- Tests ----

test_empty_directory() {
    setup
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    assert_eq "0" "$FILE_COUNT" "empty dir should have 0 entries"
    teardown
}

test_flat_files() {
    setup
    touch "$TEST_TMPDIR/a.txt" "$TEST_TMPDIR/b.txt" "$TEST_TMPDIR/c.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    assert_eq "3" "$FILE_COUNT" "should find 3 files"
    assert_eq "f" "${FILE_TYPES[0]}" "first entry should be file"
    assert_eq "a.txt" "${FILE_NAMES[0]}" "first file should be a.txt (sorted)"
    assert_eq "0" "${FILE_DEPTHS[0]}" "depth should be 0"
    teardown
}

test_directories_sorted_first() {
    setup
    touch "$TEST_TMPDIR/z_file.txt"
    mkdir "$TEST_TMPDIR/a_dir"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    assert_eq "2" "$FILE_COUNT" "should find 1 dir + 1 file"
    assert_eq "d" "${FILE_TYPES[0]}" "directories should come first"
    assert_eq "a_dir" "${FILE_NAMES[0]}" "first should be a_dir"
    assert_eq "f" "${FILE_TYPES[1]}" "second should be file"
    teardown
}

test_nested_structure() {
    setup
    mkdir -p "$TEST_TMPDIR/src/lib"
    touch "$TEST_TMPDIR/src/main.sh"
    touch "$TEST_TMPDIR/src/lib/utils.sh"
    touch "$TEST_TMPDIR/README.md"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    # Expected order: src/ (d,0), lib/ (d,1), utils.sh (f,2), main.sh (f,1), README.md (f,0)
    assert_eq "5" "$FILE_COUNT" "should find 5 entries total"
    assert_eq "src" "${FILE_NAMES[0]}" "first should be src dir"
    assert_eq "0" "${FILE_DEPTHS[0]}" "src depth=0"
    assert_eq "lib" "${FILE_NAMES[1]}" "second should be lib dir"
    assert_eq "1" "${FILE_DEPTHS[1]}" "lib depth=1"
    assert_eq "utils.sh" "${FILE_NAMES[2]}" "third should be utils.sh"
    assert_eq "2" "${FILE_DEPTHS[2]}" "utils.sh depth=2"
    teardown
}

test_depth_limit() {
    setup
    mkdir -p "$TEST_TMPDIR/a/b/c/d"
    touch "$TEST_TMPDIR/a/b/c/d/deep.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=2
    SHOW_HIDDEN=0
    scan_directory

    # depth 0: a/, depth 1: b/, depth 2: c/ -- d/ is at depth 3, should be excluded
    local max_depth=0
    for d in "${FILE_DEPTHS[@]}"; do
        (( d > max_depth )) && max_depth=$d
    done
    assert_eq "2" "$max_depth" "max depth should be limited to TREE_DEPTH"
    teardown
}

test_hidden_files_excluded_by_default() {
    setup
    touch "$TEST_TMPDIR/.hidden" "$TEST_TMPDIR/visible.txt"
    mkdir "$TEST_TMPDIR/.git"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    assert_eq "1" "$FILE_COUNT" "hidden files should be excluded"
    assert_eq "visible.txt" "${FILE_NAMES[0]}" "only visible.txt"
    teardown
}

test_hidden_files_included_when_enabled() {
    setup
    touch "$TEST_TMPDIR/.hidden" "$TEST_TMPDIR/visible.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=1
    scan_directory

    assert_eq "2" "$FILE_COUNT" "should include hidden files"
    teardown
}

test_format_tree_line() {
    local result
    result=$(format_tree_line "f" 0 "README.md" 0 1)
    assert_contains "$result" "README.md" "should contain filename"

    result=$(format_tree_line "d" 1 "src" 0 2)
    assert_contains "$result" "src/" "dir should have trailing slash"
}

# ---- Run ----

echo "Running file-watcher tree tests..."
echo ""

test_empty_directory
test_flat_files
test_directories_sorted_first
test_nested_structure
test_depth_limit
test_hidden_files_excluded_by_default
test_hidden_files_included_when_enabled
test_format_tree_line

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit $FAIL
