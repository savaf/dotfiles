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
config packages, and sets zsh as the default shell (bash stays available: `./scripts/switch-shell.sh bash`).

Omarchy already ships neovim (LazyVim), lazygit, fzf, ripgrep and zoxide, and
keeps its own configs in `~/.config` — any that collide with a stow package
(e.g. `~/.config/nvim`) are backed up to `~/.dotfiles-backup/<timestamp>/`
before linking, so nothing is lost.

Open a new terminal (or `exec zsh`) to load everything.

## 4. The default shell (zsh)

Omarchy defaults to bash, but these dotfiles use zsh: the bootstrap runs
`chsh` to zsh (a no-op if it's already your login shell). The ported bash
config (`~/.bashrc` + `~/.config/bash/`, with ble.sh and Starship) stays
installed as an alternative.

The running Hyprland/uwsm session captures `$SHELL` at login and foot reads the
shell from it rather than from `/etc/passwd`, so after switching shells
(`./scripts/switch-shell.sh zsh|bash`) either reboot/re-login Hyprland, or rely
on the pin the bootstrap/switch script writes to `~/.config/foot/foot.ini`:

```ini
[main]
shell=/usr/bin/zsh
```

New foot windows (`SUPER`+`RETURN`) then open that shell right away.

Coexistence with Omarchy: the `omarchy-*` commands and `mise` shims live on
`PATH` via `~/.config/uwsm/env`, so they keep working in bash and zsh. Omarchy's own bash
aliases/functions are **not** loaded: `~/.bashrc` is now this repo's (stowed
from `bash/`), and your `~/.config/bash/*` config replaces them.

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

## 8. Bitwarden al iniciar sesión

`omarchy/.config/hypr/autostart.lua` lanza `bitwarden-desktop` con
`o.launch_on_start`. El `~/.config/autostart/bitwarden.desktop` que crea la
propia app **no se versiona** (la app lo reescribe).

**Paso manual, una vez por máquina**: en Bitwarden, Ajustes → Opciones, desmarca
"Iniciar al abrir sesión" (`openAtLogin`) y borra
`~/.config/autostart/bitwarden.desktop` si sigue ahí. Si no, Bitwarden arranca
dos veces (Hyprland y XDG autostart).

**Minimizado en la bandeja**: no hay bandera de línea de comandos (el wrapper
`/usr/bin/bitwarden-desktop` solo pasa `$@` a Electron). Es un ajuste de la app:
Ajustes → Opciones, activa "Mostrar icono de bandeja" y luego "Iniciar en la
bandeja" (`startToTray`, requiere lo primero). Sin él, la ventana flotante se abre
en cada inicio. Comprobado por lectura del paquete; no se ha lanzado para probarlo.

## 9. Layouts de workspace, dock y ventana cuadrada

- **Layout**: `dwindle` en todos los workspaces (default de Omarchy, sin tocar). El workspace 1
  de cada monitor es **flotante** y se declara en `hypr/looknfeel.lua` con `o.workspace_mode`.
  Omarchy numera en bloques de diez por monitor, así que el primero de cada uno es 1, 11 y 21
  (se declaran los tres). En los workspaces flotantes se muestran el dock y las barras de título.
- **Convivencia con el estado local**: `~/.local/state/omarchy/workspace-layouts/<id>.lua`
  (lo que escribe `omarchy-hyprland-workspace-layout-toggle`, p. ej. `11.lua`) se carga después
  y llama a la misma función; repetir un id con el mismo modo es inocuo. Para que `o.workspace_mode`
  exista al cargar `looknfeel.lua`, el archivo hace `require("default.hypr.workspace-modes")`.
- **Dock**: abajo y siempre visible (`dock` en `shell.json`). Si molesta: `omarchy dock autohide on`.
  Atajos de Omarchy sin cambios: `SUPER+L` (layout), `SUPER+ALT+L`, `SUPER+M` (minimizar).
- **Ratio 1:1 (ventana única cuadrada y centrada)**: `layout.single_window_aspect_ratio = {1, 1}`
  solo si `/etc/hostname` es `andrea` (ultrawide 3840x1080). El ThinkPad no lo activa. El toggle de
  sesión de Omarchy (`omarchy-hyprland-window-single-square-aspect-toggle`) vive en
  `~/.local/state/omarchy/toggles/hypr/` y no se versiona.
- **No versionado**: `~/.local/state/omarchy/workspace-layouts/*.lua`, `toggles/hypr/*.lua` y
  `monitor-workspaces` (qué bloque tiene cada monitor) son estado por máquina.
