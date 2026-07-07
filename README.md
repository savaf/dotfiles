# Dotfiles

Cross-platform dotfiles for **Ubuntu/WSL**, **Fedora/Bazzite**, **Arch/Omarchy** and **macOS**, organized as
[GNU Stow](https://www.gnu.org/software/stow/) packages.

## Contents

- [Repository structure](#repository-structure)
- [Requirements](#requirements)
- [Quick start (recommended)](#quick-start-recommended)
- [Manual usage with Stow](#manual-usage-with-stow)
- [Package lists](#package-lists)
- [Notes](#notes)
- [Setup guides](#setup-guides)

## Repository structure

Each top-level folder is a Stow *package*: running `stow <package>` symlinks
its contents into `$HOME`, preserving the internal directory layout.

```
dotfiles/
├── zsh/            # .zshrc (slim loader) + .config/zsh/*.zsh modules
├── git/            # .gitconfig + .config/git/ignore
├── p10k/           # .p10k.zsh (Powerlevel10k prompt)
├── nvim/           # .config/nvim/ (LazyVim distribution)
├── tmux/           # .config/tmux/tmux.conf
├── lazygit/        # .config/lazygit/config.yml (terminal UI for git)
├── shell/          # .profile
├── vscode/         # settings.json (symlinked per-OS by a script)
├── wsl/            # .wslconfig (copied to the Windows profile on WSL)
├── packages/       # package lists (brew/apt/dnf/node/vscode extensions)
├── scripts/        # bootstrap + install/sync helpers
├── docs/           # setup guides (macOS, shell, git/ssh, lazygit, …)
└── README.md
```

The `zsh` config is modular: `zsh/.zshrc` is a slim loader that sources focused
files from `~/.config/zsh/` (`exports`, `path`, `plugins`, `completion`,
`history`, `keybindings`, `aliases`, `functions`, `integrations`). See
[docs/shell-and-dotfiles.md](docs/shell-and-dotfiles.md).

## Requirements

`git` and `stow` (the bootstrap installs `stow` for you if missing):

```sh
sudo apt install git stow   # Ubuntu/WSL
sudo dnf install git stow   # Fedora (Bazzite ships both in the base image)
sudo pacman -S git stow     # Arch/Omarchy
brew install git stow       # macOS
```

## Quick start (recommended)

Clone the repo and run the single bootstrap entry point. It detects the OS,
installs base packages, stows the config packages, syncs VS Code, installs
global node packages, and applies OS-specific extras (macOS defaults / WSL
`.wslconfig`).

```sh
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

The bootstrap backs up any conflicting real files to
`~/.dotfiles-backup/<timestamp>/` before linking.

## Manual usage with Stow

To link (or unlink) individual packages yourself:

```sh
cd ~/dotfiles
stow zsh git p10k nvim tmux shell lazygit   # link everything
stow nvim                                    # link just one package
stow -D nvim                                 # unlink (remove symlinks)
stow -R zsh                                   # restow (refresh) after changes
```

## Package lists

Reproducible package manifests live in `packages/`:

```sh
xargs brew install < packages/brew-cli.txt          # macOS CLI
xargs brew install --cask < packages/brew-casks.txt # macOS apps
sudo xargs -a packages/apt-cli.txt apt install -y   # Ubuntu/WSL CLI
grep -v '^#' packages/dnf-cli.txt | xargs sudo dnf install -y  # Fedora CLI (Bazzite: rpm-ostree install)
grep -v '^#' packages/pacman-cli.txt | xargs sudo pacman -S --needed  # Arch/Omarchy CLI
```

VS Code settings (`vscode/settings.json`) are symlinked to the OS-specific
location by `scripts/sync-vscode-settings.sh`, and extensions are installed from
`packages/vs-extensions.txt`. See [docs/vscode.md](docs/vscode.md).

## Notes

- **WSL `.wslconfig`** is read by Windows from your Windows user profile, not the
  Linux `$HOME`. The bootstrap copies it to `C:\Users\<you>\.wslconfig`; apply
  changes with `wsl --shutdown`.
- **Powerlevel10k**: regenerate the prompt anytime with `p10k configure` (writes
  `~/.p10k.zsh`, which is this repo's `p10k/.p10k.zsh`).
- **lazygit**: launch with `lzg`. See [docs/lazygit.md](docs/lazygit.md).

## Setup guides

Step-by-step guides for a fresh machine live in [`docs/`](docs):

| Guide | What it covers |
|-------|----------------|
| [shell-and-dotfiles.md](docs/shell-and-dotfiles.md) | zsh modules, prompt, and applying the dotfiles with Stow |
| [ubuntu-wsl.md](docs/ubuntu-wsl.md) | Ubuntu & WSL2 setup from scratch (incl. `.wslconfig`, fonts) |
| [bazzite.md](docs/bazzite.md) | Fedora & Bazzite (immutable) setup — dnf / rpm-ostree |
| [omarchy.md](docs/omarchy.md) | Arch & Omarchy (Hyprland) setup — pacman, switching to zsh |
| [macos-setup.md](docs/macos-setup.md) | macOS system preferences, apps, Homebrew, iTerm2 |
| [git-and-ssh.md](docs/git-and-ssh.md) | Git defaults and GitHub SSH key setup |
| [nodejs.md](docs/nodejs.md) | Node.js via nvm and global modules |
| [vscode.md](docs/vscode.md) | VS Code settings and extensions |
| [nvim.md](docs/nvim.md) | Neovim (LazyVim) setup, requirements and basics |
| [tmux.md](docs/tmux.md) | tmux prefix, panes/windows and copy mode |
| [lazygit.md](docs/lazygit.md) | lazygit keybindings and workflows |
| [hardware.md](docs/hardware.md) | My machines, for reference |
