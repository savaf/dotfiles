# Neovim (LazyVim)

The Neovim config is a [**LazyVim**](https://www.lazyvim.org/) setup living in
[`nvim/.config/nvim/`](../nvim/.config/nvim/). It's stowed to `~/.config/nvim/`
and works on macOS and Ubuntu/WSL.

Launch with `nvim` (or the aliases `vim` / `vi` / `v` from the zsh config). On the
first launch `lazy.nvim` bootstraps itself, installs all plugins and compiles the
treesitter parsers. The `bootstrap.sh` script also does this headlessly with
`nvim --headless "+Lazy! sync" +qa`.

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
├── lazy-lock.json           # pinned plugin versions (committed, reproducible)
├── stylua.toml / .neoconf.json
```

This is a **stock LazyVim** install (no custom keymaps). Learn the defaults at
<https://www.lazyvim.org/keymaps>. To customize, edit the files under
`lua/config/` and `lua/plugins/` — they're version-controlled and stowed.

## Requirements

All of these are installed by `scripts/install-packages.sh` from the package
lists, except the C compiler (Xcode CLT on macOS / `build-essential` on Linux).

| Tool | Why | Provided by |
|------|-----|-------------|
| Neovim ≥ 0.11.2 (LuaJIT) | core | `neovim` |
| Git ≥ 2.19 | lazy.nvim partial clones | `git` |
| C compiler | nvim-treesitter parsers | Xcode CLT / build-essential |
| `tree-sitter` CLI | treesitter parser builds | auto-installed by Mason on first sync |
| `curl` | blink.cmp completion | `curl` |
| `fzf`, `ripgrep` (`rg`), `fd` | fzf-lua picker / live grep / file find | `fzf`, `ripgrep`, `fd`/`fd-find` |
| `lazygit` | in-editor git UI (`<leader>gg`) | `lazygit` |
| Nerd Font v3+ | icons | `font-*-nerd-font` cask |
| Terminal with truecolor + undercurl | rendering | iTerm2 / WezTerm / kitty |

> On Ubuntu the apt package is `fd-find`; `install-packages.sh` symlinks it to
> `fd`. nvim-treesitter pulls the `tree-sitter` CLI through Mason, so no system
> package is required for it — only the C compiler to compile parsers.

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

After updating plugins (`:Lazy update`), commit the regenerated `lazy-lock.json`
to keep versions reproducible across machines.

## Tips

- New to vim? `:Tutor`. Discover keymaps live with `<leader>` (which-key popup).
- Clipboard provider on Linux/WSL: `xclip`/`wl-clipboard` / `win32yank`
  (built-in on macOS).
