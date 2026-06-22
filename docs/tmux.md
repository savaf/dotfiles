# tmux

[tmux](https://github.com/tmux/tmux) is a terminal multiplexer: split one
terminal into multiple panes/windows and keep sessions alive across
disconnects. The config lives in
[`tmux/.config/tmux/tmux.conf`](../tmux/.config/tmux/tmux.conf) and is stowed to
`~/.config/tmux/tmux.conf`. It's portable across Ubuntu/WSL and macOS.

## Concepts

- **Session** — a named workspace (survives terminal closing/SSH drops).
- **Window** — like a tab inside a session.
- **Pane** — a split within a window.

## The prefix

This config uses **`Ctrl-b`** as the prefix (the tmux default).
You press the prefix, release, then press the command key.

```sh
tmux              # start a session
tmux new -s work  # start a named session "work"
tmux ls           # list sessions
tmux attach -t work
```

## Keybindings (this config)

> Notation: `prefix` = `Ctrl-b`. `prefix |` means press `Ctrl-b`, release, then `|`.

| Keys | Action |
|------|--------|
| `prefix r` | Reload `tmux.conf` |
| `prefix \|` | Split pane **vertically** (keeps current path) |
| `prefix -` | Split pane **horizontally** (keeps current path) |
| `prefix c` | New window (keeps current path) |
| `prefix h/j/k/l` | Move to the pane left / down / up / right |
| `prefix H/J/K/L` | Resize pane (repeatable — hold/repeat the letter) |
| `prefix d` | Detach from the session (it keeps running) |
| `prefix [` | Enter copy mode (scroll/select; `q` to exit) |

Quality-of-life already enabled: mouse support, 50k-line scrollback, true color,
vi-style copy mode, windows/panes start at **1**, and windows renumber when one
closes.

## Common defaults (not remapped)

| Keys | Action |
|------|--------|
| `prefix n` / `prefix p` | Next / previous window |
| `prefix 0..9` | Jump to window by number |
| `prefix ,` | Rename current window |
| `prefix w` | Interactive window/session picker |
| `prefix x` | Kill the current pane |
| `prefix z` | Zoom/unzoom the current pane (fullscreen toggle) |
| `prefix &` | Kill the current window |
| `prefix ?` | List all keybindings |

## Copy mode (vi-style)

1. `prefix [` to enter copy mode.
2. Move with `h/j/k/l`, search with `/`.
3. `Space` to start selection, `Enter` to copy.
4. `prefix ]` to paste.

With mouse on, you can also select with the mouse and scroll with the wheel.

## A typical workflow

```sh
tmux new -s dev          # start session "dev"
# prefix |   -> split for an editor + a shell
# prefix -   -> split the shell for logs
# prefix h/l -> hop between panes
# prefix d   -> detach and walk away
tmux attach -t dev       # come back later, everything is intact
```

## Extending it

For plugins (resurrect sessions, themes, etc.) add
[TPM](https://github.com/tmux-plugins/tpm) and declare plugins in the config.
Keep the file at `~/.config/tmux/tmux.conf` so stow keeps managing it.
