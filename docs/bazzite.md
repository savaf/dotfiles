# Fedora / Bazzite setup

These dotfiles run on classic Fedora (Workstation) and on Bazzite (Fedora
Atomic, immutable). The flow is the same; the immutable-only details are
called out below.

## 1. Update the system

```sh
ujust update            # Bazzite (updates image, flatpaks, etc.)
sudo dnf upgrade -y     # classic Fedora
```

## 2. Install prerequisites and clone

Bazzite ships `git` and `stow` in the base image. On classic Fedora:

```sh
sudo dnf install -y git stow
```

Then clone:

```sh
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

> First time using git here? Set up SSH first — see [git-and-ssh.md](git-and-ssh.md).

## 3. Run the bootstrap

```sh
./scripts/bootstrap.sh
```

This installs the packages from [`packages/dnf-cli.txt`](../packages/dnf-cli.txt),
installs tools that aren't in the repos (lazygit and Neovim ≥ 0.11 from their
GitHub releases), stows the config packages, and sets zsh as the default shell.

- **Classic Fedora**: packages install with `dnf`.
- **Bazzite**: there is no `dnf` on the host; the bootstrap layers the missing
  packages with `rpm-ostree install --idempotent --apply-live` (no reboot
  needed). If `--apply-live` isn't supported, the layer is queued instead —
  reboot and re-run the bootstrap, as the script tells you.

Open a new terminal (or `source ~/.zshrc`) to load everything.

## 4. Fonts

The bootstrap installs the *Monaspace Nerd Font* into `~/.local/share/fonts`.
Select it in your terminal (Konsole/Ptyxis → profile → Appearance → Font).

## Notes

- On Fedora `fd` and `bat` install under their real names — no `fdfind`/`batcat`
  symlinks like on Ubuntu.
- `fastfetch` replaces `neofetch` (retired from the Fedora repos).
- lazygit and Neovim go to `/usr/local/bin`, which on ostree systems is the
  writable `/var/usrlocal` — no layering needed for them.
- Caps Lock → Escape is applied automatically only on GNOME (`gsettings`). On
  Bazzite's default KDE, set it in System Settings → Keyboard → Advanced →
  "Caps Lock behavior".
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R zsh git p10k nvim tmux shell lazygit`.
