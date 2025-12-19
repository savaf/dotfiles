#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

log() { echo "[setup] $*"; }

os_detect() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then echo "macos"; return; fi
  if [[ -r /etc/os-release ]]; then . /etc/os-release 2>/dev/null || true; echo "${ID:-linux}"; return; fi
  echo "unknown"
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

  if [[ -f "${ROOT_DIR}/vscode-settings.md" ]]; then
    log "Sincronizando VS Code settings desde vscode-settings.md…"
    "${SCRIPT_DIR}/sync-vscode-settings.sh" || true
  else
    log "vscode-settings.md no encontrado, se omite."
  fi

  if command -v code >/dev/null 2>&1; then
    if [[ -f "${ROOT_DIR}/vs-extensions.txt" ]]; then
      log "Instalando extensiones de VS Code…"
      "${SCRIPT_DIR}/install-vscode-extensions.sh" || true
    else
      log "vs-extensions.txt no encontrado, se omite."
    fi
  else
    log "VS Code CLI (code) no está disponible; saltando extensiones."
  fi

  log "Enlazando dotfiles básicos…"
  if [[ -f "${ROOT_DIR}/.zshrc" ]]; then ln -snf "${ROOT_DIR}/.zshrc" "$HOME/.zshrc"; fi
  if [[ -f "${ROOT_DIR}/.p10k.zsh" ]]; then ln -snf "${ROOT_DIR}/.p10k.zsh" "$HOME/.p10k.zsh"; fi

  if [[ "${OS}" == "macos" ]]; then
    log "Aplicando defaults de macOS…"
    "${SCRIPT_DIR}/apply-macos-defaults.sh" || true
  fi

  log "Listo. Abre una nueva terminal o ejecuta: source ~/.zshrc"
}

main "$@"
