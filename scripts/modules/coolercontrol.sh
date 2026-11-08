#!/usr/bin/env bash
# Setup de CoolerControl (token, curvas de curves.json y watcher Silencio ⇄
# Rendimiento): todo lo hace coolercontrol-setup, que enlaza stow, así que esto
# va DESPUÉS de stow_packages. Aquí corre sin TTY (</dev/null): si falta el
# token no se queda esperando, falla y lo deja en el resumen final. Para
# pedirlo de forma interactiva: correr `coolercontrol-setup` a mano (ver
# docs/omarchy.md).
#
# Safe-fail a propósito: nada de esto debe abortar el resto del bootstrap
# (set -e). Los fallos van a COOLERCONTROL_ISSUES y report_coolercontrol_issues()
# los imprime al final (ver main).
COOLERCONTROL_ISSUES=()

ensure_coolercontrol_mode_watcher() {
  [[ "${OS}" == "omarchy" ]] || return 0
  exists systemctl || return 0
  log "Configurando CoolerControl (curvas + watcher Silencio ⇄ Rendimiento)…"
  if ! "${HOME}/.local/bin/coolercontrol-setup" </dev/null; then
    COOLERCONTROL_ISSUES+=("coolercontrol-setup falló (¿falta el token?); córrelo a mano: coolercontrol-setup")
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
