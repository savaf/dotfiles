# Herdr desktop app

Everything about the desktop app (`herdr-app`): what it is, how it is installed and restored, where its
files live, my layouts and mods, the `horde` UI, how agents work with it, and how to copy the UI.
The terminal multiplexer (`herdr`, `hw`) is in [`herdr.md`](herdr.md).

## What it is

A separate program from the TUI: its own window, its own core (`hc`, herdr-core), config in
`~/.config/herdr-app`. It does not share workspaces or agents with the TUI.

| | TUI (`herdr`) | App |
|---|---|---|
| Hierarchy | session > workspace > tab > pane | space > tab > terminal |
| Create | `herdr workspace create` | `herdr-app do space.new` |
| Agents (prompt, wait, read) | `herdr agent …` | `hc …` |
| Detect from an agent | `HERDR_ENV=1` | `HC_TERMINAL_ID` |
| Config | `~/.config/herdr/config.toml` | `~/.config/herdr-app/` (layouts, mods, `keys.json`, `settings.json`) |

- `herdr-app` draws the window (spaces, tabs, layouts, panels); `hc` runs the terminals and agents and keeps
  them alive when the window closes. Never stop or restart the app or the core from an agent.
- `hw` is TUI-only; the app does not need it.

### Where things live

| Path | What |
|---|---|
| `~/.local/share/herdr-app/` (macOS: `~/Applications/Herdr.app`) | The app binary, installed by the official installer |
| `~/.local/bin/herdr-app`, `~/.local/bin/hc` | Launchers |
| `~/.config/herdr-app/AGENTS.md` | The app's own manual, for agents. Read it before changing anything |
| `~/.config/herdr-app/layouts/`, `mods/` | Layouts and mods. Herdr's own are rewritten at every start |
| `~/.config/herdr-app/keys.json`, `settings.json` | Keys and settings (mine; not stowed) |
| `~/.config/herdr-app/data/<mod>/store-*.json` | Each mod's `localStorage` (pins, settled, folds…) |
| `~/.cache/claude-session-stats/<session>.json` | Cost, tokens and limits written by `hooks/statusline.sh` |
| `~/.herdr/worktrees/<repo>/<slug>` | Worktrees, one per issue (rule in the Home Repo's `AGENTS.md`) |

## Install and restore on a new machine

1. `scripts/bootstrap.sh` does it all. `ensure_herdr_app` (`scripts/modules/herdr.sh`) runs the official
   installer, `curl -fsSL https://releases.herdr.dev/app/install.sh | sh`: the app goes to
   `~/.local/share/herdr-app` (Linux) or `~/Applications/Herdr.app` (macOS), with the launcher entry, the icon
   and herdr-core (`hc`) if missing. Running it again updates the app; the app also updates itself.
   It is skipped on WSL and on systems without a build. By hand: run that line.
2. Not through mise: the registry's `herdr` is only the TUI (`aqua:herdrdev/herdr`), and the app and the core
   publish no GitHub releases. There is no pacman, AUR or brew package either, so it is not in
   `packages/*.txt`; `packages/arch-apps.txt` carries a comment that points here.
3. `stow_packages` links the `herdr-app` package into `~/.config/herdr-app` (my layouts and mods, see below).
4. `ensure_herdr_app_keys` adds `ctrl-shift-a` under `layout:horde` in `~/.config/herdr-app/keys.json`
   (the user's file, not stowed; it needs the app to have run once, else it is skipped until the next run).
5. Open the app once and pick the `horde` layout (`ctrl-shift-l` cycles, or Settings > Look).
6. Statusline numbers (cost, tokens, account limits) need `hooks/statusline.sh`, stowed with the `claude` package.
7. Base spaces and agent instructions live in the Home Repo: `scripts/herdr-app-spaces.sh`, `AGENTS.md`.
8. Check: `herdr-app status` (no `errors`), `herdr-app check ~/.config/herdr-app/mods/horde-board`,
   `scripts/test-herdr-app.sh`.

## My config: the `herdr-app` stow package

`herdr-app/.config/herdr-app/` holds only my own files, linked file by file (`--no-folding`):

| File | What |
|---|---|
| `layouts/horde.json` | The daily layout (sidebar with spaces and the vertical board, tabs on top) |
| `layouts/board.json` | Three columns (Needs you, Working, Done) with the tab bar and the terminal below |
| `layouts/herdrdev-board.json` | `herdrdev/board` from herdr.dev, renamed and in a dark theme |
| `mods/horde-board/` | The agent board (vertical mode used by `horde`, columns mode by `board`) |
| `mods/horde-tabs/` | A clone of the shipped `tabs` bar: working time, cost, tokens and the Files / Changes buttons |
| `mods/herdrdev-board/` | The mod of `herdrdev-board` |

The folder itself is not stowed: the app rewrites its shipped mods and layouts at every start and owns
`settings.json` and its state. A `.gitignore` in the package skips what the app generates in each mod
(`gpui-kit.d.ts`, `jsconfig.json`).

Working on it:

- Edit the files in `~/dotfiles/herdr-app/.config/herdr-app/…`, in place. Never use `sed -i` there or in
  `~/.config/herdr-app`: it replaces the symlink with a real file.
- The window does not see edits made through the symlinks. After changing a mod, switch layout and back:
  `herdr-app do layout.switch --name main`, then `--name horde`.
- `herdr-app check <mod folder>` loads a mod once and reports errors. Run it after every change.
- `~/dotfiles` must stay on a branch that contains the `herdr-app` package: the links point into the working
  tree, so on any other branch they dangle and the layout and mods break.
- Installing someone else's layout or mod: read its `RECIPE.md` and every file first, say whether a mod reaches
  the network, runs programs or reads outside its folder, never overwrite (rename on a clash), `herdr-app check`,
  then `layout.switch`. `herdrdev/board` was installed that way. The T3 layout (`JinJieBeWater/herdr-t3`) was not:
  it targets macOS, writes labels onto agents with `hc label` and rewrites its own JSON.

## The `horde` UI

Spaces on the left, a vertical agent board under them, tabs on top, the active terminal in the middle, optional
Files and Changes panels on the right, a status bar at the bottom. The recipe to rebuild it from scratch is
[`herdr-app/RECIPE.md`](herdr-app/RECIPE.md).

**Sections** (all fold on click or key): Pinned, Needs you, Working, Done (finished, not looked at yet), Idle
(quiet; folded by default), Snoozed and Settled (folded). Pins, settled, snoozed and fold state live in the mod's
own storage, not on the agents.

**Rows:** space, title, branch with a `worktree` tag when the folder is under `~/.herdr/worktrees`, cost, tokens,
`ctx %`, and time in the current state. Blocked rows say why (`Approval`, `Input`, `Failed`, else `Needs you`; the
field is read defensively and was not tested with a real blocked agent). Hover shows snooze, settle and pin.

**Header:** totals, one usage line per account (Pro: 5h and 7d limits; contracted Enterprise: no counters, so the
spend and live sessions), account chips (All, URBN, Personal) and a search over name, title, branch and program.
The window title carries `(N) Herdr` while N agents need you. Sound and toast alerts come from Settings > Alerts.

**Tabs (`horde-tabs`):** working time, cost and tokens per tab, plus the Files and Changes panel buttons (always
on: the welcome flow left `workspace.panels` empty, which hid them).

**Keyboard:** `ctrl-shift-a` (bound in `keys.json` under `layout:horde`) or `alt-h` / `alt-left` from the
terminal puts the keyboard on the board.

| Key | Does |
|---|---|
| `up` / `down` (`k` / `j`), `home` / `end` | Move |
| `enter` / `space` | Open the agent, or fold a section |
| `left` / `right` | Fold / unfold (left on a row goes to its header) |
| `p` | Pin or unpin |
| `s` | Settle (put away until it works or needs you), or bring back |
| `z` / `shift+z` | Snooze 1h / 4h; again to wake |
| `u` | Undo the last pin, settle, snooze or reorder |
| `/` | Search |
| `escape` | Back to the terminal |

`alt-up` / `alt-down` (`agent.prev` / `agent.next`) follow the board's order.

**Pins, snooze, settle:** drag a pinned row onto another to reorder (a line shows where it lands). Snooze hides a
finished agent until a time, then it returns with a notification, or at once if it works or needs you. Settle all
sits in the Done and Idle headers.

**Sub-agents:** a row with live children shows a chevron and their count; the children fold under it. They come
from core's parent link, so they are what an agent starts with `hc run`. That is herdr's own definition, so
Claude Code's built-in sub-agents (the Agent tool) never show there. Agents opened with `herdr-app do space.new`
are separate spaces, not children; `hc run --bg` would make them children.

### Data pipeline

- `hooks/statusline.sh` writes cost, tokens, `ctx`, model, lines, account and 5h / 7d limits per session to
  `~/.cache/claude-session-stats/<session>.json`.
- `horde-tabs` maps each terminal to its Claude pid (`hc get`), to the session
  (`~/.claude/sessions/<pid>.json`, any account home) and to that file. It shares the result as
  `shared("agent.stats")` and, from `status_ms`, the exact time in each state as `shared("agent.since")`.
  Only Claude Code agents report; other programs show no numbers.
- Account types: the URBN account is Claude Enterprise (contracted billing, extra usage on), the personal one is
  Pro. Org-wide spend is not available from the CLI; it lives in the admin console.

## Copy this UI

`horde` is published as a Herdr gallery layout in its own public repo,
[`savaf/horde`](https://github.com/savaf/horde) (the layout sits at the repo root, topic `herdr-layout`, so it
shows up at `herdr.dev/layouts/savaf/horde` within the hour). To add it to any Herdr setup, paste this to the
agent:

```text
Read ~/.config/herdr-app/AGENTS.md, then add this layout: https://github.com/savaf/horde
```

The repo carries the layout, its two mods (`horde-board`, `horde-tabs`), a `keys.json` with the one key it needs, the
brief ([`RECIPE.md`](herdr-app/RECIPE.md): what you see, how it behaves, built from, watch out, done when), a
`preview.png`, and an optional `extras/statusline-snippet.sh` that feeds cost, tokens and plan limits from Claude
Code's statusline (without it everything else works). By hand, the README of that repo has the five commands.

- The repo is a copy: this dotfiles repo is where the layout is worked on (`herdr-app/.config/herdr-app/`) and
  where `docs/herdr-app/RECIPE.md` lives. After changing the layout or the mods, copy the files into
  `~/Projects/lab/horde/` (the repo root; rename nothing; drop `cloned_from` from the JSON files; the layout's
  `preview` is `layouts/horde.svg`), re-render `preview.png` if the UI changed, and push.
- The repo's recipe says `Team` where this one's examples use real account names; keep it generic there.
- Do not put screenshots of the real window in the repo: they show the terminals.

## Agents and the app

- A single agent (the Home agent) opens the rest. The rules, the detection by `HC_TERMINAL_ID` and the commands
  live in the Home Repo's `AGENTS.md`: `herdr-app do space.new … --argv '["claude-9r"]' --task "…"` to open one,
  `hc wait`, `hc read`, `hc send` to follow it. `claude-9r` runs Claude Code against 9router.
- One worktree per issue, in `~/.herdr/worktrees/<repo>/<slug>`; the base spaces are for reading only.
- Move a TUI agent over: `herdr-app do space.new --name <n> --folder <cwd> --argv '["claude-9r","--resume","<session-id>"]'`.
  The session id comes from `herdr agent list` (`agent_session.value`). Account homes share `projects/`, so no
  copy is needed.

## Everyday commands

```sh
herdr-app ls                         # spaces > tabs > terminals, with agent status
herdr-app status                     # layout, focus, errors from mods and layouts
herdr-app commands                   # every command and its arguments
herdr-app do layout.switch --name horde
herdr-app do space.new --name <n> --folder <dir> --argv '["claude-9r"]' --task "<task>" --focus false
herdr-app check <mod folder>         # load a mod once and report errors
herdr-app shot <file.png>            # save the current window (it shows your terminals: do not commit it)
hc ls                                # every live terminal; hc get <t> for one (pid, status_ms, parent)
hc wait <t>   hc read --lines 100 <t>   hc send <t> "<text>"
```

## Known limits and what was not tested

- Tested with real keys (see Testing the keyboard): moving, folding, `enter`, `p`, `s`, `z`, `shift+z`, `u`, `/`,
  `escape`, `home` / `end`, `alt-h` and `ctrl-shift-a`.
- Not tested with real input: dragging pins, snooze waking by time, the reason shown on
  blocked rows (`Approval`, `Input`, `Failed`), a window restart for the exact working time, and the real installer
  (`scripts/test-herdr-app.sh` uses a fake `curl`).
- Working time can lag up to 15s at the start of a turn; Done and Idle rows time from when the window first saw
  them in that state; the spend line counts only live sessions.
- The keyboard does not walk into children rows, and there is no keyboard way to reorder pins.
- Left out on purpose from the T3 layout: a Home page after settling, Clean up and Review (the Changes panel covers
  the essentials).

## Testing the keyboard

On Hyprland the board's keys can be tested for real, with no one at the keyboard. Give the board the keyboard, then
send keys to the app window; check the result in the mod's storage (`~/.config/herdr-app/data/horde-board/`) or with
`herdr-app shot`:

```sh
herdr-app do horde-board.focus
send() { hyprctl eval "hl.dispatch(hl.dsp.send_shortcut({ mods = \"${2:-}\", key = \"$1\", window = \"class:herdr-app\" }))"; }
send Down            # a harmless first key: the cursor ring should appear on the first header
send p               # pin; send z SHIFT for shift+z; send a "CTRL SHIFT" for ctrl-shift-a
```

- Keys go to whatever has the keyboard: if the board does not, they land in an agent's terminal. Start with `Down`
  and look before sending letters or `Enter`; after `Enter` or `Escape` the keyboard is in a terminal.
- Back up the store first and restore it after (copy it back, then switch layout and back): pins, settled and
  snoozed persist. The account chip is the user's choice, so leave it alone.
- Hyprland 0.56 uses Lua dispatchers (`hyprctl eval`); older versions take `hyprctl dispatch sendshortcut`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Layout or mods broken, `no main.js` in `herdr-app status` | `~/dotfiles` is on a branch without the `herdr-app` package; check out one that has it, or `main` after merging |
| A mod edit does not show | Switch layout and back (see above) |
| A mod stopped following edits | `sed -i` turned its symlink into a real file; copy it back into the repo, delete the real file, `stow --no-folding -d ~/dotfiles --target=$HOME herdr-app` |
| `stow` refuses to link | A real file is in the way (often an app-generated `jsconfig.json` or `.d.ts` inside the package); delete that copy from the repo |
| No cost / tokens on a tab | The agent is not Claude Code, or its statusline has not refreshed since `hooks/statusline.sh` was updated |
| `ensure_herdr_app` did nothing | WSL or an unsupported system, or `~/.local/bin/herdr-app` already exists |
