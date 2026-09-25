#!/usr/bin/env bash
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
