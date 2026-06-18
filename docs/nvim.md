# Neovim

The Neovim config lives in [`nvim/.config/nvim/init.lua`](../nvim/.config/nvim/init.lua):
a single, minimal, **plugin-manager-free** Lua file that works out of the box on
Ubuntu/WSL and macOS. It's stowed to `~/.config/nvim/init.lua`.

Launch with `nvim` (or the aliases `vim` / `vi` / `v` defined in the zsh config).

## What it sets up

- **Leader key** is `Space` (`<leader>`).
- Line numbers (absolute + relative), mouse, and the **system clipboard**
  (`unnamedplus`) so yank/paste works with the OS.
- Persistent **undo** (survives restarts), no swap files, confirm-on-quit.
- True color, always-on sign column, current-line highlight, 8 lines of scroll
  context, no line wrap, splits open right/below.
- 2-space indentation with `expandtab` (spaces, not tabs) and `smartindent`.
- Smart-case search (case-insensitive unless you type an uppercase letter).
- Brief highlight on yanked text.

## Keymaps

> `<leader>` is `Space`.

| Mode | Keys | Action |
|------|------|--------|
| Normal | `<leader>w` | Save file |
| Normal | `<leader>q` | Quit |
| Normal | `<leader>h` | Clear search highlight |
| Normal | `Ctrl-h/j/k/l` | Move between split windows |
| Visual | `J` / `K` | Move the selected lines down / up |

Everything else is stock Neovim. A few essentials if you're new to vim:

| Keys | Action |
|------|--------|
| `i` / `a` | Insert before / after cursor · `Esc` to leave insert mode |
| `:w` / `:q` / `:wq` | Write · quit · write & quit |
| `dd` / `yy` / `p` | Delete line · yank line · paste |
| `v` / `V` / `Ctrl-v` | Visual · visual-line · visual-block select |
| `/text` then `n`/`N` | Search forward, next / previous match |
| `:%s/old/new/g` | Replace in the whole file |
| `gg` / `G` | Top / bottom of file |
| `u` / `Ctrl-r` | Undo / redo |

## Working with splits

```
:vsplit   " or Ctrl-w v  -> vertical split
:split    " or Ctrl-w s  -> horizontal split
```

Then jump around with `Ctrl-h/j/k/l` (mapped here).

## Extending it

The config is deliberately dependency-free so it works on a fresh machine. When
you want LSP, treesitter, fuzzy finding, etc., add a plugin manager such as
[lazy.nvim](https://github.com/folke/lazy.nvim) and split your config into
`lua/` modules. Keep `init.lua` as the entry point so stow keeps managing it.

## Tips

- Check health: `:checkhealth`.
- See a mapping: `:verbose nmap <leader>w`.
- The clipboard integration needs a provider: `xclip`/`wl-clipboard` on Linux,
  `win32yank` on WSL, built-in on macOS.
