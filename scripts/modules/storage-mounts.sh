#!/usr/bin/env bash
# Discos fijos del PC "andrea" (Games/LIBRARY), ver docs/storage.md. Gateado por
# hostname Y por la presencia real del UUID (blkid), así que en cualquier otra
# máquina es no-op seguro aunque STORAGE_MOUNTS no cambie. Idempotente: no
# duplica líneas de fstab ni symlinks ya creados.
STORAGE_MOUNTS=(
  "48ea0561-f38a-4966-a708-6d60f14e796b:/mnt/games:${HOME}/Games"
  "efe510d5-526e-46b3-bfa0-ac3db9570994:/mnt/library:${HOME}/Library"
)

ensure_storage_mounts() {
  [[ "$(hostname)" == "andrea" ]] || return 0
  exists blkid && exists mountpoint || { log "Storage: blkid/mountpoint no disponibles; se omite."; return 0; }

  local entry uuid mnt link
  for entry in "${STORAGE_MOUNTS[@]}"; do
    uuid="${entry%%:*}"
    mnt="${entry#*:}"; mnt="${mnt%%:*}"
    link="${entry##*:}"

    if ! blkid -U "${uuid}" >/dev/null 2>&1; then
      log "Storage: disco UUID ${uuid} no presente; se omite ${mnt}."
      continue
    fi

    sudo mkdir -p "${mnt}"

    if grep -q "UUID=${uuid}" /etc/fstab 2>/dev/null; then
      log "Storage: ${mnt} ya en /etc/fstab; se omite."
    else
      log "Storage: añadiendo ${mnt} (UUID=${uuid}) a /etc/fstab…"
      printf 'UUID=%s\t%s\text4\tdefaults,noatime,nofail,x-systemd.device-timeout=10\t0 2\n' \
        "${uuid}" "${mnt}" | sudo tee -a /etc/fstab >/dev/null
      sudo systemctl daemon-reload
    fi

    if ! mountpoint -q "${mnt}"; then
      sudo mount "${mnt}" || log "Storage: no se pudo montar ${mnt}; revisa manualmente."
    fi

    mountpoint -q "${mnt}" && sudo chown "$(id -un):$(id -gn)" "${mnt}"

    [[ -e "${link}" ]] || { ln -s "${mnt}" "${link}"; log "Storage: symlink ${link} → ${mnt}"; }
  done
}
