#!/usr/bin/env bash
# Copia wsl/.wslconfig al perfil de Windows (Windows lo lee de ahí, no de $HOME
# de Linux). No-op fuera de WSL.

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
