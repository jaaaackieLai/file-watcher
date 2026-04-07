#!/usr/bin/env bash
# tests/test_input.sh - Unit tests for input.sh navigation helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/constants.sh"
source "$PROJECT_DIR/lib/utils.sh"
source "$PROJECT_DIR/lib/tree.sh"
source "$PROJECT_DIR/lib/input.sh"

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

# ---- Navigation helper tests ----

test_find_dir_forward_skips_files() {
    # Setup: dir, file, file, dir
    FILE_TYPES=("d" "f" "f" "d")
    FILE_COUNT=4
    SELECTED=0

    local next
    next=$(_find_dir_in_direction 1)
    assert_eq "3" "$next" "should skip files and find next dir"
}

test_find_dir_backward_skips_files() {
    FILE_TYPES=("d" "f" "f" "d")
    FILE_COUNT=4
    SELECTED=3

    local prev
    prev=$(_find_dir_in_direction -1)
    assert_eq "0" "$prev" "should skip files backward and find prev dir"
}

test_find_dir_wraps_forward() {
    FILE_TYPES=("d" "f" "f")
    FILE_COUNT=3
    SELECTED=0

    local next
    next=$(_find_dir_in_direction 1)
    assert_eq "0" "$next" "should wrap around when no more dirs forward"
}

test_find_dir_wraps_backward() {
    FILE_TYPES=("f" "f" "d")
    FILE_COUNT=3
    SELECTED=2

    local prev
    prev=$(_find_dir_in_direction -1)
    assert_eq "2" "$prev" "should wrap around when no more dirs backward"
}

test_find_dir_no_dirs() {
    FILE_TYPES=("f" "f" "f")
    FILE_COUNT=3
    SELECTED=0

    local result
    result=$(_find_dir_in_direction 1)
    assert_eq "0" "$result" "should stay put when no dirs exist"
}

test_set_expanded_for_single_level() {
    setup
    mkdir -p "$TEST_TMPDIR/src" "$TEST_TMPDIR/tests"
    WATCH_DIR="$TEST_TMPDIR"

    _set_expanded_for "$TEST_TMPDIR/src"
    assert_eq "1" "${#EXPANDED_DIRS[@]}" "should have 1 expanded dir"
    assert_eq "$TEST_TMPDIR/src" "${EXPANDED_DIRS[0]}" "should be src"
    teardown
}

test_set_expanded_for_nested() {
    setup
    mkdir -p "$TEST_TMPDIR/src/lib"
    WATCH_DIR="$TEST_TMPDIR"

    _set_expanded_for "$TEST_TMPDIR/src/lib"
    assert_eq "2" "${#EXPANDED_DIRS[@]}" "should have 2 expanded dirs"

    # Check both src and src/lib are expanded
    local has_src=0 has_lib=0
    local d
    for d in "${EXPANDED_DIRS[@]}"; do
        [[ "$d" == "$TEST_TMPDIR/src" ]] && has_src=1
        [[ "$d" == "$TEST_TMPDIR/src/lib" ]] && has_lib=1
    done
    assert_eq "1" "$has_src" "src should be expanded (ancestor)"
    assert_eq "1" "$has_lib" "src/lib should be expanded (target)"
    teardown
}

test_select_path_finds_index() {
    FILE_PATHS=("/a/src" "/a/src/main.sh" "/a/tests")
    FILE_COUNT=3
    SELECTED=0

    _select_path "/a/tests"
    assert_eq "2" "$SELECTED" "should select index of matching path"
}

test_select_path_defaults_to_zero() {
    FILE_PATHS=("/a/src" "/a/tests")
    FILE_COUNT=2
    SELECTED=1

    _select_path "/nonexistent"
    assert_eq "0" "$SELECTED" "should default to 0 when path not found"
}

test_navigate_expands_and_collapses() {
    setup
    mkdir -p "$TEST_TMPDIR/alpha"
    touch "$TEST_TMPDIR/alpha/a.txt"
    mkdir -p "$TEST_TMPDIR/beta"
    touch "$TEST_TMPDIR/beta/b.txt"
    touch "$TEST_TMPDIR/root.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0

    # Start at alpha (expanded)
    _set_expanded_for "$TEST_TMPDIR/alpha"
    scan_directory
    _select_path "$TEST_TMPDIR/alpha"

    # Verify alpha is expanded: .., alpha/, a.txt, beta/, root.txt = 5
    assert_eq "5" "$FILE_COUNT" "alpha expanded should show 5 entries (.. + 4)"

    # Navigate down to beta
    _set_expanded_for "$TEST_TMPDIR/beta"
    scan_directory
    _select_path "$TEST_TMPDIR/beta"

    # Now beta expanded, alpha collapsed: .., alpha/, beta/, b.txt, root.txt = 5
    assert_eq "5" "$FILE_COUNT" "beta expanded should show 5 entries (.. + 4)"
    assert_eq ".." "${FILE_NAMES[0]}" "first should be .."
    assert_eq "alpha" "${FILE_NAMES[1]}" "alpha should still be visible (collapsed)"
    assert_eq "beta" "${FILE_NAMES[2]}" "beta should be visible"
    assert_eq "b.txt" "${FILE_NAMES[3]}" "b.txt should be visible (under expanded beta)"
    assert_eq "root.txt" "${FILE_NAMES[4]}" "root.txt should be visible"
    teardown
}

