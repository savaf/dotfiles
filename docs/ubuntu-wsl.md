# Ubuntu / WSL setup

These dotfiles run on native Ubuntu and on Ubuntu under WSL2 (Windows). The flow
is the same; the WSL-only extras are called out below.

## 1. (WSL only) Install WSL2 + Ubuntu

From an elevated PowerShell on Windows:

```powershell
wsl --install -d Ubuntu
```

Reboot if prompted, then launch **Ubuntu** and create your Linux user.

## 2. Update the system

```sh
sudo apt update && sudo apt upgrade -y
```

## 3. Install prerequisites and clone

```sh
sudo apt install -y git stow
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

> First time using git here? Set up SSH first — see [git-and-ssh.md](git-and-ssh.md).

## 4. Run the bootstrap

```sh
./scripts/bootstrap.sh
```

This installs the apt packages from [`packages/apt-cli.txt`](../packages/apt-cli.txt),
installs tools that aren't in apt (e.g. lazygit from its GitHub release),
stows the config packages, sets zsh as the default shell, and—on WSL—copies
`.wslconfig` to your Windows user profile.

Open a new terminal (or `source ~/.zshrc`) to load everything.

## 5. (WSL only) `.wslconfig`

`.wslconfig` is read by **Windows**, not Linux, from
`C:\Users\<you>\.wslconfig`. The bootstrap copies [`wsl/.wslconfig`](../wsl/.wslconfig)
there for you. Apply changes with:

```powershell
wsl --shutdown
```

## 6. (WSL only) Fonts in the Windows terminal

The prompt and icons need a Nerd Font installed **on Windows** (WSL renders
through the Windows terminal). Install *MonaspiceAr Nerd Font* (or any Nerd Font)
from [nerdfonts.com](https://www.nerdfonts.com/), then select it in your terminal
(Windows Terminal → Settings → your profile → Appearance → Font face).

## Notes

- `fd` and `bat` are installed as `fdfind`/`batcat` on Ubuntu; the bootstrap adds
  `fd`/`bat` convenience symlinks.
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R zsh git p10k nvim tmux shell lazygit`.
