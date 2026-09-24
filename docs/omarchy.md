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

mise on Omarchy is the preinstalled `mise-bin` (from the `omarchy` repo), so it
is **not** listed in `packages/pacman-cli.txt` (`extra/mise` conflicts with it);
`install_arch` only installs `mise` if it is missing. Updates come through
`omarchy update`/pacman, not `mise self-update`, so `exports.zsh` sets
`MISE_DISABLE_UPDATE_WARNING=1` when mise lives in `/usr/bin`.

## 5. Fonts

The bootstrap installs the *Monaspace Nerd Font* into `~/.local/share/fonts`.
Select it in your terminal (Alacritty on Omarchy: `~/.config/alacritty/alacritty.toml`
→ `[font]` section).

## 6. Hyprland se configura en Lua, no en `.conf`

Desde Omarchy *quattro*, Hyprland usa el config provider de Lua. Compruébalo con:

```bash
hyprctl systeminfo | grep configProvider   # → configProvider: lua
```

`~/.config/hypr/hyprland.lua` carga los defaults de Omarchy y **después**
`hypr/monitors.lua`, `hypr/input.lua`, `hypr/bindings.lua`, `hypr/looknfeel.lua`
y `hypr/autostart.lua`, que es lo que versiona el paquete stow `omarchy`. Los
`.conf` equivalentes ya **no se leen** (quedan en el disco pero son inertes).

Referencia de la API: `/usr/share/hypr/stubs/hl.meta.lua` (tipos de `hl.config`,
`hl.device`, `hl.monitor`, `hl.bind`…) y los defaults en
`/usr/share/omarchy/default/hypr/` — leerlos es seguro, editarlos no.

Ejemplo, Caps Lock → Escape en `~/.config/hypr/input.lua`:

```lua
hl.config({ input = { kb_options = "caps:escape" } })
```

Luego `hyprctl reload && hyprctl configerrors`. (Omarchy usa Caps como tecla
compose por defecto; esto lo reemplaza.)

## 7. Keyboard layouts (LATAM / US, per-device)

La laptop (songbird) tiene el teclado físico en **LATAM** pero se usa con un
teclado USB EN-US (Keychron K3). El paquete stow `omarchy` versiona
`~/.config/hypr/input.lua` para resolverlo **por dispositivo**, sin udev:

- Default global `kb_layout = "us,latam"` → el USB EN-US, el teclado virtual de
  fcitx5 y las máquinas sin teclado LATAM (p.ej. ANDREA, el desktop) arrancan en
  **US**. Va hardcodeado a propósito: el default de Omarchy lo saca de
  `XKBLAYOUT` en `/etc/vconsole.conf`, que el instalador deja en `latam` y varía
  por instalación.
- Un `hl.device{}` para el teclado físico (`at-translated-set-2-keyboard`) lo
  fuerza a `latam,us` → **LATAM**. En máquinas que no tengan ese teclado la regla
  no matchea, así el mismo archivo sirve para ambas PCs.

Hyprland aplica la regla de `device` al conectar el teclado, así que el switch es
automático. Extras:

- **Toggle manual**: `SUPER` + `ALT` + `K` → `hyprctl switchxkblayout current
  next` (en `~/.config/hypr/bindings.lua`, también versionado). Ojo: esa combo es
  "Tmux keybindings" por defecto en Omarchy, hay que `hl.unbind` primero.
- **Indicador**: el widget `omarchy.keyboard-layout` en la barra
  (`~/.config/omarchy/shell.json`, versionado) muestra `US`/`LATAM`.

El nombre del `device` es el que reporta `hyprctl devices` (minúsculas, espacios
→ guiones). Con fcitx5 activo (método de entrada), el toggle `current` y el
indicador operan sobre el teclado virtual de fcitx5; solo intercepta apps Qt.
Ese teclado virtual se crea al arrancar fcitx5, así que tras un `hyprctl reload`
hay que reiniciarlo (`systemctl --user restart omarchy-fcitx5.service`) para que
tome el layout nuevo; en un arranque normal ya sale bien.