- Test: `scripts/test-hypr-looknfeel.sh` (sintaxis y condición por hostname con stubs).

## 10. Tailscale

Solo conectividad entre ANDREA y el ThinkPad, más Taildrop. Servidor de coordinación oficial
de Tailscale (cuenta personal gratuita), sin Headscale. Sin exit node ni Tailscale SSH: el SSH
sigue por llaves (`docs/git-and-ssh.md`). `tailscale` **no** está en `packages/*.txt`: lo
instala el propio Omarchy.

**Paso manual, una vez por máquina**:

```bash
omarchy install service tailscale
```

El script instala el paquete `tailscale` por pacman, activa `tailscaled`, ejecuta
`tailscale up --accept-routes` (abre el login en el navegador), te configura como operador,
activa el servicio de usuario de Taildrop (recibe en `~/Downloads`), añade el plugin de la
barra e instala la webapp de administración.

**Aviso con el vigilante de sincronización**: el script reescribe
`~/.config/omarchy/shell.json` con `mv`, lo que sustituye el symlink de stow por un fichero
real. Ejecútalo con el vigilante (`sync-config`, units en `omarchy/.config/systemd/user/`) ya
activo, o revisa `git diff` justo después. El repo ya trae el widget en la barra
(`omarchy.tailscale` tras `omarchy.network`, refresco por defecto de 30 s), así que el diff
debería quedar vacío o casi.

**El widget** (`omarchy.tailscale`) solo necesita la CLI de Tailscale y `wl-copy`: muestra el
estado de la conexión y los dispositivos de la tailnet. Archivos entre máquinas:
`omarchy tailscale send` y `omarchy tailscale receive`.

**Quitarlo**: `omarchy remove service tailscale`, y borra el bloque `omarchy.tailscale` de
`bar.layout.right` en `omarchy/.config/omarchy/shell.json` (de nuevo con el vigilante activo o
revisando `git diff`).

## 11. Marca por hostname (About y fastfetch)

Cada máquina muestra su hostname en letras grandes: `about.andrea.txt` y `about.songbird.txt` en
`omarchy/.config/omarchy/branding/` (wordmarks de `omarchy ascii`, partidos en dos líneas para caber en
la caja de 54x26 de About). El portátil se asume `songbird` (sin confirmar con `hostname`).

- `~/.local/bin/branding-select` enlaza `~/.config/omarchy/branding/about.txt` al About del hostname
  actual. Corre desde el bootstrap y desde `hypr/autostart.lua`. Un About suelto previo se respalda en
  `about.txt.bak`; un hostname sin archivo avisa por stderr y no toca nada.
- `omarchy branding about text|image` escribe a través del enlace, o sea en el archivo versionado
  (se ve en `git diff`). `omarchy branding about reset` copia el genérico sobre el archivo versionado:
  es destructivo, revisa `git diff` después.
- `omarchy/.config/fastfetch/config.jsonc` es copia de la global (`/etc/fastfetch`) y lee `about.txt`,
  así que sigue a la máquina. Al existir una config propia, `omarchy launch about` deja de ajustar la
  ventana y de animar el logo (lo trata como configuración personalizada).
- El screensaver (`screensaver.txt`) es común y no cambia.
- Nuevo equipo: añade `about.<hostname>.txt` (máx. 54 columnas x 26 filas; `scripts/test-branding.sh` lo
  comprueba).

## 12. Vigilante de `shell.json` y `monitors.lua`

Omarchy reescribe esos dos archivos con temporal + `mv` y rompe el symlink de stow (ver Notes).
Un observador de systemd de usuario lo repara solo, sin commit: el cambio queda como `git diff`.

- **Piezas** (paquete `omarchy/`): `sync-config-omarchy.path` (vigila `~/.config/omarchy`) y
  `sync-config-hypr.path` (vigila `~/.config/hypr`) disparan `sync-config.service` (oneshot), que
  corre `~/.local/bin/sync-config-watch`. Ese wrapper llama a `sync-config` para
  `shell.json` y `monitors.lua`: si dejaron de ser symlink copia su contenido al repo (un `.json`
  inválido no se copia y se avisa en el journal) y restaura el symlink relativo. El repo se deduce
  del propio script (symlink de stow), no hay ruta fija.
- **Activación**: `ensure_sync_config_watcher` (`scripts/modules/sync-config-watcher.sh`) la hace
  el bootstrap tras el stow, solo en Omarchy: `daemon-reload` y `enable --now` de las dos `.path`.
  Idempotente. En otros sistemas no se toca systemd.
