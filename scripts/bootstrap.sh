#!/usr/bin/env bash
set -euo pipefail

# Single entry point to set up these dotfiles on Ubuntu/WSL and macOS.
# Steps: install packages -> stow config packages -> VS Code -> OS extras.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/scripts/lib-sudo.sh"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

os_detect() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then echo "macos"; return; fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release 2>/dev/null || true
    # Omarchy no altera /etc/os-release (queda ID=arch); detectarlo por su marca.
    if [[ "${ID:-}" == "arch" ]] \
        && { [[ -d "${HOME}/.local/share/omarchy" ]] || command -v omarchy >/dev/null 2>&1; }; then
      echo "omarchy"; return
    fi
    echo "${ID:-linux}"; return
  fi
  echo "unknown"
}

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Config packages that get symlinked into $HOME via stow.
STOW_PACKAGES=(zsh git p10k nvim tmux herdr shell lazygit claude)

# Shared backup dir for this run; created lazily on first real file moved.
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Move a real (non-symlink) file out of the way before we overwrite it.
backup_if_real() {
  local target="$1" rel="$2"
  [[ -e "${target}" && ! -L "${target}" ]] || return 0
  # No mover archivos que resuelven dentro del repo (symlinks folded de stow).
  case "$(readlink -f "${target}")" in "${ROOT_DIR}"/*) return 0 ;; esac
  mkdir -p "$(dirname "${BACKUP_DIR}/${rel}")"
  log "Backup ${target} → ${BACKUP_DIR}/${rel}"
  mv "${target}" "${BACKUP_DIR}/${rel}"
}

ensure_locale() {
  case "${OS}" in ubuntu|debian) ;; *) return 0 ;; esac
  exists locale-gen || return 0
  # Idempotente: si ya está generado, no hace nada.
  if locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
    log "Locale en_US.UTF-8 ya presente; se omite."
    return 0
  fi
  log "Generando locale en_US.UTF-8…"
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8
}

ensure_stow() {
  exists stow && return 0
  log "GNU stow no encontrado; instalando…"
  case "${OS}" in
    macos)        exists brew && brew install stow ;;
    ubuntu|debian) sudo apt install -y stow ;;
    fedora)       sudo dnf install -y stow ;;
    arch|omarchy) sudo pacman -S --needed --noconfirm stow ;;
    bazzite)      log "stow se capeó con rpm-ostree; reinicia y re-ejecuta el bootstrap."; exit 1 ;;
    *) log "Instala 'stow' manualmente y reintenta."; exit 1 ;;
  esac
}

# herdr no está en apt/dnf/pacman/brew (salvo brew, que ya cubre el script);
# el instalador oficial funciona igual en Ubuntu/WSL, Fedora/Bazzite,
# Arch/Omarchy y macOS, así que no hace falta bifurcar por OS. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}

# Back up any real (non-symlink) files that would collide, then stow.
stow_packages() {
  local pkg rel f
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ ! -d "${ROOT_DIR}/${pkg}" ]]; then
      log "Paquete '${pkg}' no existe; se omite."
      continue
    fi
    while IFS= read -r -d '' f; do
      rel="${f#"${ROOT_DIR}/${pkg}/"}"
      backup_if_real "${HOME}/${rel}" "${rel}"
    done < <(find "${ROOT_DIR}/${pkg}" -type f -print0)
  done
  log "Enlazando paquetes con stow: ${STOW_PACKAGES[*]}"
  # Modo link (sin --restow): idempotente con symlinks ya correctos, así que
  # re-ejecutar es seguro y evita la fase unstow que disparaba el bug cosmético
  # de stow ("BUG in find_stowed_path?"). No limpia links de paquetes eliminados.
  stow -d "${ROOT_DIR}" --no-folding --target="${HOME}" "${STOW_PACKAGES[@]}"
}

# Perfiles extra de Claude Code (config dirs aparte para otras cuentas). El
# perfil por defecto es ~/.claude y lo enlaza stow; estos replican la misma
# config compartida vía symlink. Ver docs/claude-code.md.
CLAUDE_PROFILES=(work)

link_claude_profiles() {
  local p dir agent
  for p in "${CLAUDE_PROFILES[@]}"; do
    dir="${HOME}/.claude-${p}"
    log "Enlazando config compartida de Claude en ${dir}…"
    mkdir -p "${dir}/agents"
    ln -sfn "${ROOT_DIR}/claude/.claude/settings.json" "${dir}/settings.json"
    ln -sfn "${ROOT_DIR}/claude/.claude/CLAUDE.md" "${dir}/CLAUDE.md"
    for agent in "${ROOT_DIR}"/claude/.claude/agents/*.md; do
      [[ -e "${agent}" ]] || continue
      ln -sfn "${agent}" "${dir}/agents/$(basename "${agent}")"
    done
    # Las skills reales viven en el perfil por defecto (ahí las instala
    # `npx skills add -g`); los perfiles extra las comparten por symlink.
    if [[ -d "${dir}/skills" && ! -L "${dir}/skills" ]]; then
      log "AVISO: ${dir}/skills es un directorio real; muévelo a ~/.claude/skills y re-ejecuta."
    else
      ln -sfn "${HOME}/.claude/skills" "${dir}/skills"
    fi
  done
}

# El watcher de modos de CoolerControl es un servicio de USUARIO (necesita el
# socket de eventos de Hyprland, que vive en $XDG_RUNTIME_DIR) y su unidad la
# enlaza stow, así que esto va DESPUÉS de stow_packages y no en
# install-packages.sh (que corre antes del stow). Sin el token de la API
# (creado a mano desde la GUI, ver docs/omarchy.md) no hay nada que habilitar
# todavía. Idempotente.
#
# Safe-fail a propósito: nada de esta función debe poder abortar el resto del
# bootstrap (set -e). Cada paso que puede fallar por causas externas al repo
# (systemd de usuario no disponible, coolercontrold caído, hardware distinto)
# se comprueba explícitamente y, si falla, se registra en COOLERCONTROL_ISSUES
# en vez de propagar el error; report_coolercontrol_issues() imprime el
# resumen al final del bootstrap (ver main).
COOLERCONTROL_ISSUES=()

ensure_coolercontrol_mode_watcher() {
  [[ "${OS}" == "omarchy" ]] || return 0
  exists systemctl || return 0
  local token="${XDG_STATE_HOME:-${HOME}/.local/state}/coolercontrol-modes/api-token"
  if [[ ! -s "${token}" ]]; then
    log "Falta el token de la API de CoolerControl (${token}); watcher no habilitado."
    log "Créalo desde la GUI (Settings > Access Tokens) y reejecuta el bootstrap; ver docs/omarchy.md."
    COOLERCONTROL_ISSUES+=("Falta el token de la API (${token}); créalo desde la GUI (ver docs/omarchy.md).")
    return 0
  fi

  if ! systemctl --user daemon-reload; then
    log "systemctl --user daemon-reload falló; ¿hay sesión de usuario de systemd? Se omite CoolerControl."
    COOLERCONTROL_ISSUES+=("systemctl --user daemon-reload falló (¿sin sesión de usuario systemd?).")
    return 0
  fi

  if systemctl --user is-enabled --quiet coolercontrol-mode-watcher.service 2>/dev/null; then
    log "coolercontrol-mode-watcher ya habilitado; se omite."
    return 0
  fi

  log "Aprovisionando perfiles/modos de CoolerControl…"
  if ! "${HOME}/.local/bin/coolercontrol-provision"; then
    log "Aprovisionamiento falló; revisa manual (¿coolercontrold corriendo? ¿hardware detectado?)."
    COOLERCONTROL_ISSUES+=("coolercontrol-provision falló; revisa el log de arriba (¿coolercontrold corriendo?).")
    return 0
  fi

  log "Habilitando coolercontrol-mode-watcher (Silencio ⇄ Rendimiento)…"
  if ! systemctl --user enable --now coolercontrol-mode-watcher.service; then
    log "No se pudo habilitar coolercontrol-mode-watcher.service."
    COOLERCONTROL_ISSUES+=("systemctl --user enable --now coolercontrol-mode-watcher.service falló.")
  fi
}

report_coolercontrol_issues() {
  [[ ${#COOLERCONTROL_ISSUES[@]} -gt 0 ]] || return 0
  log "CoolerControl: ${#COOLERCONTROL_ISSUES[@]} paso(s) fallaron (no bloquearon el bootstrap):"
  local issue
  for issue in "${COOLERCONTROL_ISSUES[@]}"; do
    log "  - ${issue}"
  done
}

# Discos fijos del PC "andrea" (Games/LIBRARY), ver docs/storage.md. Gateado por
# hostname Y por la presencia real del UUID (blkid), así que en cualquier otra
# máquina es no-op seguro aunque STORAGE_MOUNTS no cambie. Idempotente: no
# duplica líneas de fstab ni symlinks ya creados.
STORAGE_MOUNTS=(
  "48ea0561-f38a-4966-a708-6d60f14e796b:/mnt/games:${HOME}/Games"
  "efe510d5-526e-46b3-bfa0-ac3db9570994:/mnt/library:${HOME}/Library"
)

ensure_storage_mounts() {
  [[ "$(hostname)" == "andrea" ]] || return 0
  exists blkid && exists mountpoint || { log "Storage: blkid/mountpoint no disponibles; se omite."; return 0; }

  local entry uuid mnt link
  for entry in "${STORAGE_MOUNTS[@]}"; do
    uuid="${entry%%:*}"
    mnt="${entry#*:}"; mnt="${mnt%%:*}"
    link="${entry##*:}"

    if ! blkid -U "${uuid}" >/dev/null 2>&1; then
      log "Storage: disco UUID ${uuid} no presente; se omite ${mnt}."
      continue
    fi

    sudo mkdir -p "${mnt}"

    if grep -q "UUID=${uuid}" /etc/fstab 2>/dev/null; then
      log "Storage: ${mnt} ya en /etc/fstab; se omite."
    else
      log "Storage: añadiendo ${mnt} (UUID=${uuid}) a /etc/fstab…"
      printf 'UUID=%s\t%s\text4\tdefaults,noatime,nofail,x-systemd.device-timeout=10\t0 2\n' \
        "${uuid}" "${mnt}" | sudo tee -a /etc/fstab >/dev/null
      sudo systemctl daemon-reload
    fi

    if ! mountpoint -q "${mnt}"; then
      sudo mount "${mnt}" || log "Storage: no se pudo montar ${mnt}; revisa manualmente."
    fi

    mountpoint -q "${mnt}" && sudo chown "$(id -un):$(id -gn)" "${mnt}"

    [[ -e "${link}" ]] || { ln -s "${mnt}" "${link}"; log "Storage: symlink ${link} → ${mnt}"; }
  done
}

# Fusiona caps:escape en el array xkb-options actual, preservando lo existente.
# $1 = valor crudo de `gsettings get`; echo del array fusionado.
xkb_merge() {
  local cur="$1"
  case "${cur}" in *caps:escape*) echo "${cur}"; return 0 ;; esac
  case "${cur}" in
    "@as []"|"[]"|"") echo "['caps:escape']" ;;
    *)                echo "${cur%]}, 'caps:escape']" ;;
  esac
}

apply_linux_keyboard() {
  is_wsl && { log "WSL: Caps→Esc lo gestiona Windows; se omite."; return 0; }
  exists gsettings || return 0   # solo GNOME (default de Ubuntu)
  local cur merged
  cur="$(gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null || echo '@as []')"
  merged="$(xkb_merge "${cur}")"
  if [[ "${merged}" == "${cur}" ]]; then
    log "caps:escape ya presente en xkb-options; se omite."
    return 0
  fi
  log "Remapeando Caps Lock → Escape (GNOME)…"
  gsettings set org.gnome.desktop.input-sources xkb-options "${merged}" || true
}

install_wslconfig() {
  is_wsl || return 0
  [[ -f "${ROOT_DIR}/wsl/.wslconfig" ]] || return 0
  local win_profile=""
  if exists wslpath && exists cmd.exe; then
    win_profile="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)"
  fi
  if [[ -n "${win_profile}" && -d "${win_profile}" ]]; then
    backup_if_real "${win_profile}/.wslconfig" "wslconfig.windows"
    cp "${ROOT_DIR}/wsl/.wslconfig" "${win_profile}/.wslconfig"
    log ".wslconfig → ${win_profile}/.wslconfig (aplica con: wsl --shutdown)"
  else
    log "No se pudo localizar el perfil de Windows; copia wsl/.wslconfig manualmente a C:\\Users\\<tu-usuario>\\.wslconfig"
  fi
}

# On macOS lazygit reads its config from ~/Library/Application Support/lazygit,
# not ~/.config. Symlink the stowed config there (mirrors the VS Code approach).
link_lazygit_macos() {
  [[ "${OS}" == "macos" ]] || return 0
  local src="${ROOT_DIR}/lazygit/.config/lazygit/config.yml"
  [[ -f "${src}" ]] || return 0
  local dest="$HOME/Library/Application Support/lazygit/config.yml"
  mkdir -p "$(dirname "${dest}")"
  backup_if_real "${dest}" "lazygit-config.yml.macos"
  ln -snf "${src}" "${dest}"
  log "Enlazado lazygit config → ${dest}"
}

# El extra lang.typescript de LazyVim (y los node globals de abajo) necesitan
# Node. Se provisiona con nvm para tener una versión moderna en cualquier OS.
# Sourcear nvm.sh en este proceso deja node/npm en el PATH para los pasos
# siguientes (sync de LazyVim → Mason, install_node_globals).
ensure_node() {
  # Misma ruta que usa la shell (zsh/.config/zsh/integrations.zsh); el installer
  # oficial respeta NVM_DIR si está exportado.
  export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
  if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
    log "Instalando nvm…"
    mkdir -p "${NVM_DIR}"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash || true
  fi
  # shellcheck disable=SC1091
  [[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
  if exists nvm && ! exists node; then
    log "Instalando Node LTS vía nvm…"
    nvm install --lts || true
  fi
}

# Mensaje final sobre cómo entrar a zsh. Clave: NO sugerir `source ~/.zshrc`,
# porque ~/.zshrc es sintaxis zsh y falla línea por línea si tu sesión actual es
# bash (bad substitution, `command not found: zinit`, etc.). Lo correcto es
# arrancar zsh en una sesión nueva o con `exec zsh`.
final_shell_hint() {
  local login_shell
  login_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
  [[ -n "${login_shell}" ]] || login_shell="${SHELL:-}"

  log "Bootstrap completo."
  case "${login_shell##*/}" in
    zsh) log "zsh ya es tu login shell." ;;
    *)   log "Aviso: zsh aún no es tu login shell; revisa el paso chsh de install-packages.sh." ;;
  esac
  case "${OS}" in
    omarchy)
      log "Cierra sesión de Hyprland y vuelve a entrar (o reinicia) para que \$SHELL se"
      log "actualice en toda la sesión; las ventanas NUEVAS de foot ya abren zsh"
      log "gracias al pin en foot.ini. Para probar aquí mismo: exec zsh"
      ;;
    *)
      log "Abre una terminal nueva para entrar a zsh, o cámbiate ya con: exec zsh"
      ;;
  esac
  log "No ejecutes 'source ~/.zshrc' desde bash: es config de zsh y dará errores."
}

