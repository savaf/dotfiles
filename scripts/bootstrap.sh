#!/usr/bin/env bash
set -euo pipefail

# Single entry point to set up these dotfiles on Ubuntu/WSL and macOS.
# Steps: install packages -> stow config packages -> VS Code -> OS extras.
#
# Este script es solo el orquestador: detecta el OS y llama, en orden, a los
# pasos instalables/opcionales, cada uno en su propio archivo bajo
# scripts/modules/ (stow, herdr, perfiles de Claude, CoolerControl, discos,
# teclado, .wslconfig, lazygit en macOS, node). Las utilidades genéricas que
# esos módulos comparten (log, os_detect, backup_if_real…) viven en
# scripts/lib/. Añadir un paso nuevo es: crear su módulo y llamarlo en main().

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/scripts/lib/common.sh"
source "${ROOT_DIR}/scripts/lib/sudo.sh"

for module in "${ROOT_DIR}"/scripts/modules/*.sh; do
  # shellcheck disable=SC1090
  source "${module}"
done

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