- **`stow -R` no lo dispara de forma dañina**: `sync-config` no hace nada si el archivo falta
  (fase unstow) o ya es symlink (fase restow), así que las ráfagas de eventos son no-ops;
  `StartLimitIntervalSec=0` evita que systemd corte la `.path` por tantas activaciones. El
  script no es interactivo, así que el `mv -i` del alias no interviene.
- **Cubre solo** `~/.config/omarchy/shell.json` y `~/.config/hypr/monitors.lua`. Otro archivo
  enlazado que Omarchy reescriba hay que añadirlo a `sync-config-watch`.
- **Ver / desactivar**: `systemctl --user status sync-config-omarchy.path sync-config-hypr.path`,
  `journalctl --user -u sync-config.service`; apagar con
  `systemctl --user disable --now sync-config-omarchy.path sync-config-hypr.path`. Sin él,
  sigue valiendo la reparación manual de `docs/shell-and-dotfiles.md`.
- Test: `scripts/test-sync-config-watcher.sh` (wrapper, unidades con `systemd-analyze verify` e
  instalador con `systemctl` falso).

## 13. Aviso de agentes de herdr en la barra

Widget de comando `herdr-attention` en `bar.layout.centerEnd` de `shell.json`: muestra `herdr N` con los
agentes bloqueados (`blocked`) o terminados (`done`), con el detalle en el tooltip, y no muestra nada si
no hay ninguno (o si herdr no responde). Sirve para enterarse aunque herdr (`hw`) esté tapado por otra
ventana. Un clic ejecuta `omarchy-launch-terminal herdr`, que adjunta la sesión persistente.

- Script: `omarchy/.config/omarchy/bar/scripts/herdr-attention`. Ejecuta `herdr agent list` (solo lectura)
  y filtra `result.agents[].agent_status` con `jq`. Estados de herdr: `idle`, `working`, `blocked`, `done`,
  `unknown`.
- `interval` 10 s: un `herdr` + un `jq` cada 10 s, sin demonio.
- Convive con el toast `[ui.toast] delivery = "system"` (`docs/herdr.md`); este es un indicador
  persistente, el toast avisa una vez.
- Test: `scripts/test-herdr-attention.sh` (con `herdr` falso en el PATH). Mostrar el widget en vivo
  requiere recargar la barra, que hace el integrador.

## 14. Reproductor de música propio (`savaf.media`)

Copia del plugin `omarchy.media` en `omarchy/.config/omarchy/plugins/savaf.media/` (el id sigue la
convención `<usuario>.media` de `omarchy plugin clone`). La barra usa la copia en lugar del original:
`shell.json` apunta a `savaf.media` en `bar.layout.center`, y lleva `omarchy.media` en `disabledPlugins` y
`savaf.media` en `cloneSourceRestores`, que es lo que escribe `omarchy plugin clone` (se replicó a mano,
sin ejecutarlo). La carpeta queda enlazada en `~/.config/omarchy/plugins/` con Stow.

- Cambios sobre el original (`BarWidget.qml`): ancho máximo de la etiqueta 180 -> 320 px, y botones
  visibles anterior / play-pausa / siguiente (en barra vertical solo play-pausa). Se conservan la rueda
  (anterior/siguiente), el clic medio (siguiente), el clic derecho (popup con carátula) y el clic izquierdo
  sobre la etiqueta (play/pausa).
- **La copia no recibe las actualizaciones del original.** Tras actualizar Omarchy, compara con
  `diff -ru /usr/share/omarchy/shell/plugins/services/media omarchy/.config/omarchy/plugins/savaf.media`
  y porta a mano lo que interese. Para volver al original: `omarchy plugin enable omarchy.media`.
- Validación: `omarchy plugin validate omarchy/.config/omarchy/plugins/savaf.media` (solo lectura). Verlo en
  la barra con música real requiere recargar el shell, que hace el integrador.

## Notes

- **Omarchy reescribe algunos ficheros que stow enlaza.** `omarchy-shell-config` (detrás de
  cualquier `omarchy bar …`) escribe un temporal y hace `mv` sobre
  `~/.config/omarchy/shell.json`, lo que sustituye el symlink por un fichero real: a partir
  de ahí los cambios se quedan fuera del repo y el siguiente `stow` aborta por conflicto. Lo
  mismo le pasó a `~/.config/hypr/monitors.lua` con `omarchy-upgrade-to-quattro`. Cómo
  detectarlo y resolverlo: `docs/shell-and-dotfiles.md`.
