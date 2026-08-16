# Neovim (LazyVim)

The Neovim config is a [**LazyVim**](https://www.lazyvim.org/) setup living in
[`nvim/.config/nvim/`](../nvim/.config/nvim/). It's stowed to `~/.config/nvim/`
and works on macOS and Ubuntu/WSL.

Launch with `nvim` (or the aliases `vim` / `vi` / `v` from the zsh config). On the
first launch `lazy.nvim` bootstraps itself, installs all plugins and compiles the
treesitter parsers. The `bootstrap.sh` script also does this headlessly with
`nvim --headless "+Lazy! install" "+Lazy! restore" +qa`.

`lazy-lock.json` is **not** version-controlled (it's in `.gitignore`): on Omarchy the
desktop theme injects its own plugin specs into `~/.config/nvim/lua/plugins/`, so the
lock differs per machine by design and committing it produced churn on every Omarchy
update. Each machine keeps its own lock; plugin versions come from the specs, not from
a shared lock.

## Layout

```
nvim/.config/nvim/
├── init.lua                 # entry point → require("config.lazy")
├── lua/config/lazy.lua      # bootstraps lazy.nvim + LazyVim
├── lua/config/options.lua   # your option overrides (empty = LazyVim defaults)
├── lua/config/keymaps.lua   # your keymap overrides (empty = LazyVim defaults)
├── lua/config/autocmds.lua  # your autocmd overrides
├── lua/plugins/             # your plugin specs / overrides
├── lazyvim.json             # enabled LazyVim extras
├── lazy-lock.json           # pinned plugin versions (per-machine, gitignored)
├── stylua.toml / .neoconf.json
```

This is a **stock LazyVim** install (no custom keymaps). Learn the defaults at
<https://www.lazyvim.org/keymaps>. To customize, edit the files under
`lua/config/` and `lua/plugins/` — they're version-controlled and stowed.

## Requirements

All of these are installed automatically by the bootstrap. On Linux the C
compiler ships as `build-essential` in the apt list. On macOS it comes from the
Xcode Command Line Tools, which Homebrew's installer pulls in on a clean Mac;
`ensure_xcode_clt` also triggers `xcode-select --install` (a one-time GUI
prompt) as a guard.

| Tool | Why | Provided by |
|------|-----|-------------|
| Neovim ≥ 0.11.2 (LuaJIT) | core | `neovim` |
| Git ≥ 2.19 | lazy.nvim partial clones | `git` |
| C compiler | nvim-treesitter parsers | `build-essential` (Linux) / Xcode CLT (macOS) |
| `tree-sitter` CLI | treesitter parser builds | auto-installed by Mason on first sync |
| `curl` | blink.cmp completion | `curl` |
| Node.js | `lang.typescript` LSP, Mason servers, node globals | `nvm` (installed by `bootstrap.sh`) |
| `fzf`, `ripgrep` (`rg`), `fd` | fzf-lua picker / live grep / file find | `fzf`, `ripgrep`, `fd`/`fd-find` |
| `lazygit` | in-editor git UI (`<leader>gg`) | `lazygit` |
| clipboard | yank to system clipboard | `xclip`/`wl-clipboard` (Linux) / built-in (macOS) |
| Nerd Font v3+ | icons | `ensure_nerd_font` → Monaspace (Linux) / `font-*-nerd-font` cask (macOS) |
| Terminal with truecolor + undercurl | rendering | iTerm2 / WezTerm / kitty |

> On Ubuntu the apt package is `fd-find`; `install-packages.sh` symlinks it to
> `fd`. nvim-treesitter pulls the `tree-sitter` CLI through Mason, so no system
> package is required for it — only the C compiler to compile parsers.
> Node is provisioned via `nvm` (so it's modern enough for the TS server).

## Enabled extras

Tracked in `lazyvim.json`, managed with `:LazyExtras`:

- `lang.typescript` — TS/JS LSP, formatting (needs node, already installed)
- `lang.json`, `lang.yaml`, `lang.markdown`

LSP servers/formatters install on demand via **Mason** (`:Mason`).

## Day-to-day

| Command | Action |
|---------|--------|
| `<leader><space>` | Find files (uses `fd`) |
| `<leader>/` | Live grep (uses `rg`) |
| `<leader>e` | File explorer |
| `<leader>gg` | lazygit |
| `:Lazy` | Plugin manager UI (install/update/clean) |
| `:LazyExtras` | Enable/disable language & feature extras |
| `:Mason` | Manage LSP servers, linters, formatters |
| `:checkhealth lazy` / `:checkhealth lazyvim` | Verify requirements are met |

Update plugins with `:Lazy update` on each machine. The regenerated `lazy-lock.json`
stays local (gitignored), so there's nothing to commit and nothing to restore from a
shared lock — `:Lazy restore` only re-pins to *this* machine's lock.

## Colorscheme

On Omarchy the colorscheme comes from the desktop theme: `~/.config/nvim/lua/plugins/`
holds a few unversioned files installed by Omarchy, among them `theme.lua` (a symlink to
the generated `…/current/theme/neovim.lua`, i.e. `aether.nvim`) and a hot-reload plugin
that re-applies it without restarting Neovim. They coexist with the stowed specs, which
link file by file. Elsewhere, LazyVim's default colorscheme applies.

## Tips

- New to vim? `:Tutor`. Discover keymaps live with `<leader>` (which-key popup).
- IDE cockpit: run `nic [session]` (zsh function) to open a tmux session with
  LazyVim and Claude Code side by side; re-attaches if it already exists.
- Clipboard provider: `xclip`/`wl-clipboard` are installed automatically on
  Linux (built-in on macOS). On WSL the system clipboard goes through
  `win32yank`, which you install manually on the Windows side.