Verificación:

```bash
hyprctl devices -j | jq -r '.keyboards[] | "\(.name)\t\(.layout)\t\(.active_keymap)"'
```

## Notes

- **Omarchy reescribe algunos ficheros que stow enlaza.** `omarchy-shell-config` (detrás de
  cualquier `omarchy bar …`) escribe un temporal y hace `mv` sobre
  `~/.config/omarchy/shell.json`, lo que sustituye el symlink por un fichero real: a partir
  de ahí los cambios se quedan fuera del repo y el siguiente `stow` aborta por conflicto. Lo
  mismo le pasó a `~/.config/hypr/monitors.lua` con `omarchy-upgrade-to-quattro`. Cómo
  detectarlo y resolverlo: `docs/shell-and-dotfiles.md`.
- On Arch `fd` and `bat` install under their real names — no `fdfind`/`batcat`
  symlinks like on Ubuntu.
- lazygit and Neovim come from the official repos (current versions), so the
  GitHub-release fallbacks used on Ubuntu/Fedora aren't needed.
- `wl-clipboard` is in the package list — Neovim's system clipboard needs it
  under Wayland/Hyprland.
- GUI apps (the `brew-casks.txt` equivalent) install automatically from
  `packages/arch-apps.txt` via `yay` (official repos + AUR), and web-only apps
  (Teams, Outlook, Discord, WhatsApp, Slack, Telegram) from
  `packages/omarchy-webapps.txt` via
  `omarchy-webapp-install`. Add lines there instead of installing by hand.
- Webapp manifest format is `Name|URL|IconURL[|CustomExec]`. The 4th field is
  optional and replaces the generated `Exec=`; `omarchy-launch-webapp` forwards
  everything after the URL straight to the browser, so it's how you pass
  Chromium flags. `$HOME` in that field is expanded by
  `scripts/install-packages.sh` — the desktop-entry spec does **not** expand
  `$HOME` or `~`, so a literal one would break the launcher.
- **Isolating several accounts of the same service.** Every webapp runs on the
  browser's `Default` profile, so one entry can't hold two sessions of the same
  provider — signing into a second tenant evicts the first. Give each account its
  own entry with a separate `--user-data-dir`. Teams does this for three
  Microsoft tenants (`teams-unapec`, `teams-cnc`, `teams-work`); profiles live in
  `~/.local/share/omarchy-webapps/<name>/`, outside the browser's own config, so
  normal browsing is untouched and a profile is disposable with `rm -rf`. Pair it
  with `--no-first-run --no-default-browser-check` (skips Brave's welcome screen
  on a fresh profile) and `--class=<name>` (distinct `app_id` for Hyprland
  rules). Caveat: `omarchy-webapp-install` only takes `MimeType` as a 5th
  argument, so `StartupWMClass` can't be set in the generated `.desktop` —
  `--class` still applies to the window, but the compositor's
  launcher-to-window association isn't wired up.
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
- NVIDIA GSP crash (Xid 120): el firmware GSP del driver `nvidia-open`
  crasheaba bajo carga 3D sostenida (`NVRM: Xid ... 120, GSP task exception:
  load address misaligned`), tumbando todo Hyprland de golpe — pasó dos veces
  jugando Marvel Rivals vía Proton (2026-09-11 y 2026-09-16). Se ve en
  `coredumpctl list` como un `SIGABRT` de Hyprland + `SIGSEGV` de
  `xdg-desktop-portal-hyprland` en el mismo segundo, y en
  `journalctl -k -b <n> | grep Xid` como cientos/miles de líneas repetidas
  (el GSP queda reintentando y fallando hasta el reinicio). Workaround:
  desactivar GSP con `NVreg_EnableGpuFirmware=0` en
  `/etc/modprobe.d/nvidia.conf` (vuelve al driver a modo "legacy" sin GSP; el
  costo es algo de gestión de energía dinámica de menos). El contenido
  canónico vive versionado en `system/etc/modprobe.d/nvidia.conf` — no es
  stow (`/etc` está fuera de `$HOME`), lo instala `ensure_nvidia_gsp_disabled`
  en `install-packages.sh`, que también regenera el initramfs si el archivo
  cambió (el módulo `nvidia` se carga temprano vía el hook `kms`). Requiere
  reiniciar para tomar efecto.
