# file-watcher

Live file tree viewer for tmux panes. Designed for vibe coding sessions where you want to see your project structure without opening a separate editor.

## Install

```bash
curl -fsSL https://jaaaackielai.github.io/file-watcher/install.sh | bash
```

Or from source:

```bash
git clone https://github.com/jaaaackieLai/file-watcher.git
cd file-watcher
bash install.sh
```

This installs to `~/.local/share/file-watcher/` with a symlink at `~/.local/bin/file-watcher`.

Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

```bash
file-watcher              # watch current directory
file-watcher ~/project    # watch a specific directory
file-watcher -d 5         # set tree depth to 5
file-watcher -a           # show hidden files
```

## Keys

| Key | Action |
|-----|--------|
| `j` / `Down` | Move down |
| `k` / `Up` | Move up |
| `Tab` / `Shift+Tab` | Next / previous sibling directory |
| `Enter` | Enter directory |
| `Backspace` | Go to parent directory |
| `+` / `-` | Increase / decrease tree depth |
| `.` | Toggle hidden files |
| `g` / `G` | Go to top / bottom |
| `r` | Refresh |
| `q` / `ESC` | Quit |

## Recommended tmux setup

Split a small pane on the side for file-watcher:

```bash
# Horizontal split, 30% width on the right
tmux split-window -h -l 30% 'file-watcher /path/to/project'
```

## Management

```bash
file-watcher --version    # show version
file-watcher --update     # update from GitHub
file-watcher --uninstall  # remove from system
```

## Requirements

- bash 4.0+
- Standard POSIX utilities (find, sort)
- curl + jq (for --update only)

## License

MIT
