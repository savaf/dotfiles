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
| `integrations.zsh` | fzf, zoxide, nvm, neofetch, … |

Plugins are managed by [zinit](https://github.com/zdharma-continuum/zinit) and
auto-install on first launch. The prompt is
[Powerlevel10k](https://github.com/romkatv/powerlevel10k); regenerate it anytime
with `p10k configure` (writes `~/.p10k.zsh`, tracked here as `p10k/.p10k.zsh`).

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
stow zsh git p10k nvim tmux shell lazygit   # link everything
stow nvim                                     # just one package
stow -D nvim                                  # unlink
stow -R zsh                                   # restow after changes
```

The bootstrap backs up any conflicting real files to
`~/.dotfiles-backup/<timestamp>/` before linking.

## Other CLI tools

This config assumes a modern CLI toolset (installed via the package lists):
`eza`, `bat`, `fzf`, `zoxide`, `ripgrep`/`fd`, `neovim`, `tldr`, plus
`ffmpeg` and `imagemagick` for media work. See [`packages/`](../packages).
