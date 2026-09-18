# herdr

[herdr](https://herdr.dev) is a terminal multiplexer built for coding agents:
a persistent server that keeps sessions, panes, and running agents alive
across client disconnects. The config lives in
[`herdr/.config/herdr/config.toml`](../herdr/.config/herdr/config.toml) and is
stowed to `~/.config/herdr/config.toml`. Not in any distro package manager —
installed by `scripts/bootstrap.sh` (`ensure_herdr`) via `herdr.dev/install.sh`,
same on Ubuntu/WSL, Fedora/Bazzite, Arch/Omarchy, and macOS.

Adopted alongside tmux, not instead of it: `nic` (tmux) keeps working
untouched, `nih` is the herdr equivalent. See
[`zsh/.config/zsh/functions.zsh`](../zsh/.config/zsh/functions.zsh).

## Concepts

herdr's hierarchy differs from tmux's:

| tmux | herdr |
|------|-------|
| Session | Session — one persistent session (`default`), survives disconnects |
| Window | Workspace — one per project |
| — | Tab — a layout inside a workspace |
| Pane | Pane — a real terminal |

There is normally **one** herdr session running. `nih` never creates a new
session; it adds or reuses a **workspace** inside the existing one, keyed by
project name — the herdr analog of "one tmux session per project".

## The prefix

This config uses **`Ctrl-Space`** as the prefix (`config.toml`'s `[keys]`
section), chosen to mirror tmux's `Ctrl-a` role without colliding with it —
both can run side by side.

```sh
herdr                # attach the persistent session (starts it if needed)
herdr status         # client + server status
herdr workspace list # list workspaces (JSON)
nih                  # cockpit for the current directory (see below)
```

## Keybindings (this config)

> Notation: `prefix` = `Ctrl-Space`.

| Keys | Action |
|------|--------|
| `prefix q` | Reload `config.toml` |
| `prefix h` / `alt+enter` | Split pane horizontally |
| `prefix v` / `alt+shift+enter` | Split pane vertically |
| `prefix c` | New tab (keeps current path) |
| `ctrl+alt+←/↓/↑/→` | Move to the pane left / down / up / right |
| `ctrl+alt+shift+←/↓/↑/→` | Resize pane |
| `prefix d` | Detach from the session (it keeps running) |
| `prefix [` | Enter copy mode |
| `prefix z` | Zoom/unzoom the current pane |
| `prefix shift+c` | New workspace |
| `prefix shift+r` | Rename current workspace |
| `alt+←/→` or `prefix p`/`prefix n` | Previous / next tab |
| `alt+↑/↓` or `prefix shift+p`/`prefix shift+n` | Previous / next workspace |

Quality-of-life already enabled: mouse support, `new_cwd = "follow"` (splits
and new tabs inherit the current pane's cwd, like tmux's
`-c "#{pane_current_path}"`), and no confirmation prompts on close.

## `nih`: the coding cockpit, on herdr

```
usage: nih [-p perfil] [name]   (default: basename of the current directory)
```

- Looks up a herdr workspace labeled `name`. If found, focuses it.
- If not found, creates one and arms the cockpit: nvim on the left (60%),
  Claude Code on the right (40%) — same layout as `nic`.
- Run from outside a herdr pane: attaches the client afterward so you land on
  the workspace. Run from inside one (`$HERDR_ENV` set): just focuses/creates
  the workspace, no nested attach.
- `-p <perfil>`: the Claude Code pane uses `claude-profile <perfil>` instead
  of plain `claude` — same profiles as `nic`, see `docs/claude-code.md`.

```sh
cd ~/Projects/lab/some-project
nih          # first run: creates the workspace + cockpit
nih          # later: reuses the same workspace
nih -p work  # cockpit using the "work" Claude Code profile
```

## Extending it

Keybindings and theme live entirely in `config.toml`'s `[keys]`/`[ui]`
sections — edit there and `prefix q` reloads without restarting the server.
Keep the file at `~/.config/herdr/config.toml` so stow keeps managing it.

## Claude Code integration hook

`~/.claude/hooks/herdr-agent-state.sh` reports Claude Code's agent lifecycle
state to herdr (`herdr agent list/wait/prompt`). It's stowed from
[`claude/.claude/hooks/herdr-agent-state.sh`](../claude/.claude/hooks/herdr-agent-state.sh)
like every other Claude Code hook.

**Do not run `herdr integration install claude` by hand.** `~/.claude/settings.json`
is a symlink into this repo; that command rewrites it in place and can reorder
or drop the other hooks already registered there (`git-guardrails`,
`guard-protected-branch`, `load-agents-md`, `statusline`). If herdr ships a
newer hook version, diff `herdr --skill`'s output (or the installer's target
file) against the tracked hook manually and update the file in the repo
instead.

`herdr integration status` may still show `claude` as outdated — that's
expected and harmless; the hook only needs to be present, executable, and
correctly wired in `settings.json`, none of which the version number affects.

**Decision: no LazyVim/Claude shortcut for now.** A quick-open/jump-to-nvim
command from inside Claude Code was considered and rejected — a keybinding
can't know *which file* to open (only Claude does), so the useful half of
that idea can only be triggered by Claude itself, inheriting the fragility of
piping keystrokes into a pane (`pane send-text` races with insert mode and
mis-escapes paths). Existing navigation (`ctrl+alt+←/↓/↑/→`, `nic`/`nih`)
already covers this once a cockpit is open. Revisit only if nvim panes are in
regular use again; the low-risk design then is a slash command that opens
nvim with `nvim --listen <socket>` and sends files via
`nvim --server <socket> --remote <file>`, not `pane send-text`.
