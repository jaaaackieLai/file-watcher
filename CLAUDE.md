# file-watcher

Live file tree viewer TUI for tmux panes, built in pure bash.

## Architecture

```
file-watcher          # main entry point (CLI parsing, main loop)
lib/
  constants.sh        # colors, version, global state variables
  utils.sh            # terminal utilities (cursor, buffered output)
  tree.sh             # directory scanning (scan_directory, format_tree_line)
  render.sh           # TUI rendering (header, tree, footer)
  input.sh            # keyboard handling (read_key, handle_input)
tests/
  test_tree.sh        # unit tests for tree.sh
install.sh            # installer (symlink to ~/.local/bin)
```

## Key patterns

- **Buffered output**: All rendering goes through `_RENDER_BUF` / `buf_flush()` to avoid flicker.
- **Dirty flag**: Only re-render when `DIRTY=1`. Set by input handlers and WINCH signal.
- **Polling refresh**: `read_key` times out after `DEFAULT_POLL_INTERVAL` seconds, triggering a directory rescan.
- **Parallel arrays**: `FILE_PATHS`, `FILE_TYPES`, `FILE_DEPTHS`, `FILE_NAMES` store scan results. Avoids subshells and associative arrays for performance.
- **Guard loading**: Each lib file uses `[[ -n "${_FW_*_LOADED:-}" ]] && return` to prevent double-sourcing.

## Running tests

```bash
bash tests/test_tree.sh     # tree scanning tests
bash tests/test_input.sh    # input/navigation tests
```

## Adding new features

- New key bindings go in `lib/input.sh` `handle_input()`.
- New display elements go in `lib/render.sh`. Update `first_row` / `last_row` if adding header/footer rows.
- New state variables go in `lib/constants.sh` under the `State (mutable)` section.
