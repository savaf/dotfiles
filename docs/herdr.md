# herdr

[herdr](https://herdr.dev) is a terminal multiplexer built for coding agents:
a persistent server that keeps sessions, panes, and running agents alive
across client disconnects. The config lives in
[`herdr/.config/herdr/config.toml`](../herdr/.config/herdr/config.toml) and is
stowed to `~/.config/herdr/config.toml`. Not in any distro package manager —
installed by `scripts/bootstrap.sh` (`ensure_herdr`) via `herdr.dev/install.sh`,
same on Ubuntu/WSL, Fedora/Bazzite, Arch/Omarchy, and macOS.

Adopted alongside tmux, not instead of it. The `hw` function opens the work
workspaces; see
[`zsh/.config/zsh/functions.zsh`](../zsh/.config/zsh/functions.zsh).

## Concepts

herdr's hierarchy differs from tmux's:

| tmux | herdr |
|------|-------|
| Session | Session — one persistent session (`default`), survives disconnects |
| Window | Workspace — one per project |
| — | Tab — a layout inside a workspace |
| Pane | Pane — a real terminal |

There is normally **one** herdr session running. `hw` never creates a new
session; it adds or reuses **workspaces** inside the existing one, keyed by
label — the herdr analog of "one tmux session per project". herdr has no
workspace groups or nesting (workspaces are flat; only git-worktree workspaces
group under their parent repo), so related repos share one workspace with a tab
each.

## The prefix

This config uses **`Ctrl-Space`** as the prefix (`config.toml`'s `[keys]`
section), chosen to mirror tmux's `Ctrl-a` role without colliding with it —
both can run side by side.

```sh
herdr                # attach the persistent session (starts it if needed)
herdr status         # client + server status
herdr workspace list # list workspaces (JSON)
hw                   # open the work workspaces (see below)
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

## `hw`: the work workspaces

```
usage: hw   (no arguments)
```

Opens, in this order, whichever of these workspaces is missing — one full-screen
Claude Code pane per repo, no nvim:

| Workspace | Repos | Claude |
|-----------|-------|--------|
| `dotfiles` | `~/dotfiles` | `claude` |
| `SlipStream` | `~/Projects/urbn/SlipStream` | `claude-profile work` (`ccw`) |
| `CNC` | `~/Projects/cnc/{vuf-portal,backoffice-vuf,b0-vuf-apis}`, one tab each | `claude` |

- Idempotent: looks workspaces up by label and only creates the missing ones.
- Ends focused on `dotfiles`; in `CNC` the active tab is `vuf-portal`.
- Run from outside a herdr pane: attaches the client afterward. Run from inside
  one (`$HERDR_ENV` set): no nested attach.
- To change the set, edit the three `_hw_workspace` calls in `hw`.
- A repo outside the list: `prefix shift+c` (new workspace).

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

The tracked hook is at integration v10. It only reports the session id on
`SessionStart`; herdr reads `idle`/`working`/`blocked`/`done` from the
terminal itself.

To update it without touching the real `settings.json`, install into a
throwaway home and copy the result:

```sh
tmp=$(mktemp -d) && mkdir "$tmp/.claude" && echo '{}' >"$tmp/.claude/settings.json"
HOME="$tmp" CLAUDE_CONFIG_DIR="$tmp/.claude" herdr integration install claude
cp -f "$tmp/.claude/hooks/herdr-agent-state.sh" claude/.claude/hooks/
cat "$tmp/.claude/settings.json"   # copy its SessionStart matcher if it changed
```

`herdr integration status` should then show `claude: current`.

**Decision: no LazyVim/Claude shortcut for now.** A quick-open/jump-to-nvim
command from inside Claude Code was considered and rejected — a keybinding
can't know *which file* to open (only Claude does), so the useful half of
that idea can only be triggered by Claude itself, inheriting the fragility of
piping keystrokes into a pane (`pane send-text` races with insert mode and
mis-escapes paths). Existing navigation (`ctrl+alt+←/↓/↑/→`)
already covers this once the workspaces are open. Revisit only if nvim panes are in
regular use again (`hw` no longer opens nvim); the low-risk design then is a slash command that opens
nvim with `nvim --listen <socket>` and sends files via
`nvim --server <socket> --remote <file>`, not `pane send-text`.
