#!/usr/bin/env bash
set -euo pipefail

# Single entry point to set up these dotfiles on Ubuntu/WSL and macOS.
# Steps: install packages -> stow config packages -> VS Code -> OS extras.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

os_detect() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then echo "macos"; return; fi
  if [[ -r /etc/os-release ]]; then . /etc/os-release 2>/dev/null || true; echo "${ID:-linux}"; return; fi
  echo "unknown"
}

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Config packages that get symlinked into $HOME via stow.
STOW_PACKAGES=(zsh git p10k nvim tmux shell lazygit)

ensure_stow() {
  exists stow && return 0
  log "GNU stow no encontrado; instalando…"
  case "${OS}" in
    macos)        exists brew && brew install stow ;;
    ubuntu|debian) sudo apt install -y stow ;;
    *) log "Instala 'stow' manualmente y reintenta."; exit 1 ;;
  esac
}

# Back up any real (non-symlink) files that would collide, then stow.
stow_packages() {
  local backup_dir="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
  local pkg rel target f
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ ! -d "${ROOT_DIR}/${pkg}" ]]; then
      log "Paquete '${pkg}' no existe; se omite."
      continue
    fi
    while IFS= read -r -d '' f; do
      rel="${f#"${ROOT_DIR}/${pkg}/"}"
      target="${HOME}/${rel}"
      if [[ -e "${target}" && ! -L "${target}" ]]; then
        mkdir -p "$(dirname "${backup_dir}/${rel}")"
        log "Backup ${target} → ${backup_dir}/${rel}"
        mv "${target}" "${backup_dir}/${rel}"
      fi
    done < <(find "${ROOT_DIR}/${pkg}" -type f -print0)
  done
  log "Enlazando paquetes con stow: ${STOW_PACKAGES[*]}"
  ( cd "${ROOT_DIR}" && stow --restow --target="${HOME}" "${STOW_PACKAGES[@]}" )
}

install_wslconfig() {
  is_wsl || return 0
  [[ -f "${ROOT_DIR}/wsl/.wslconfig" ]] || return 0
  local win_profile=""
  if exists wslpath && exists cmd.exe; then
    win_profile="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)"
  fi
  if [[ -n "${win_profile}" && -d "${win_profile}" ]]; then
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
  ln -snf "${src}" "${dest}"
  log "Enlazado lazygit config → ${dest}"
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

  ensure_stow
  stow_packages

  # First-run LazyVim sync: clones lazy.nvim, installs plugins and compiles
  # treesitter parsers without opening the UI. Safe to re-run (idempotent).
  if exists nvim; then
    log "Sincronizando plugins de LazyVim (headless)…"
    nvim --headless "+Lazy! sync" +qa || true
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

  link_lazygit_macos

  if [[ "${OS}" == "macos" ]]; then
    log "Aplicando defaults de macOS…"
    "${SCRIPT_DIR}/apply-macos-defaults.sh" || true
  fi

  install_wslconfig

  log "Listo. Abre una nueva terminal o ejecuta: source ~/.zshrc"
}

main "$@"