- **Reboot to Windows**: el paquete stow `omarchy` instala `~/.local/bin/reboot-windows` y
  la fila **System → Reboot to Windows** del menú (`SUPER+SPACE`), declarada en
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
  - Windows vive en otro disco NVMe, con su propia entrada UEFI ("Windows Boot Manager")
    presente en la NVRAM pero inactiva (sin `*` en `efibootmgr`) y fuera del `BootOrder`
    de Limine.
  - El script busca esa entrada por label, no por número — una reinstalación de Windows
    puede correrlo —, la activa y arma `BootNext` (`efibootmgr -b <n> -a` / `-n <n>`).
    Es one-shot: el firmware consume `BootNext` en el próximo arranque, así que el
    reinicio siguiente vuelve solo a Omarchy sin tocar Limine ni el `BootOrder`.
  - Pide confirmación por `omarchy-menu-select` antes de tocar la NVRAM.
  - `sudo` no tiene tty al lanzarse desde el menú de Hyprland: usa un askpass de un solo
    uso con `pinentry-gtk` en vez de pedir la contraseña por stdin.
  - Reutiliza `omarchy-system-reboot` para el cierre de ventanas y el reinicio en sí.
- Temas: `omarchy-theme-set <slug>` interpola el `colors.toml` del tema sobre las
  plantillas de `~/.local/share/omarchy/default/themed/*.tpl`, deja el resultado en
  `~/.local/state/omarchy/current/theme/` (ojo: **antes vivía en `~/.config/omarchy/`**)
  y luego retinta cada app. Cómo le llega a lo que está bajo stow:

  | App | Mecanismo | Choca con stow? |
  |---|---|---|
  | Terminal | `alacritty.toml`/`ghostty.conf`/`kitty.conf` generados + `omarchy-theme-osc`, que reenvía secuencias OSC a los terminales ya abiertos | no |
  | Prompt zsh | ninguno: omarchy no trae plantilla para shells. `p10k/.p10k.zsh` usa índices ANSI 0-15 para heredar la paleta del terminal (ver `docs/shell-and-dotfiles.md`) | no |
  | Neovim | `~/.config/nvim/lua/plugins/theme.lua` → symlink al `neovim.lua` generado (aether.nvim), con hot-reload. Archivo local, no versionado | no |
  | VS Code | `omarchy-theme-set-vscode` reescribe `workbench.colorTheme` con `sed --follow-symlinks` | **sí**: escribe dentro del repo (aceptado, ver `docs/vscode.md`) |
  | Claude Code | `omarchy-theme-set-claude` genera `~/.claude/themes/omarchy.json`; la activación está versionada en el repo (ver `docs/claude-code.md`) | evitado |
  | RGB | hook propio `theme-set.d/openrgb` | no |

  Los hooks propios van en `~/.config/omarchy/hooks/theme-set.d/`; `omarchy-theme-set`
  los ejecuta todos al final de cada cambio de tema (`omarchy-hook theme-set <slug>`).
  El paquete stow `omarchy` aporta dos: `openrgb` y `claude`.
