#!/usr/bin/env bash
set -euo pipefail

# Cambia el login shell del usuario entre bash (defecto) y zsh, a demanda.
# El bootstrap (ensure_bash_installed) ya fija bash; este script es para
# alternar manualmente.
#
# uso: ./scripts/switch-shell.sh zsh|bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${ROOT_DIR}/scripts/lib/common.sh"

target="${1:-}"
if [[ "${target}" != "zsh" && "${target}" != "bash" ]]; then
  echo "uso: $0 zsh|bash" >&2
  exit 1
fi

OS="$(os_detect)"

current_login_shell() {
  if [[ "${OS}" == "macos" ]]; then
    dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'
  else
    getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7
  fi
}

resolve_bin() {
  if [[ "${OS}" == "macos" && "${target}" == "bash" ]]; then
    [[ -x /opt/homebrew/bin/bash ]] && { echo /opt/homebrew/bin/bash; return; }
    [[ -x /usr/local/bin/bash ]] && { echo /usr/local/bin/bash; return; }
  fi
  command -v "${target}" || true
}

target_bin="$(resolve_bin)"
if [[ -z "${target_bin}" ]]; then
  log "${target} no está instalado; corre ./scripts/install-packages.sh primero."
  exit 1
fi

if [[ -r /etc/shells ]] && ! grep -qxF "${target_bin}" /etc/shells; then
  log "Añadiendo ${target_bin} a /etc/shells…"
  echo "${target_bin}" | sudo tee -a /etc/shells >/dev/null
fi

cur="$(current_login_shell)"
if [[ "${cur}" == "${target_bin}" ]]; then
  log "${target} ya es tu login shell (${target_bin})."
elif sudo chsh -s "${target_bin}" "$(id -un)"; then
  log "Login shell cambiado a ${target_bin}."
else
  log "chsh falló; cámbialo manual: chsh -s ${target_bin}"
  exit 1
fi

# Omarchy: foot toma el shell de $SHELL (congelado por uwsm), no de
# /etc/passwd — pin en foot.ini para que las ventanas NUEVAS abran el shell
# correcto sin esperar a un reinicio de sesión (mismo mecanismo que
# ensure_omarchy_shell() en install-packages.sh).
if [[ "${OS}" == "omarchy" ]]; then
  cfg="${HOME}/.config/foot/foot.ini"
  if [[ -f "${cfg}" ]]; then
    if grep -qE '^\s*shell\s*=' "${cfg}"; then
      sed -i "s|^\s*shell\s*=.*|shell=${target_bin}|" "${cfg}"
    elif grep -qE '^\s*\[main\]' "${cfg}"; then
      sed -i "/^\s*\[main\]/a shell=${target_bin}" "${cfg}"
    else
      printf '\n[main]\nshell=%s\n' "${target_bin}" >> "${cfg}"
    fi
    log "Pin de shell (${target}) actualizado en foot.ini."
  else
    log "foot.ini no encontrado; se omite el pin de shell."
  fi
  log "Cierra sesión de Hyprland y vuelve a entrar (o reinicia) para que \$SHELL"
  log "se actualice en toda la sesión; las ventanas NUEVAS de foot ya abren"
  log "${target} gracias al pin de arriba."
else
  log "Abre una terminal nueva para entrar a ${target}, o cámbiate ya con: exec ${target}"
fi
