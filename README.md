# Dotfiles

[![CI](https://github.com/savaf/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/savaf/dotfiles/actions/workflows/ci.yml)

Cross-platform dotfiles for **Ubuntu/WSL**, **Arch/Omarchy** and **macOS**, organized as
[GNU Stow](https://www.gnu.org/software/stow/) packages.

## Contents

- [Repository structure](#repository-structure)
- [Requirements](#requirements)
- [Quick start (recommended)](#quick-start-recommended)
- [Manual usage with Stow](#manual-usage-with-stow)
- [Package lists](#package-lists)
- [Checks](#checks)
- [Notes](#notes)
- [Setup guides](#setup-guides)

## Repository structure

Most top-level folders are a Stow *package*: running `stow <package>` symlinks
its contents into `$HOME`, preserving the internal directory layout.
`packages/`, `scripts/`, `docs/` and `system/` are the exceptions — plain
utility/reference dirs, not linked by Stow.

```
dotfiles/
├── bash/           # .bashrc + .inputrc + .config/bash/*.sh modules (alternative shell)
├── starship/       # .config/starship.toml (prompt shared by bash and zsh)
├── zsh/            # .zshrc (slim loader) + .config/zsh/*.zsh modules
├── git/            # .gitconfig + .config/git/ignore
├── nvim/           # .config/nvim/ (LazyVim distribution)
├── tmux/           # .config/tmux/tmux.conf
├── lazygit/        # .config/lazygit/config.yml (terminal UI for git)
├── mise/           # .config/mise/config.toml (global CLI tools, see "Package lists")
├── shell/          # .profile
├── claude/         # .claude/ (Claude Code settings, agents, global CLAUDE.md; shared across profiles)
├── clef/           # systemd --user units + clef-server for the local decision engine (Linux; docs/decision-engine.md)
├── vscode/         # settings.json (symlinked per-OS by a script)
├── wsl/            # .wslconfig (copied to the Windows profile on WSL)
├── packages/       # package lists (brew/apt/pacman/node/vscode extensions)
├── .github/        # GitHub Actions workflow (runs scripts/ci.sh)
├── scripts/        # bootstrap + install/sync helpers + ci.sh
│   ├── lib/        # shared utilities (log, os_detect, sudo keep-alive…)
│   └── modules/    # one installable/optional step per file, sourced by bootstrap.sh
├── system/         # non-$HOME system files (/etc/…), installed by a script, not Stow
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
sudo pacman -S git stow     # Arch/Omarchy
brew install git stow       # macOS
```

## Quick start (recommended)

One line on a fresh machine (Linux, macOS or WSL). It installs `git` if missing,
clones the repo over HTTPS into `~/dotfiles` (or updates it if it's already there)
and runs the single bootstrap entry point, which detects the OS, installs base
packages, stows the config packages, syncs VS Code, installs global node packages,
and applies OS-specific extras (macOS defaults / WSL `.wslconfig`).

```sh
curl -fsSL https://raw.githubusercontent.com/savaf/dotfiles/main/install.sh | bash
```

Windows host (native apps + Windows Terminal, from PowerShell; see
[docs/windows-host.md](docs/windows-host.md)):

```powershell
irm https://raw.githubusercontent.com/savaf/dotfiles/main/install.ps1 | iex
```

Options (environment variables): `DOTFILES_DIR` (target, default `~/dotfiles`),
`DOTFILES_BRANCH` (default `main`), `DOTFILES_REPO`, and `DOTFILES_NO_BOOTSTRAP=1`
to only clone. Arguments after `bash -s --` are passed to `bootstrap.sh`. The clone
uses HTTPS; switch to SSH once your keys are set up
(`git remote set-url origin git@github.com:savaf/dotfiles.git`, see
[docs/git-and-ssh.md](docs/git-and-ssh.md)).

Or do it by hand:

```sh
git clone https://github.com/savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

The bootstrap backs up any conflicting real files to
`~/.dotfiles-backup/<timestamp>/` before linking.

## Manual usage with Stow

To link (or unlink) individual packages yourself:

```sh
cd ~/dotfiles
stow bash zsh git starship nvim tmux shell lazygit claude mise   # link everything
stow nvim                                    # link just one package
stow -D nvim                                 # unlink (remove symlinks)
stow -R zsh                                   # restow (refresh) after changes
```

## Package lists

**Installation cascade.** Every tool is installed by the first level that supports it:

1. **mise**, any backend (`mise/.config/mise/config.toml`, pinned versions).
2. The **system package manager** (apt, pacman; brew on macOS; winget on Windows).
3. **Homebrew on Linux**, only if the system manager lacks it.
4. Building from source, as a last resort.

A tool lives in exactly one place: `scripts/test-bootstrap.sh` fails if something declared in
mise also appears in a system manifest. Tools without a mise binary for a platform are
restricted with `os` in the config (eza and btop) and stay in the system manifest where needed.
What remains in the manifests below is what mise cannot provide (git, zsh, stow, curl,
compilers, nginx, wget…).

Reproducible package manifests live in `packages/`:

```sh
xargs brew install < packages/brew-cli.txt          # macOS CLI
xargs brew install --cask < packages/brew-casks.txt # macOS apps
sudo xargs -a packages/apt-cli.txt apt install -y   # Ubuntu/WSL CLI
grep -v '^#' packages/pacman-cli.txt | xargs sudo pacman -S --needed  # Arch/Omarchy CLI
```

VS Code settings (`vscode/settings.json`) are symlinked to the OS-specific
location by `scripts/sync-vscode-settings.sh`, and extensions are installed from
`packages/vs-extensions.txt`. See [docs/vscode.md](docs/vscode.md).

## Checks

`scripts/ci.sh` is the single entry point for repo checks:

- Runs every `scripts/test-*.sh`.
- Runs `shellcheck` on every tracked `*.sh` (`scripts/bootstrap.sh` installs `shellcheck`).
- Runs everything even after a failure, prints a summary, exits non-zero on any failure.

```sh
bash scripts/ci.sh
```

`.github/workflows/ci.yml` runs it on every push and pull request.

## Notes

- **WSL `.wslconfig`** is read by Windows from your Windows user profile, not the
  Linux `$HOME`. The bootstrap copies it to `C:\Users\<you>\.wslconfig`; apply
  changes with `wsl --shutdown`.
- **Prompt**: Starship, configured in `starship/.config/starship.toml`.
- **lazygit**: launch with `lzg`. See [docs/lazygit.md](docs/lazygit.md).

## Setup guides

Step-by-step guides for a fresh machine live in [`docs/`](docs):

| Guide | What it covers |
|-------|----------------|
| [shell-and-dotfiles.md](docs/shell-and-dotfiles.md) | zsh modules, prompt, and applying the dotfiles with Stow |
| [ubuntu-wsl.md](docs/ubuntu-wsl.md) | Ubuntu & WSL2 setup from scratch (incl. `.wslconfig`, fonts) |
| [omarchy.md](docs/omarchy.md) | Arch & Omarchy (Hyprland) setup — pacman, default shell (zsh), bash alternative |
| [macos-setup.md](docs/macos-setup.md) | macOS system preferences, apps, Homebrew, iTerm2 |
| [git-and-ssh.md](docs/git-and-ssh.md) | Git defaults and GitHub SSH key setup |
| [nodejs.md](docs/nodejs.md) | Node.js via nvm and global modules |
| [vscode.md](docs/vscode.md) | VS Code settings and extensions |
| [nvim.md](docs/nvim.md) | Neovim (LazyVim) setup, requirements and basics |
| [tmux.md](docs/tmux.md) | tmux prefix, panes/windows and copy mode |
| [lazygit.md](docs/lazygit.md) | lazygit keybindings and workflows |
| [hardware.md](docs/hardware.md) | My machines, for reference |
| [storage.md](docs/storage.md) | `Games` / `LIBRARY` disks: fstab, mountpoints, Kavita |