test_set_expanded_for_parent_path() {
    setup
    WATCH_DIR="$TEST_TMPDIR"
    local parent
    parent="$(dirname "$TEST_TMPDIR")"

    # Parent path is outside WATCH_DIR, should result in empty EXPANDED_DIRS
    _set_expanded_for "$parent"
    assert_eq "0" "${#EXPANDED_DIRS[@]}" "parent path should not expand anything"
    teardown
}

test_init_selection_skips_parent() {
    setup
    mkdir "$TEST_TMPDIR/src"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory
    _init_selection

    # Should select src, not ..
    assert_eq "src" "${FILE_NAMES[$SELECTED]}" "init should select first real dir, not .."
    teardown
}

# ---- Sibling navigation tests ----

# Tree layout when alpha is expanded:
#   ..(d,0)  alpha/(d,0)  sub1/(d,1)  sub2/(d,1)  beta/(d,0)  file.txt(f,0)
# Tab at alpha should jump to beta, skipping sub1/sub2.

test_find_sibling_forward_skips_children() {
    setup
    mkdir -p "$TEST_TMPDIR/alpha/sub1" "$TEST_TMPDIR/alpha/sub2"
    mkdir -p "$TEST_TMPDIR/beta"
    touch "$TEST_TMPDIR/file.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/alpha")
    scan_directory

    # alpha is at index 1, depth 0
    SELECTED=1
    local result
    result=$(_find_sibling_dir_in_direction 1)
    assert_eq "beta" "${FILE_NAMES[$result]}" "forward sibling should be beta, skipping sub1/sub2"
    teardown
}

test_find_sibling_backward_skips_children() {
    setup
    mkdir -p "$TEST_TMPDIR/alpha/sub1" "$TEST_TMPDIR/alpha/sub2"
    mkdir -p "$TEST_TMPDIR/beta"
    touch "$TEST_TMPDIR/file.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/alpha")
    scan_directory

    # Find beta's index
    local beta_idx
    for (( i = 0; i < FILE_COUNT; i++ )); do
        [[ "${FILE_NAMES[$i]}" == "beta" ]] && beta_idx=$i
    done
    SELECTED=$beta_idx
    local result
    result=$(_find_sibling_dir_in_direction -1)
    assert_eq "alpha" "${FILE_NAMES[$result]}" "backward sibling should be alpha, skipping sub1/sub2"
    teardown
}

test_find_sibling_no_sibling_stays_put() {
    setup
    mkdir -p "$TEST_TMPDIR/only_dir/child"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/only_dir")
    scan_directory

    # only_dir is at index 1, depth 0 -- no other depth-0 dir
    SELECTED=1
    local result
    result=$(_find_sibling_dir_in_direction 1)
    assert_eq "$SELECTED" "$result" "no forward sibling should stay at current"
    teardown
}

test_find_sibling_from_nested_dir() {
    setup
    mkdir -p "$TEST_TMPDIR/src/lib" "$TEST_TMPDIR/src/utils"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/src" "$TEST_TMPDIR/src/lib")
    scan_directory

    # Find lib's index (depth 1)
    local lib_idx
    for (( i = 0; i < FILE_COUNT; i++ )); do
        [[ "${FILE_NAMES[$i]}" == "lib" ]] && lib_idx=$i
    done
    SELECTED=$lib_idx
    local result
    result=$(_find_sibling_dir_in_direction 1)
    assert_eq "utils" "${FILE_NAMES[$result]}" "sibling at depth 1 should be utils"
    teardown
}

test_find_sibling_does_not_wrap() {
    setup
    mkdir -p "$TEST_TMPDIR/alpha" "$TEST_TMPDIR/beta"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory

    # beta is the last depth-0 dir, forward should stay put
    local beta_idx
    for (( i = 0; i < FILE_COUNT; i++ )); do
        [[ "${FILE_NAMES[$i]}" == "beta" ]] && beta_idx=$i
    done
    SELECTED=$beta_idx
    local result
    result=$(_find_sibling_dir_in_direction 1)
    assert_eq "$SELECTED" "$result" "should not wrap around past last sibling"
    teardown
}

# ---- Run ----

echo "Running file-watcher input tests..."
echo ""

test_find_dir_forward_skips_files
test_find_dir_backward_skips_files
test_find_dir_wraps_forward
test_find_dir_wraps_backward
test_find_dir_no_dirs
test_set_expanded_for_single_level
test_set_expanded_for_nested
test_select_path_finds_index
test_select_path_defaults_to_zero
test_navigate_expands_and_collapses
test_set_expanded_for_parent_path
test_init_selection_skips_parent
test_find_sibling_forward_skips_children
test_find_sibling_backward_skips_children
test_find_sibling_no_sibling_stays_put
test_find_sibling_from_nested_dir
test_find_sibling_does_not_wrap

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit $FAIL