- RGB: el paquete stow `omarchy` instala `~/.local/bin/rgb`, que apaga todo el RGB
  del PC o lo devuelve al color accent del tema activo.
  - `rgb toggle` (por defecto) alterna. Es lo que invoca la fila **Style → RGB** del
    menú, declarada en `~/.config/omarchy/extensions/omarchy-menu.jsonc`.
  - `rgb off` y `rgb on` fuerzan un estado; `rgb theme` reaplica el tema salvo que lo
    hayas apagado a mano.
  - El estado vive en `$XDG_RUNTIME_DIR/omarchy-rgb-off`, que se borra al cerrar
    sesión: tras reiniciar se vuelve al color del tema.
  - El teclado Keychron queda fuera del apagado a propósito. `rgb on` sí lo cubre.
  - Las velocidades de ventilador no se tocan nunca; siguen siendo de CoolerControl.
- El RGB está repartido entre dos herramientas según quién posea el dispositivo:

  | Dispositivos | Herramienta | Detalle |
  |---|---|---|
  | RAM Corsair, GPU ZOTAC, Lian Li Strimer, placa MSI, teclado Keychron | `openrgb` | dos pasadas, `--mode direct` y `--mode static`: ningún modo de color fijo es común a todos |
  | Hub `NZXT RGB & Fan Controller`, canales `led1` y `led2` | `liquidctl` | OpenRGB lo lista, pero `coolercontrold` posee el USB y sus escrituras no llegan |
  | Conector RGB externo del Kraken Z53, canal `external` | `liquidctl` | de ahí cuelgan ventiladores que OpenRGB no ve en absoluto |
  | Pantalla LCD del Kraken Z53 | `liquidctl` | `set lcd screen brightness` |

  El canal agregado `sync` del hub no alcanza a `led2`: hay que recorrerlos uno a uno.
  Los dispositivos de OpenRGB se seleccionan por nombre (`-d Dominator`), no por
  índice, porque el índice cambia entre arranques; un nombre alcanza a todas sus
  coincidencias.
- El hook `theme-set.d/openrgb` es un wrapper de una línea sobre `rgb theme`, en
  segundo plano para no bloquear el cambio de tema. `omarchy-theme-set` lo ejecuta en
  cada cambio y `~/.config/hypr/autostart.lua` al arrancar. Los overrides de color por
  tema están en el `case` de la función `accent()` de `rgb`. El módulo `i2c-dev`
  (RGB de RAM/placa por SMBus) lo persiste el bootstrap en
  `/etc/modules-load.d/i2c-dev.conf`.
- Refrigeración y Kraken (CoolerControl): `coolercontrol` (en `arch-apps.txt`)
  controla el AIO NZXT Kraken —bomba, ventiladores y **pantalla LCD**— vía su
  daemon `coolercontrold`, que el bootstrap habilita (`systemctl enable --now`).
  Deps opcionales `liquidctl` y `lm_sensors` (en `pacman-cli.txt`) le dan acceso
  a más sensores. El **contenido de la LCD** (temperatura de líquido/CPU, imagen,
  reloj) se configura desde la **GUI de CoolerControl**; esa config vive en el
  daemon (root, fuera de `$HOME`) y no se gestiona por stow. Para exponer todos
  los sensores del sistema, opcionalmente: `sudo sensors-detect --auto`.
  `coolercontrold` posee por USB tanto el Kraken como el hub NZXT: OpenRGB lista el
  hub pero no puede escribirle, así que su iluminación va por `liquidctl`.

