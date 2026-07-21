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

## 4. Switching the shell to zsh

The bootstrap runs `chsh` to make zsh your login shell (Omarchy defaults to
bash). This updates `/etc/passwd`, but **reopening a terminal is not enough**:
the running Hyprland/uwsm session captured `SHELL=/usr/bin/bash` at login, and
Omarchy launches the terminal via `xdg-terminal-exec` → Alacritty, which reads
the shell from that inherited `$SHELL` rather than from `/etc/passwd`. So new
terminals keep opening bash until the session's `$SHELL` is refreshed.

Two ways to get zsh:

- **Reboot / re-login Hyprland** — the clean, terminal-agnostic fix. PAM
  re-exports `SHELL=/usr/bin/zsh` into the fresh session and every terminal
  opens zsh. Verify with `echo $SHELL`.
- **Pin the shell in Alacritty** — works immediately, no reboot, but is
  Alacritty-specific. The bootstrap does this automatically on Omarchy; it adds
  to `~/.config/alacritty/alacritty.toml`:

  ```toml
  [terminal]
  shell = { program = "/usr/bin/zsh" }
  ```

  New Alacritty windows (`SUPER`+`RETURN`) then open zsh right away.

Coexistence with Omarchy: the `omarchy-*` commands and `mise` shims live on
`PATH` via `~/.config/uwsm/env`, so they keep working under zsh. Omarchy's bash
aliases/functions are **not** loaded in zsh (by design) — your own
`~/.config/zsh/*` config replaces them. `~/.bashrc` is left untouched (these
dotfiles don't stow it), so bash still works in TTYs and scripts, and
`omarchy update` won't conflict.

## 5. Fonts

The bootstrap installs the *Monaspace Nerd Font* into `~/.local/share/fonts`.
Select it in your terminal (Alacritty on Omarchy: `~/.config/alacritty/alacritty.toml`
→ `[font]` section).

## 6. Caps Lock → Escape (Hyprland)

There is no `gsettings` on Hyprland, so the bootstrap can't apply this
automatically. Set it in `~/.config/hypr/input.conf`:

```conf
input {
  kb_options = caps:escape
}
```

Then `hyprctl reload`. (Omarchy binds Caps as compose key by default; this
replaces that.)

## 7. Keyboard layouts (LATAM / US, per-device)

La laptop (songbird) tiene el teclado físico en **LATAM** pero se usa con un
teclado USB EN-US (Keychron K3). El paquete stow `omarchy` versiona
`~/.config/hypr/input.conf` para resolverlo **por dispositivo**, sin udev:

- Default global `kb_layout = us,latam` → el USB EN-US y las máquinas sin
  teclado LATAM (p.ej. ANDREA, el desktop) arrancan en **US**.
- Un bloque `device{}` para el teclado físico (`at-translated-set-2-keyboard`)
  lo fuerza a `latam,us` → **LATAM**. En máquinas que no tengan ese teclado el
  bloque se ignora, así el mismo archivo sirve para ambas PCs.

Hyprland aplica el bloque `device{}` solo al conectar el teclado, así que el
switch es automático. Extras:

- **Toggle manual**: `SUPER` + `ALT` + `K` → `hyprctl switchxkblayout current
  next` (en `~/.config/hypr/bindings.conf`, también versionado).
- **Indicador**: el módulo `hyprland/language` en `~/.config/waybar/config.jsonc`
  muestra `US`/`LATAM` y es clicable para alternar.

El nombre del `device` es el que reporta `hyprctl devices` (minúsculas, espacios
→ guiones). Con fcitx5 activo (método de entrada), el toggle `current` y el
indicador operan sobre el teclado virtual de fcitx5; solo intercepta apps Qt.

## Notes

- On Arch `fd` and `bat` install under their real names — no `fdfind`/`batcat`
  symlinks like on Ubuntu.
- lazygit and Neovim come from the official repos (current versions), so the
  GitHub-release fallbacks used on Ubuntu/Fedora aren't needed.
- `wl-clipboard` is in the package list — Neovim's system clipboard needs it
  under Wayland/Hyprland.
- GUI apps (the `brew-casks.txt` equivalent) install automatically from
  `packages/arch-apps.txt` via `yay` (official repos + AUR), and web-only apps
  (Teams, Outlook, Discord, WhatsApp, Slack) from
  `packages/omarchy-webapps.txt` via
  `omarchy-webapp-install`. Add lines there instead of installing by hand.
- One-off extra packages: `omarchy pkg add <name>` (or plain `pacman`/`yay`).
- Xbox controller: pair over Bluetooth (Super+Ctrl+B) — works with the
  in-kernel driver; run `omarchy-install-gaming-xbox-controllers` (xpadneo)
  if you want rumble/battery reporting. Avoid the USB Wireless Adapter
  dongle: it needs the AUR `xone-dkms` driver and, on a monitor/desk hub, it
  can brown out and stall boot ~1 min (this happened; see boot-health.sh).
- Slow boot/login? Run `scripts/boot-health.sh` — it reports per-phase boot
  times, flaky-USB enumeration errors (a bad device can stall the LUKS prompt
  ~1 min), and whether the initramfs has the NVIDIA modules. The bootstrap
  also runs it at the end.
- NVIDIA + LUKS: a black screen at the boot password prompt means the
  initramfs is missing the nvidia modules (an Omarchy update can create
  `/etc/mkinitcpio.conf.d/nvidia.conf` after the last image rebuild). The
  bootstrap detects this and regenerates via `limine-mkinitcpio`; manual fix:
  `sudo limine-mkinitcpio`.
- RGB (OpenRGB): el paquete stow `omarchy` instala un hook
  (`~/.config/omarchy/hooks/theme-set.d/openrgb`) que pone todo el RGB del PC
  (NZXT, Lian Li Strimer, RAM, GPU, placa, teclado Keychron) al color accent del
  tema activo, en cada cambio de tema y al arrancar (vía
  `~/.config/hypr/autostart.conf`). El hook aplica dos pasadas (`--mode direct` y
  `--mode static`) porque los dispositivos no comparten un único modo de color
  fijo: el Lian Li Strimer y la RAM Corsair solo soportan `direct`, mientras que
  GPU y teclado solo soportan `static`. Overrides de color por tema se ajustan en
  el `case` del hook. El módulo `i2c-dev` (necesario para el RGB de RAM/placa por
  SMBus) lo persiste el bootstrap en `/etc/modules-load.d/i2c-dev.conf`.
- Refrigeración y Kraken (CoolerControl): `coolercontrol` (en `arch-apps.txt`)
  controla el AIO NZXT Kraken —bomba, ventiladores y **pantalla LCD**— vía su
  daemon `coolercontrold`, que el bootstrap habilita (`systemctl enable --now`).
  Deps opcionales `liquidctl` y `lm_sensors` (en `pacman-cli.txt`) le dan acceso
  a más sensores. El **contenido de la LCD** (temperatura de líquido/CPU, imagen,
  reloj) se configura desde la **GUI de CoolerControl**; esa config vive en el
  daemon (root, fuera de `$HOME`) y no se gestiona por stow. Para exponer todos
  los sensores del sistema, opcionalmente: `sudo sensors-detect --auto`.
  OpenRGB no ve el Kraken, así que no hay conflicto entre ambas herramientas.
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R zsh git p10k nvim tmux shell lazygit`.
