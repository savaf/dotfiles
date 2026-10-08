# Shell & dotfiles

How the shell is set up and how these dotfiles are applied.

## zsh

zsh is the **default** shell (the alternative is [bash](#bash)). It stays fully
configured and installed by the bootstrap, which also `chsh`es to it. Go back to it
any time with `./scripts/switch-shell.sh zsh` (see [Switching your login shell](#switching-your-login-shell)).

The configuration is **modular**: `~/.zshrc` is a slim loader that sources
focused files from `~/.config/zsh/`:

| Module | Responsibility |
|--------|----------------|
| `exports.zsh` | locale + environment variables |
| `path.zsh` | Homebrew + `PATH` |
| `plugins.zsh` | zinit, plugins, Oh-My-Zsh snippets, prompt theme |
| `completion.zsh` | completion styling + fzf-tab previews + compinit |
| `history.zsh` | history options (50k, timestamps, shared) |
| `options.zsh` | `setopt`: autocd, auto_pushd, extended_glob… |
| `keybindings.zsh` | key bindings |
| `aliases.zsh` | aliases (git, eza, bat, docker, `lzg`, …) |
| `functions.zsh` | utility functions (`ex`, `mkcd`, `glog`, …) |
| `integrations.zsh` | fzf, zoxide, nvm, fastfetch, … |

Plugins are managed by [zinit](https://github.com/zdharma-continuum/zinit) and
auto-install on first launch. **The prompt is [Starship](https://starship.rs)**
(see below).

## bash

bash is the **alternative shell**: `bootstrap.sh`/`install-packages.sh`
install it (Homebrew's modern bash on macOS) but never `chsh` to it. It stays
available as a one-keystroke fallback (`exec bash`) or a permanent switch (see [Switching your login shell](#switching-your-login-shell)
below).

Same modular pattern as zsh: `~/.bashrc` is a slim loader that sources focused
files from `~/.config/bash/`:

| Module | Responsibility |
|--------|----------------|
| `plugins.sh` | installer functions for ble.sh + Starship (called from `.bashrc`/`integrations.sh`) |
| `exports.sh` | locale + environment variables + colored man pages |
| `path.sh` | Homebrew + `PATH` |
| `completion.sh` | bash-completion + related `shopt` |
| `history.sh` | history options (`shopt`/`HISTCONTROL`, live-shared history) |
| `git.sh` | puerto del plugin git de OMZ (`gco`, `gfo`, `ggp`…; generado desde `OMZP::git`) |
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
package). It self-installs the same way ble.sh does —
no manual step needed.

**Prompt colors:** `starship.toml` uses ANSI indices
**0-15** (`fg:4`, `fg:2`, …) on purpose, not hex/256-color values, so the
prompt follows whatever palette the terminal defines instead of hardcoding a
theme.

## Switching your login shell

The bootstrap (`ensure_zsh()` in `install-packages.sh`) sets zsh as your login
shell on every run; `ensure_bash_installed()` only installs bash and registers
it in `/etc/shells`. So if you switch to bash permanently, re-running the
bootstrap will `chsh` back to zsh — run `switch-shell.sh bash` again after it.
To alternate by hand:

```sh
./scripts/switch-shell.sh zsh    # or: bash
```

This registers the target shell in `/etc/shells` if needed, runs `chsh`, and
on Omarchy also re-pins `shell=` in `~/.config/foot/foot.ini` (foot inherits
the frozen `$SHELL` from the uwsm/Hyprland session, not `/etc/passwd` — see
`ensure_omarchy_zsh()` in `install-packages.sh`). tmux's `default-command`
is `bash` (see `tmux.conf`) independently of your login shell.

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
stow --no-folding zsh bash git starship nvim tmux herdr shell lazygit claude   # link everything
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
for pkg in zsh bash git starship nvim tmux herdr shell lazygit claude omarchy; do
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
