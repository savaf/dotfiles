# Shell & dotfiles

How the shell is set up and how these dotfiles are applied.

## zsh

The default shell is **zsh**. Install it if needed and make it the login shell:

```sh
brew install zsh          # macOS
sudo apt install zsh      # Ubuntu/WSL
chsh -s "$(which zsh)"
```

The configuration is **modular**: `~/.zshrc` is a slim loader that sources
focused files from `~/.config/zsh/`:

| Module | Responsibility |
|--------|----------------|
| `exports.zsh` | locale + environment variables |
| `path.zsh` | Homebrew + `PATH` |
| `plugins.zsh` | zinit, plugins, Oh-My-Zsh snippets, prompt theme |
| `completion.zsh` | `compinit` + completion styling |
| `history.zsh` | history options |
| `keybindings.zsh` | key bindings |
| `aliases.zsh` | aliases (git, eza, bat, docker, `lzg`, …) |
| `functions.zsh` | utility functions (`ex`, `mkcd`, `glog`, …) |
| `integrations.zsh` | fzf, zoxide, nvm, fastfetch, … |

Plugins are managed by [zinit](https://github.com/zdharma-continuum/zinit) and
auto-install on first launch. **The prompt is [Starship](https://starship.rs)**
(see below) — Powerlevel10k stays installed as an untouched rollback path:
`p10k/.p10k.zsh` and the `zinit light romkatv/powerlevel10k` line in
`plugins.zsh` are kept, just commented out. To go back, uncomment both and the
p10k instant-prompt block in `.zshrc`.

## bash

zsh remains the default login shell; bash is a **fully ported, opt-in
migration** — installed and configured everywhere, but switching your login
shell to it is a manual step (see [Switching your login shell](#switching-your-login-shell)
below). zsh is never touched by that switch and stays available as a
one-keystroke fallback (`exec zsh`).

Same modular pattern as zsh: `~/.bashrc` is a slim loader that sources focused
files from `~/.config/bash/`:

| Module | Responsibility |
|--------|----------------|
| `plugins.sh` | installer functions for ble.sh + Starship (called from `.bashrc`/`integrations.sh`) |
| `exports.sh` | locale + environment variables + colored man pages |
| `path.sh` | Homebrew + `PATH` |
| `completion.sh` | bash-completion + related `shopt` |
| `history.sh` | history options (`shopt`/`HISTCONTROL`, live-shared history) |
| `aliases.sh` | aliases (same set as zsh, minus the zsh-only suffix aliases) |
| `functions.sh` | utility functions (same as zsh's `functions.zsh`, portable as-is) |
| `integrations.sh` | fzf, zoxide, nvm, phpbrew, Starship init |

Keybindings live in `bash/.inputrc` (readline, not bash-only — the same
bindings apply to any readline program: `psql`, `python3 -i`, etc.).

**Interactive features**, installed automatically the first time a new bash
shell starts (same self-install pattern zinit uses for zsh — a cheap check,
install only if missing):
- [ble.sh](https://github.com/akinomyoga/ble.sh) — autosuggestions + real-time
  syntax highlighting (the bash equivalent of zsh-autosuggestions +
  zsh-syntax-highlighting combined). Must stay sourced near the very top of
  `.bashrc` and attached (`ble-attach`) as the very last line — don't reorder
  `.bashrc` without keeping that invariant.
- [Starship](https://starship.rs) — see below.
- `bash-completion` is a real system package (`packages/*.txt`), not
  self-installed; `completion.sh` just sources it.

Not ported (no direct bash equivalent, low value relative to the effort):
zsh's suffix aliases (`alias -s md=code`) and the `zsh-you-should-use` plugin.
A subset of the Oh-My-Zsh snippets `plugins.zsh` loads for zsh (sudo's
Esc-Esc-prepend and colored man pages) was hand-ported; the rest
(`command-not-found`, `node`, `pm2`, `bun`) was skipped as low-value/platform-specific
— `command_not_found_handle` in `functions.sh` degrades gracefully outside
Ubuntu/Debian.

### macOS bash version

macOS ships `/bin/bash` 3.2 (frozen since 2007 over licensing). `ensure_bash_installed()`
in `scripts/install-packages.sh` installs a modern bash via Homebrew instead —
same pattern already used for Homebrew itself in `path.sh`.

## Starship (shared prompt)

[Starship](https://starship.rs) is the single prompt config for **both** zsh
and bash, configured in `starship/.config/starship.toml` (its own Stow
package, same idea as `p10k/`). It self-installs the same way ble.sh does —
no manual step needed.

**Prompt colors:** like `p10k/.p10k.zsh`, `starship.toml` uses ANSI indices
**0-15** (`fg:4`, `fg:2`, …) on purpose, not hex/256-color values, so the
prompt follows whatever palette the terminal defines instead of hardcoding a
theme.

## Switching your login shell

Installing/configuring bash (via `bootstrap.sh`/`install-packages.sh`) never
changes your login shell — that's deliberately a separate, manual step so you
can validate the new setup before committing to it, and so it doesn't fight
with the automatic zsh `chsh` that `bootstrap.sh` still runs on every
re-execution:

```sh
./scripts/switch-shell.sh bash   # or: zsh, to go back
```

This registers the target shell in `/etc/shells` if needed, runs `chsh`, and
on Omarchy also re-pins `shell=` in `~/.config/foot/foot.ini` (foot inherits
the frozen `$SHELL` from the uwsm/Hyprland session, not `/etc/passwd` — see
`ensure_omarchy_zsh()` in `install-packages.sh` for the zsh-side of the same
mechanism). tmux's `default-command` follows whichever shell you migrate to
(currently `bash`, see `tmux.conf`) independently of your login shell.

## Applying the dotfiles

These dotfiles are managed with [GNU Stow](https://www.gnu.org/software/stow/):
most top-level folders are a *package* whose contents are symlinked into
`$HOME` (see [repository structure](../README.md#repository-structure) for
the non-Stow exceptions).

The easiest path is the bootstrap, which installs packages and stows everything:

```sh
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Or link packages manually:

```sh
cd ~/dotfiles
stow --no-folding zsh bash git p10k starship nvim tmux herdr shell lazygit claude   # link everything
stow --no-folding omarchy                                             # Omarchy only
stow --no-folding nvim                                                # just one package
stow -D nvim                                                          # unlink
stow -R --no-folding zsh                                              # restow after changes
```

`--no-folding` matches what the bootstrap does: it links every file individually instead of
symlinking whole directories, so apps that write new files into `~/.config/<tool>/` do not
end up writing them into the repo.

The bootstrap backs up any conflicting real files to
`~/.dotfiles-backup/<timestamp>/` before linking.

### When a symlink turns back into a real file

Some apps rewrite their config by writing a temp file and `mv`-ing it over the target. `mv`
replaces the symlink with a regular file, so the repo stops receiving the changes and the
next `stow` aborts with a conflict. Known cases on Omarchy: `~/.config/omarchy/shell.json`
(any `omarchy bar …` command) and `~/.config/hypr/monitors.lua` (the quattro upgrade).

Find every package file that is no longer a link to the repo:

```sh
cd ~/dotfiles
for pkg in zsh bash git p10k starship nvim tmux herdr shell lazygit claude omarchy; do
  [ -d "$pkg" ] || continue
  find "$pkg" -type f | while read -r f; do
    t="$HOME/${f#$pkg/}"
    [ -L "$t" ] || { [ -e "$t" ] && echo "DIVERGED $t"; }
  done
done
```

Resolve one by deciding which side wins, then re-link:

```sh
stow --adopt --no-folding <pkg>   # pull the live file INTO the repo, then git diff
git diff                          # keep it, or `git checkout --` to keep the repo version
```

## Other CLI tools

This config assumes a modern CLI toolset (installed via the package lists):
`eza`, `bat`, `fzf`, `zoxide`, `ripgrep`/`fd`, `neovim`, `tldr`, plus
`ffmpeg` and `imagemagick` for media work. See [`packages/`](../packages).