- CLI tools such as `fd`, `bat`, lazygit and Neovim are installed by mise
  (`mise/.config/mise/config.toml`), not pacman, so every platform gets the same
  versions (see the [install cascade](../README.md#package-lists)).
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
- **Netflix (u otro vídeo DRM) en negro con audio, en Brave/Chromium.** Causa:
  con GPU NVIDIA + Wayland (Hyprland), cuando el vídeo cae al decodificador
  software (`FFmpegVideoDecoder` — pasa con Widevine L3, que es lo único que
  hay en Linux, y también con HEVC Main10), el frame se decodifica bien pero
  el compositor no lo pinta: pantalla negra, audio normal. Es un bug conocido
  de Chromium/Brave en NVIDIA+Wayland, no de Widevine ni de los codecs (ver
  `brave/brave-browser#57974`). Solución aplicada: añadir `--use-gl=egl` y
  `--disable-features=VaapiVideoDecoder` a `~/.config/brave-flags.conf` y
  `~/.config/chromium-flags.conf` (se queda en Wayland, no hace falta forzar
  X11 con `--ozone-platform=x11`). Estos ficheros están versionados en el
  paquete Stow `omarchy/.config/{brave,chromium}-flags.conf`, así que
  sobreviven a una reinstalación — tras `stow`, reinicia el navegador para que
  tome los flags nuevos. Nota: si en algún momento reactivas la aceleración
  por hardware del navegador (`brave://settings/system` /
  `chrome://settings/system`), Netflix sigue topado en 1080p igualmente — Linux
  nunca pasa de Widevine L3.
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
  | Prompt zsh | ninguno: omarchy no trae plantilla para shells. `starship/.config/starship.toml` usa índices ANSI 0-15 para heredar la paleta del terminal (ver `docs/shell-and-dotfiles.md`) | no |
  | Neovim | `~/.config/nvim/lua/plugins/theme.lua` → symlink al `neovim.lua` generado (aether.nvim), con hot-reload. Archivo local, no versionado | no |
  | VS Code | `omarchy-theme-set-vscode` reescribe `workbench.colorTheme` con `sed --follow-symlinks` | **sí**: escribe dentro del repo (aceptado, ver `docs/vscode.md`) |
  | Claude Code | `omarchy-theme-set-claude` genera `~/.claude/themes/omarchy.json`; la activación está versionada en el repo (ver `docs/claude-code.md`) | evitado |
  | RGB | hook propio `theme-set.d/openrgb` | no |

  Los hooks propios van en `~/.config/omarchy/hooks/theme-set.d/`; `omarchy-theme-set`
  los ejecuta todos al final de cada cambio de tema (`omarchy-hook theme-set <slug>`).
  El paquete stow `omarchy` aporta dos: `openrgb` y `claude`.
- RGB: el paquete stow `omarchy` instala `~/.local/bin/rgb`, que apaga todo el RGB
  del PC o lo devuelve al color accent del tema activo.
  - `rgb toggle` (por defecto) alterna. Es lo que invoca la fila **Appearance → RGB** del
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
- Menú: la extensión `~/.config/omarchy/extensions/omarchy-menu.jsonc` añade
  **Appearance → RGB** (`appearance.rgb`, alias antiguo `style`) y **System → Work
  workspaces** (`system.hw`), que abre `hw` en una terminal nueva con
  `omarchy-launch-terminal zsh -ic hw` (`hw` es una función de zsh, de ahí el `-ic`).
  Sin atajo de teclado.
- Branding: los archivos de `~/.config/omarchy/branding/` son enlaces al repo, así que
  `omarchy branding about|screensaver text|image` escribe en el archivo versionado
  (se ve en `git diff`). **`omarchy branding reset` lo pisa** con el logo por defecto de
  Omarchy: revisa el diff o restaura con git después.
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
  El Nuvoton NCT6687D-R de la placa (fan headers/sensores) no tiene driver en
  `linux-omarchy`; sin él, `coolercontrold` loguea `Failed to load module nct6687`
  al arrancar. Lo provee `nct6687d-dkms-git` (AUR, en `arch-apps.txt`); el bootstrap
  lo carga y persiste con `ensure_nct6687` en `install-packages.sh`.

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
- To re-apply config after pulling changes: `cd ~/dotfiles && stow -R bash zsh git starship nvim tmux shell lazygit mise`.