install_node_globals() {
  local list="${ROOT_DIR}/packages/global-node-packages.txt"
  [[ -s "${list}" ]] || return 0
  if ! exists npm; then
    log "npm no disponible; se omiten paquetes globales de node."
    return 0
  fi
  local pkgs
  pkgs="$(grep -Ev '^\s*#|^\s*$' "${list}" | tr '\n' ' ')"
  [[ -n "${pkgs}" ]] || return 0
  log "Instalando paquetes globales de node: ${pkgs}"
  # shellcheck disable=SC2086
  npm install -g ${pkgs} || true
}

main() {
  OS="$(os_detect)"
  log "OS detectado: ${OS}"

  # Paquete solo-Omarchy: hook de OpenRGB (RGB sync con el tema) + autostart de hypr.
  # coolercontrol: perfiles/modos de temperatura + watcher que cambia de modo
  # según las ventanas abiertas (ver docs/omarchy.md).
  [[ "${OS}" == "omarchy" ]] && STOW_PACKAGES+=(omarchy coolercontrol)

  # Un solo prompt de sudo para todo el bootstrap; el keep-alive del padre cubre
  # install-packages.sh, ensure_locale y ensure_stow.
  require_sudo

  if [[ -x "${SCRIPT_DIR}/install-packages.sh" ]]; then
    log "Instalando paquetes base…"
    "${SCRIPT_DIR}/install-packages.sh"
  else
    log "scripts/install-packages.sh no encontrado o no ejecutable; se omite."
  fi

  # En un Mac recién instalado, brew/stow/code no están en el PATH de este
  # proceso padre; cargar el entorno de Homebrew para los pasos siguientes.
  if [[ "${OS}" == "macos" ]]; then
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [[ -x "$b" ]] && eval "$("$b" shellenv)" && break
    done
  fi

  ensure_locale
  ensure_stow
  ensure_herdr
  stow_packages
  link_claude_profiles
  ensure_coolercontrol_mode_watcher
  ensure_storage_mounts

  # Node antes del sync para que Mason pueda instalar el LSP de TypeScript.
  ensure_node

  # First-run LazyVim setup, headless (sin abrir la UI). install clona los plugins
  # faltantes; restore los fija a los commits EXACTOS de lazy-lock.json (reproducible
  # entre PCs). Se usa install+restore en vez de sync porque sync ACTUALIZA a la última
  # versión y reescribe el lock, provocando deriva entre máquinas. Idempotente.
  if exists nvim; then
    log "Instalando y fijando plugins de LazyVim al lockfile (headless)…"
    nvim --headless "+Lazy! install" "+Lazy! restore" +qa || true
  fi

  if [[ -f "${ROOT_DIR}/vscode/settings.json" ]]; then
    log "Sincronizando VS Code settings…"
    "${SCRIPT_DIR}/sync-vscode-settings.sh" || true
  fi

  if exists code; then
    log "Instalando extensiones de VS Code…"
    "${SCRIPT_DIR}/install-vscode-extensions.sh" || true
  else
    log "VS Code CLI (code) no disponible; se omiten extensiones."
  fi

  install_node_globals

  # Skills y MCP de Claude Code (necesita npx en PATH, ya cargado arriba).
  "${SCRIPT_DIR}/install-claude-skills.sh" || true

  link_lazygit_macos

  if [[ "${OS}" == "macos" ]]; then
    log "Aplicando defaults de macOS…"
    "${SCRIPT_DIR}/apply-macos-defaults.sh" || true
  fi

  if [[ "${OS}" != "macos" ]]; then
    apply_linux_keyboard
  fi

  install_wslconfig

  # Diagnóstico de arranque (solo Linux; avisos, nunca bloquea).
  [[ "${OS}" != "macos" ]] && bash "${SCRIPT_DIR}/boot-health.sh" || true

  report_coolercontrol_issues
  final_shell_hint
}

main "$@"
