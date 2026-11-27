#!/usr/bin/env bash
# El instalador oficial funciona igual en Ubuntu/WSL, Arch/Omarchy
# y macOS, así que no hace falta bifurcar por OS. Se actualiza con `herdr update`.
# En Omarchy `exists herdr` lo cumpliría el paquete pacman (repo omarchy, desfasado):
# quitarlo con `sudo pacman -R herdr`. Ver docs/herdr.md.
ensure_herdr() {
  exists herdr && return 0
  log "herdr no encontrado; instalando…"
  curl -fsSL https://herdr.dev/install.sh | sh
}

# App de escritorio (herdr-app + herdr-core, `hc`). Va aparte del TUI de arriba.
# No hay paquete en pacman/AUR ni cask de brew, y mise no sirve: su `herdr` es solo el TUI
# (herdrdev/herdr) y la app y el core no publican releases en GitHub. El instalador oficial
# deja la app en ~/.local/share/herdr-app (Linux) o ~/Applications/Herdr.app (macOS), añade el
# lanzador y el icono, instala herdr-core si falta y la app se actualiza sola. Correrlo otra vez
# la actualiza. Sin build para WSL ni otros sistemas. Ver docs/herdr-app.md.
ensure_herdr_app() {
  case "${OS:-$(os_detect)}" in
    macos | omarchy | arch | ubuntu | debian) ;;
    *) log "herdr-app: sin build para este sistema; se omite."; return 0 ;;
  esac
  if is_wsl; then
    log "herdr-app: WSL no tiene ventana propia; se omite."
    return 0
  fi
  exists herdr-app && return 0
  # ~/.local/bin puede no estar en el PATH del proceso de bootstrap.
  [[ -x "${HOME}/.local/bin/herdr-app" || -d "${HOME}/Applications/Herdr.app" ]] && return 0
  log "herdr-app no encontrado; instalando…"
  curl -fsSL https://releases.herdr.dev/app/install.sh | sh
}

# keys.json de la app es del usuario (la app solo lo reescribe si no se toca) y no va en Stow:
# aquí solo se añade, sin tocar el resto, el atajo que da el teclado al board (layout board-v).
# Si la app aún no se abrió no hay keys.json: se omite y se reintenta en la siguiente corrida.
ensure_herdr_app_keys() {
  local keys="${HERDR_APP_HOME:-${HOME}/.config/herdr-app}/keys.json" tmp
  [[ -f "${keys}" ]] || { log "herdr-app: sin keys.json (abre la app una vez); atajo del board omitido."; return 0; }
  exists jq || { log "herdr-app: sin jq; atajo del board omitido."; return 0; }
  jq -e '.["layout:board-v"]["ctrl-shift-a"] == "board.focus"' "${keys}" >/dev/null 2>&1 && return 0
  tmp="$(mktemp)"
  if jq '.["layout:board-v"]["ctrl-shift-a"] = "board.focus"' "${keys}" >"${tmp}" 2>/dev/null; then
    mv "${tmp}" "${keys}"
    log "herdr-app: ctrl-shift-a enfoca el board en board-v."
  else
    command rm -f "${tmp}"
    log "herdr-app: no pude leer ${keys}; atajo del board omitido."
  fi
}
