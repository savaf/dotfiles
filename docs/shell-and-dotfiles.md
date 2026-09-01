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
auto-install on first launch. The prompt is
[Powerlevel10k](https://github.com/romkatv/powerlevel10k); regenerate it anytime
with `p10k configure` (writes `~/.p10k.zsh`, tracked here as `p10k/.p10k.zsh`).

**Prompt colors:** `p10k/.p10k.zsh` uses ANSI indices **0-15** on purpose, not the
256-color indices that `p10k configure` emits. That way the prompt inherits whatever
palette the terminal defines, so it follows the active theme by itself — on Omarchy a
theme change retints it live (even in already-open shells, via OSC), and elsewhere it
just follows your terminal's theme. If you re-run `p10k configure`, convert the
`*_FOREGROUND` values back to 0-15.

## Applying the dotfiles

These dotfiles are managed with [GNU Stow](https://www.gnu.org/software/stow/):
each top-level folder is a *package* whose contents are symlinked into `$HOME`.

The easiest path is the bootstrap, which installs packages and stows everything:

```sh
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Or link packages manually:

```sh
cd ~/dotfiles
stow --no-folding zsh git p10k nvim tmux shell lazygit claude   # link everything
stow --no-folding omarchy                                       # Omarchy only
stow --no-folding nvim                                          # just one package
stow -D nvim                                                    # unlink
stow -R --no-folding zsh                                        # restow after changes
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
for pkg in zsh git p10k nvim tmux shell lazygit claude omarchy; do
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
