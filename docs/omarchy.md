# Arch / Omarchy setup

These dotfiles run on Arch Linux and on [Omarchy](https://omarchy.org)
(Arch + Hyprland by DHH). The flow is the same; Omarchy-specific details are
called out below.

## 1. Update the system

```sh
omarchy update          # Omarchy (system + Omarchy configs)
sudo pacman -Syu        # plain Arch
```

## 2. Install prerequisites and clone

Omarchy ships `git` in the base install. On plain Arch:

```sh
sudo pacman -S --needed git stow
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

This installs the packages from [`packages/pacman-cli.txt`](../packages/pacman-cli.txt)
with `pacman -S --needed` (already-installed packages are skipped), stows the
config packages, and sets zsh as the default shell (Omarchy defaults to bash).

Omarchy already ships neovim (LazyVim), lazygit, fzf, ripgrep and zoxide, and
keeps its own configs in `~/.config` — any that collide with a stow package
(e.g. `~/.config/nvim`) are backed up to `~/.dotfiles-backup/<timestamp>/`
before linking, so nothing is lost.

Open a new terminal (or `source ~/.zshrc`) to load everything.

## 4. Fonts

The bootstrap installs the *Monaspace Nerd Font* into `~/.local/share/fonts`.
Select it in your terminal (Alacritty on Omarchy: `~/.config/alacritty/alacritty.toml`
→ `[font]` section).

## 5. Caps Lock → Escape (Hyprland)

There is no `gsettings` on Hyprland, so the bootstrap can't apply this
automatically. Set it in `~/.config/hypr/input.conf`:

```conf
input {
  kb_options = caps:escape
}
```

Then `hyprctl reload`. (Omarchy binds Caps as compose key by default; this
replaces that.)

## Notes

- On Arch `fd` and `bat` install under their real names — no `fdfind`/`batcat`
  symlinks like on Ubuntu.
- lazygit and Neovim come from the official repos (current versions), so the
  GitHub-release fallbacks used on Ubuntu/Fedora aren't needed.
- `wl-clipboard` is in the package list — Neovim's system clipboard needs it
  under Wayland/Hyprland.
- Extra packages on Omarchy: `omarchy pkg add <name>` (or plain `pacman`/AUR).
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R zsh git p10k nvim tmux shell lazygit`.
