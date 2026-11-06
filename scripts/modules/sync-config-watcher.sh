#!/usr/bin/env bash
# Activa el vigilante de shell.json/monitors.lua (unidades en omarchy/.config/systemd/user, ver
# docs/omarchy.md). Va DESPUÉS de stow_packages: las unidades las enlaza stow. Solo Omarchy.
# Seguro con `stow -R`: sync-config no hace nada si el archivo falta o ya es symlink.
# Safe-fail: nunca aborta el bootstrap. Idempotente.
ensure_sync_config_watcher() {
  [[ "${OS}" == "omarchy" ]] || return 0
  exists systemctl || return 0
  if ! systemctl --user daemon-reload; then
    log "systemctl --user daemon-reload falló; se omite el vigilante de sync-config."
    return 0
  fi
  if systemctl --user is-enabled --quiet sync-config-omarchy.path sync-config-hypr.path 2>/dev/null; then
    log "Vigilante de sync-config ya habilitado; se omite."
    return 0
  fi
  log "Habilitando el vigilante de sync-config (shell.json, monitors.lua)…"
  systemctl --user enable --now sync-config-omarchy.path sync-config-hypr.path \
    || log "No se pudo habilitar el vigilante de sync-config."
}
