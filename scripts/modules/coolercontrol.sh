#!/usr/bin/env bash
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
