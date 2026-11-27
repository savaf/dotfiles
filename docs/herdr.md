# herdr

[herdr](https://herdr.dev) is a terminal multiplexer built for coding agents:
a persistent server that keeps sessions, panes, and running agents alive
across client disconnects. The config lives in
[`herdr/.config/herdr/config.toml`](../herdr/.config/herdr/config.toml) and is
stowed to `~/.config/herdr/config.toml`. Not in the Ubuntu or
macOS package managers — `scripts/bootstrap.sh` (`ensure_herdr`) installs it via
`herdr.dev/install.sh` there. Same on Arch/Omarchy: one install in `~/.local/bin`,
not the `herdr` pacman package (see [Updating herdr](#updating-herdr)).

Adopted alongside tmux, not instead of it. The `hw` function opens the
home agent; see
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
hw                   # open the home agent (see below)
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
| `prefix a` | Jump to the next agent that needs attention |
| `prefix alt+g` | lazygit in a popup (90% of the screen) |
| `prefix o` | Open the notification target (`open_notification_target`, herdr default) |

Quality-of-life already enabled: mouse support, `new_cwd = "follow"` (splits
and new tabs inherit the current pane's cwd, like tmux's
`-c "#{pane_current_path}"`), and no confirmation prompts on close.

Agent alerts:

- `[ui.toast] delivery = "system"` sends a desktop notification (`notify-send`) when a background agent blocks or finishes, after `delay_seconds = 3`.
- Test it with `herdr notification show prueba`; if nothing appears, use `delivery = "herdr"`.
- The sidebar uses `status_indicators = "symbols"` and `agent_panel_sort = "priority"`.

## `hw`: the home agent

```
usage: hw   (no arguments)
```

Opens one workspace, `home`, with one Claude Code pane in `~/Projects/home`
(the [Home Repo](https://github.com/savaf/home)), and focuses it. That agent
opens a workspace for each project it needs; how it does so lives in the Home
Repo's `AGENTS.md`.

- Idempotent: if a `home` workspace exists, `hw` only focuses it.
- Fails without creating anything when `~/Projects/home` is missing.
- Run from outside a herdr pane: attaches the client afterward. Run from inside
  one (`$HERDR_ENV` set): no nested attach.
- A project by hand: `prefix shift+c` (new workspace).

## Desktop app (`herdr-app`)

A separate program from the TUI: its own window, its own core (`hc`, herdr-core), config in
`~/.config/herdr-app`. It does not share workspaces or agents with the TUI.

| | TUI (`herdr`) | App |
|---|---|---|
| Create | `herdr workspace create` | `herdr-app do space.new` |
| Agents (prompt, wait, read) | `herdr agent …` | `hc …` |
| Detect from an agent | `HERDR_ENV=1` | `HC_TERMINAL_ID` |

### Install and restore on a new machine

1. `scripts/bootstrap.sh` does it all. `ensure_herdr_app` (`scripts/modules/herdr.sh`) runs the official
   installer, `curl -fsSL https://releases.herdr.dev/app/install.sh | sh`: the app goes to
   `~/.local/share/herdr-app` (Linux) or `~/Applications/Herdr.app` (macOS), with the launcher entry, the icon
   and herdr-core (`hc`) if missing. Running it again updates the app; the app also updates itself.
   It is skipped on WSL and on systems without a build. By hand: run that line.
2. Not through mise: the registry's `herdr` is only the TUI (`aqua:herdrdev/herdr`), and the app and the core
   publish no GitHub releases. There is no pacman, AUR or brew package either, so it is not in
   `packages/*.txt`; `packages/arch-apps.txt` carries a comment that points here.
3. `stow_packages` links the `herdr-app` package into `~/.config/herdr-app` (my layouts and mods, see below).
4. `ensure_herdr_app_keys` adds `ctrl-shift-a` under `layout:board-v` in `~/.config/herdr-app/keys.json`
   (the user's file, not stowed; it needs the app to have run once, else it is skipped until the next run).
5. Open the app once and pick the `board-v` layout (`ctrl-shift-l` cycles, or Settings > Look).
6. Statusline numbers (cost, tokens, account limits) need `hooks/statusline.sh`, stowed with the `claude` package.
7. Base spaces and agent instructions live in the Home Repo: `scripts/herdr-app-spaces.sh`, `AGENTS.md`.
8. Check: `herdr-app status` (no `errors`), `herdr-app check ~/.config/herdr-app/mods/board`, `scripts/test-herdr-app.sh`.

### Notes

- `hw` is TUI-only; the app does not need it.
- Base spaces: `scripts/herdr-app-spaces.sh` in the Home Repo creates one space per base repo.
- Move a TUI agent over: `herdr-app do space.new --name <n> --folder <cwd> --argv '["env","CLAUDE_CONFIG_DIR=<home>","claude","--resume","<session-id>"]'`.
  The session id comes from `herdr agent list` (`agent_session.value`). Account homes share `projects/`, so no copy is needed.
- Agent instructions for both live in the Home Repo's `AGENTS.md`.
- My layouts and mods live in the `herdr-app` stow package, file by file: `layouts/board*.json`,
  `mods/board`, `mods/tabs-stats`, `mods/herdrdev-board`. The folder `~/.config/herdr-app` itself is not
  stowed: the app rewrites its shipped mods and layouts at every start and owns `settings.json` and its state,
  so only my own files are linked. The window does not see edits made through the symlinks: after changing a mod,
  switch layout and back (`herdr-app do layout.switch --name main`, then `--name board-v`) to reload it.
  Edit in place, never with `sed -i` (it replaces the symlink with a real file).
- `board-v` is the daily layout: spaces on the left, a vertical agent board (Pinned, Needs you, Working, Done,
  Settled; folding sections), tabs with working time, cost and tokens. Cost and tokens come from
  `hooks/statusline.sh`, which writes `~/.cache/claude-session-stats/<session>.json` on every refresh.
- Keyboard on the `board-v` board: `ctrl-shift-a` (bound in `keys.json` under `layout:board-v`) or `alt-h` / `alt-left`
  from the terminal puts the keyboard on the board. Then `up` / `down` (or `k` / `j`) move, `enter` opens the agent
  (or folds a section), `left` / `right` fold, `p` pins, `s` settles, `z` snoozes for 1h (`shift+z` for 4h; again to
  wake), `u` undoes the last pin, settle or snooze, `/` searches,
  `escape` returns to the terminal. `alt-up` / `alt-down` (agent.prev / agent.next) follow the board's order.
- `herdrdev-board` is the `herdrdev/board` layout from herdr.dev in a dark theme (renamed; `board` is mine).
  Installed from its recipe (herdr.dev/layouts/herdrdev/board); the T3 layout (`JinJieBeWater/herdr-t3`) was not:
  it targets macOS, writes labels onto agents with `hc label` and rewrites its own JSON.

### The `board-v` board

- **Sections:** Pinned, Needs you, Working, Done (finished, not looked at yet), Idle (quiet; folded by default) and
  Settled (put away; folded). Headers fold on click or key. The fold state, pins and settled agents are kept in the
  mod's own `localStorage`, not on the agents; a settled agent comes back by itself when it works or needs you.
- **Rows:** space, title, branch with a `worktree` tag when the folder is under `~/.herdr/worktrees`, cost, tokens,
  `ctx %`, and time in the current state. Blocked rows say why (`Approval`, `Input`, `Failed`, else `Needs you`;
  the field is read defensively and was not tested with a real blocked agent). Hover shows pin and settle.
- **Header:** totals, one usage line per account (Pro: 5h and 7d limits; contracted Enterprise: no counters, so
  the spend and live sessions), account chips (All, URBN, Personal) and a search over name, title, branch and
  program. The window title carries `(N) Herdr` while N agents need you. Sound and toast alerts come from
  Settings > Alerts.
- **Tabs (`tabs-stats`):** working time, cost and tokens per tab, plus the Files and Changes panel buttons
  (always on: the welcome flow left `workspace.panels` empty, which hid them).
- **Data:** `hooks/statusline.sh` writes cost, tokens, `ctx`, model, lines, account and limits per session to
  `~/.cache/claude-session-stats/<session>.json`; `tabs-stats` maps terminal to claude pid to session
  (`~/.claude/sessions/<pid>.json`, any account home) and shares it as `shared("agent.stats")`.
  Only Claude Code agents report; other programs show no numbers.
- **Account types:** the URBN account is Claude Enterprise (contracted billing, extra usage on), the personal one
  is Pro. Org-wide spend is not available from the CLI; it lives in the admin console.
- **Working time:** exact. `tabs-stats` reads `status_ms` (when core last changed the status) with `hc get` every
  15s and shares it as `shared("agent.since")`; the tab and the working/blocked rows use it, so it survives
  restarting the window. Done and Idle rows still show the time since the window first saw them in that state
  (looking at a finished agent changes its status, so core's stamp would restart the clock).
- **Sub-agents:** a row with live children shows a chevron and their count; the children (programs and agents it
  started, nested with tree lines) fold under it. They come from core's parent link (`parent` on each terminal),
  so they are what an agent starts with `hc run`; click focuses an agent or peeks a plain program. That is
  herdr's own definition (`~/.config/herdr-app/AGENTS.md`: sub-agents are terminals an agent started with
  `hc run`), so Claude Code's built-in sub-agents (the Agent tool) are not herdr sub-agents and never show
  there (`sub_agents` stays empty); there is no hook to fix. Agents the Home agent opens with
  `herdr-app do space.new` are separate spaces, not children; `hc run --bg` would make them children.
  Tested with a real child terminal, not with a Claude sub-agent.
- **Snooze and Settle all:** `z` or the clock button hides a finished agent for an hour in a Snoozed section;
  it comes back at that time (with a notification), or at once if it works or needs you. Done and Idle headers
  have a Settle all button. Both live in the mod's own storage and `u` undoes them.
- **Reordering pins:** press on a pinned row, move over another one and release; a line shows where it will land
  and `u` undoes it. The target comes from the measured row heights and the pointer position in the Pinned list.
  Not tested with a real drag (nothing here can press a mouse button); the Pinned list itself was checked.
- **Limits:** the working time can lag up to 15s at the start of a turn; the spend line counts only live
  sessions; the keyboard does not walk into the children, and there is no keyboard way to reorder pins.

## Updating herdr

- All platforms: `herdr update`. The binary lives in `~/.local/bin`.
- Omarchy: remove the `omarchy` repo package with `sudo pacman -R herdr`. It lags behind and nothing depends on it.
- If `omarchy-update` reinstalls it, the `~/.local/bin` copy still wins in `PATH`.
- `herdr status` shows a client/server version mismatch only if something started the server with the other binary.
- Updating replaces the binary only. The running server keeps the old version.
- Restarting the server closes every pane, and the agents in them.
- Restart only with no builders running: `herdr server stop`, then `hw`.
- Do not use `--handoff`: it is experimental and only keeps live agents across a server replacement.
- Afterwards run `herdr integration status`.
- If it shows `claude: outdated`, follow the throwaway-home procedure in
  [Claude Code integration hook](#claude-code-integration-hook).

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

The tracked hook is at integration v11. It only reports the session id on
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
