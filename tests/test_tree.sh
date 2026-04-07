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

    # Only the .. entry
    assert_eq "1" "$FILE_COUNT" "empty dir should have only .. entry"
    assert_eq ".." "${FILE_NAMES[0]}" "only entry should be .."
    teardown
}

test_flat_files() {
    setup
    touch "$TEST_TMPDIR/a.txt" "$TEST_TMPDIR/b.txt" "$TEST_TMPDIR/c.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    scan_directory

    assert_eq "4" "$FILE_COUNT" "should find .. + 3 files"
    assert_eq ".." "${FILE_NAMES[0]}" "first entry should be .."
    assert_eq "f" "${FILE_TYPES[1]}" "second entry should be file"
    assert_eq "a.txt" "${FILE_NAMES[1]}" "first file should be a.txt (sorted)"
    assert_eq "0" "${FILE_DEPTHS[1]}" "depth should be 0"
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

    assert_eq "3" "$FILE_COUNT" "should find .. + 1 dir + 1 file"
    assert_eq ".." "${FILE_NAMES[0]}" "first should be .."
    assert_eq "d" "${FILE_TYPES[1]}" "directories should come before files"
    assert_eq "a_dir" "${FILE_NAMES[1]}" "second should be a_dir"
    assert_eq "f" "${FILE_TYPES[2]}" "third should be file"
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
    EXPANDED_DIRS=("$TEST_TMPDIR/src" "$TEST_TMPDIR/src/lib")
    scan_directory

    # Expected: .., src/ (d,0), lib/ (d,1), utils.sh (f,2), main.sh (f,1), README.md (f,0)
    assert_eq "6" "$FILE_COUNT" "should find .. + 5 entries total"
    assert_eq ".." "${FILE_NAMES[0]}" "first should be .."
    assert_eq "src" "${FILE_NAMES[1]}" "second should be src dir"
    assert_eq "0" "${FILE_DEPTHS[1]}" "src depth=0"
    assert_eq "lib" "${FILE_NAMES[2]}" "third should be lib dir"
    assert_eq "1" "${FILE_DEPTHS[2]}" "lib depth=1"
    assert_eq "utils.sh" "${FILE_NAMES[3]}" "fourth should be utils.sh"
    assert_eq "2" "${FILE_DEPTHS[3]}" "utils.sh depth=2"
    teardown
}

test_depth_limit() {
    setup
    mkdir -p "$TEST_TMPDIR/a/b/c/d"
    touch "$TEST_TMPDIR/a/b/c/d/deep.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=2
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/a" "$TEST_TMPDIR/a/b" "$TEST_TMPDIR/a/b/c")
    scan_directory

    # depth 0: ..(0), a/(0), depth 1: b/, depth 2: c/ -- d/ is at depth 3, should be excluded
    # Skip .. (depth 0) when checking max depth
    local max_depth=0
    local i
    for (( i = 1; i < FILE_COUNT; i++ )); do
        (( FILE_DEPTHS[i] > max_depth )) && max_depth=${FILE_DEPTHS[i]}
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

    assert_eq "2" "$FILE_COUNT" "should have .. + visible.txt"
    assert_eq "visible.txt" "${FILE_NAMES[1]}" "only visible.txt after .."
    teardown
}

test_hidden_files_included_when_enabled() {
    setup
    touch "$TEST_TMPDIR/.hidden" "$TEST_TMPDIR/visible.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=1
    scan_directory

    assert_eq "3" "$FILE_COUNT" "should include .. + hidden + visible"
    teardown
}

test_format_tree_line() {
    local result
    result=$(format_tree_line "f" 0 "README.md" 0 1)
    assert_contains "$result" "README.md" "should contain filename"

    result=$(format_tree_line "d" 1 "src" 0 2)
    assert_contains "$result" "src/" "dir should have trailing slash"
}

# ---- Parent entry (..) tests ----

test_scan_includes_parent_entry() {
    setup
    mkdir "$TEST_TMPDIR/src"
    touch "$TEST_TMPDIR/file.txt"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory

    # First entry should be ..
    assert_eq ".." "${FILE_NAMES[0]}" "first entry should be .."
    assert_eq "d" "${FILE_TYPES[0]}" ".. should be type d"
    assert_eq "0" "${FILE_DEPTHS[0]}" ".. depth should be 0"

    local expected_parent
    expected_parent="$(dirname "$TEST_TMPDIR")"
    assert_eq "$expected_parent" "${FILE_PATHS[0]}" ".. path should be parent dir"
}

test_scan_no_parent_at_root() {
    WATCH_DIR="/"
    TREE_DEPTH=1
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory

    # Should NOT have .. at root
    if (( FILE_COUNT > 0 )); then
        local result
        if [[ "${FILE_NAMES[0]}" == ".." ]]; then result="has_parent"; else result="no_parent"; fi
        assert_eq "no_parent" "$result" "root dir should not have .. entry"
    else
        PASS=$(( PASS + 1 ))
    fi
}