- **Perfiles de temperatura y modo Rendimiento automático** (paquete stow
  `coolercontrol/`): recién instalado, `coolercontrold` detecta todo el
  hardware pero llega **sin ninguna curva configurada** (`modes.json` y
  `calibrations.json` vacíos) — todo el hardware queda en "Unmanaged"
  (perfil `Identity`), es decir, ningún ventilador ni la bomba reaccionan a la
  temperatura real. Este paquete lo corrige y además cambia de perfil solo al
  jugar.

  Canales que realmente se gobiernan (el resto de NZXT/NCT6687 no tiene nada
  físicamente conectado y no se toca):

  | canal | dispositivo | rol |
  |---|---|---|
  | `fan` / `pump` | NZXT Kraken (AIO) | radiador + bomba |
  | `fan3` | NZXT RGB & Fan Controller | único canal del hub con algo conectado |
  | `fan1` / `fan2` | GPU (RTX 3080) | vía **NVML** (`nvmlDeviceSetFanSpeed_v2`) — no hace falta Xorg, Coolbits ni `nvidia-settings`, esta sesión es Wayland |

  El tacómetro `fan1` del NCT6687D-R es el mismo eje físico que la bomba del
  Kraken (cableado al header CPU_FAN de la placa): se lee para diagnóstico,
  pero su `pwm1` no se toca. `fan2`–`fan8` del NCT6687 y `fan1`/`fan2` del hub
  NZXT no tienen nada conectado.

  Dos modos, definidos declarativamente en
  `coolercontrol/.config/coolercontrol-modes/curves.json` (temp→%duty, ahí se
  ajustan las curvas sin tocar bash):
  - **Silencio** (por defecto, persiste entre arranques vía `apply_on_boot`
    del propio daemon): curvas conservadoras, ventiladores inaudibles hasta
    ~58 °C de CPU / ~52 °C de GPU.
  - **Rendimiento**: piso de RPM más alto y rampa más agresiva; se activa solo
    mientras hay una ventana de juego abierta.

  `coolercontrol/.local/bin/coolercontrol-provision` aplica `curves.json` vía
  la API REST del daemon (`127.0.0.1:11987`) de forma idempotente (crea o
  actualiza functions/profiles/modes por nombre; los `device_uid` se resuelven
  en cada ejecución, nunca se hardcodean, porque son hashes que cambian si se
  mueve el Kraken de puerto USB o cambia la GPU).

  `coolercontrol/.local/bin/coolercontrol-mode-watcher` (systemd de usuario
  `coolercontrol-mode-watcher.service`, habilitado por
  `ensure_coolercontrol_mode_watcher` en `bootstrap.sh`) escucha el socket de
  eventos de Hyprland (`.socket2.sock`) y, en cada apertura/cierre de ventana,
  relee **todas** las ventanas abiertas (`hyprctl clients -j`) y activa
  "Rendimiento" si alguna clase coincide con un patrón de
  `coolercontrol/.config/coolercontrol-modes/gaming-classes.conf`; si no, vuelve
  a "Silencio". Se relee sin estado a propósito: `closewindow>>` de Hyprland no
  trae la clase de la ventana, así que llevar un mapa en memoria se
  desincroniza en cuanto se pierde un evento o se reinicia el servicio.

  **Para añadir un juego**: añade una línea (glob) a `gaming-classes.conf`, sin
  reiniciar nada — se relee en cada evento. Para saber la clase de una ventana
  abierta: `hyprctl clients -j | jq -r '.[] | .class, .initialClass'`. El
  *cliente* de Steam se deja fuera por defecto (`# steam`, comentado): suele
  quedarse abierto en segundo plano y dejaría "Rendimiento" activo todo el
  tiempo; el disparador real son las clases de juego (`steam_app_*`,
  `gamescope`, `steam_proton`).

  **Token de la API** (paso manual, una sola vez, fuera del repo): la API
  exige un Bearer token con permiso de escritura. Créalo desde la GUI de
  CoolerControl (Settings → Access Tokens) y guárdalo en
  `~/.local/state/coolercontrol-modes/api-token` con permisos `600`:
  ```sh
  install -d -m 700 ~/.local/state/coolercontrol-modes
  umask 077; printf '%s' '<TOKEN>' > ~/.local/state/coolercontrol-modes/api-token
  ```
  Sin ese fichero, `ensure_coolercontrol_mode_watcher` deja el watcher sin
  habilitar y avisa en el log del bootstrap; una vez creado el token,
  re-ejecuta `scripts/bootstrap.sh` (o a mano:
  `coolercontrol-provision && systemctl --user enable --now coolercontrol-mode-watcher`).
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R zsh git p10k nvim tmux shell lazygit`.