test_parent_entry_counts_in_total() {
    setup
    mkdir "$TEST_TMPDIR/alpha"
    mkdir "$TEST_TMPDIR/beta"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory

    # .., alpha, beta = 3
    assert_eq "3" "$FILE_COUNT" "count should include .. entry"
    teardown
}

# ---- Expand/Collapse tests ----

test_is_expanded() {
    EXPANDED_DIRS=("/tmp/foo" "/tmp/bar")
    local result
    if _is_expanded "/tmp/foo"; then result="yes"; else result="no"; fi
    assert_eq "yes" "$result" "foo should be expanded"

    if _is_expanded "/tmp/baz"; then result="yes"; else result="no"; fi
    assert_eq "no" "$result" "baz should not be expanded"

    EXPANDED_DIRS=()
    if _is_expanded "/tmp/foo"; then result="yes"; else result="no"; fi
    assert_eq "no" "$result" "empty expanded list means nothing expanded"
}

test_scan_collapsed_hides_children() {
    setup
    mkdir -p "$TEST_TMPDIR/src"
    touch "$TEST_TMPDIR/src/main.sh"
    mkdir -p "$TEST_TMPDIR/tests"
    touch "$TEST_TMPDIR/README.md"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=()
    scan_directory

    # Collapsed: .., root-level dirs and files only, no children
    assert_eq "4" "$FILE_COUNT" "collapsed dirs should hide children (.. + 3)"
    assert_eq ".." "${FILE_NAMES[0]}" "first should be .."
    assert_eq "src" "${FILE_NAMES[1]}" "second should be src dir"
    assert_eq "d" "${FILE_TYPES[1]}" "src should be dir"
    assert_eq "tests" "${FILE_NAMES[2]}" "third should be tests dir"
    assert_eq "README.md" "${FILE_NAMES[3]}" "fourth should be README.md"
    teardown
}

test_scan_expanded_shows_children() {
    setup
    mkdir -p "$TEST_TMPDIR/src"
    touch "$TEST_TMPDIR/src/main.sh"
    mkdir -p "$TEST_TMPDIR/tests"
    touch "$TEST_TMPDIR/README.md"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/src")
    scan_directory

    # src expanded: .., src, main.sh, tests, README.md
    assert_eq "5" "$FILE_COUNT" "expanded dir should show children (.. + 4)"
    assert_eq ".." "${FILE_NAMES[0]}" "first should be .."
    assert_eq "src" "${FILE_NAMES[1]}" "second should be src dir"
    assert_eq "main.sh" "${FILE_NAMES[2]}" "third should be main.sh"
    assert_eq "1" "${FILE_DEPTHS[2]}" "main.sh depth should be 1"
    assert_eq "tests" "${FILE_NAMES[3]}" "fourth should be tests dir"
    assert_eq "README.md" "${FILE_NAMES[4]}" "fifth should be README.md"
    teardown
}

test_scan_deeply_nested_expansion() {
    setup
    mkdir -p "$TEST_TMPDIR/src/lib"
    touch "$TEST_TMPDIR/src/lib/utils.sh"
    touch "$TEST_TMPDIR/src/main.sh"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/src" "$TEST_TMPDIR/src/lib")
    scan_directory

    # Both expanded: .., src, lib, utils.sh, main.sh
    assert_eq "5" "$FILE_COUNT" "deeply nested expansion should show all (.. + 4)"
    assert_eq ".." "${FILE_NAMES[0]}"
    assert_eq "src" "${FILE_NAMES[1]}"
    assert_eq "lib" "${FILE_NAMES[2]}"
    assert_eq "utils.sh" "${FILE_NAMES[3]}"
    assert_eq "main.sh" "${FILE_NAMES[4]}"
    teardown
}

test_scan_partial_expansion() {
    setup
    mkdir -p "$TEST_TMPDIR/src/lib"
    touch "$TEST_TMPDIR/src/lib/utils.sh"
    touch "$TEST_TMPDIR/src/main.sh"
    WATCH_DIR="$TEST_TMPDIR"
    TREE_DEPTH=3
    SHOW_HIDDEN=0
    EXPANDED_DIRS=("$TEST_TMPDIR/src")  # src expanded, lib NOT expanded
    scan_directory

    # src expanded shows lib/ and main.sh, but lib collapsed hides utils.sh
    assert_eq "4" "$FILE_COUNT" "partial expansion should hide nested children (.. + 3)"
    assert_eq ".." "${FILE_NAMES[0]}"
    assert_eq "src" "${FILE_NAMES[1]}"
    assert_eq "lib" "${FILE_NAMES[2]}"
    assert_eq "main.sh" "${FILE_NAMES[3]}"
    teardown
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
test_scan_includes_parent_entry
test_scan_no_parent_at_root
test_parent_entry_counts_in_total
test_is_expanded
test_scan_collapsed_hides_children
test_scan_expanded_shows_children
test_scan_deeply_nested_expansion
test_scan_partial_expansion

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
exit $FAIL
