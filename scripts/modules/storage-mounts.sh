#!/usr/bin/env bash
# Discos fijos del PC "andrea" (GAMES/LIBRARY), ver docs/storage.md. Gateado por
# hostname Y por la presencia real del UUID (blkid), así que en cualquier otra
# máquina es no-op seguro aunque STORAGE_MOUNTS no cambie. Idempotente: no
# duplica líneas de fstab ni symlinks ya creados.
# Formato: "UUID:fstype:punto-de-montaje:symlink". Los discos son exFAT (sin
# permisos POSIX): la propiedad se fija al montar con uid/gid, no con chown.
STORAGE_MOUNTS=(
  "58C9-EF00:exfat:/mnt/games:${HOME}/Games"
  "CABE-732A:exfat:/mnt/library:${HOME}/Library"
)

ensure_storage_mounts() {
  [[ "$(hostname)" == "andrea" ]] || return 0
  # shellcheck disable=SC2015 # el bloque tras || solo hace log y return 0; no puede fallar
  exists blkid && exists mountpoint || { log "Storage: blkid/mountpoint no disponibles; se omite."; return 0; }

  local entry uuid fstype mnt link opts rest
  for entry in "${STORAGE_MOUNTS[@]}"; do
    uuid="${entry%%:*}"; rest="${entry#*:}"
    fstype="${rest%%:*}"; rest="${rest#*:}"
    mnt="${rest%%:*}"
    link="${rest#*:}"

    if ! blkid -U "${uuid}" >/dev/null 2>&1; then
      log "Storage: disco UUID ${uuid} no presente; se omite ${mnt}."
      continue
    fi

    sudo mkdir -p "${mnt}"

    if grep -q "UUID=${uuid}" /etc/fstab 2>/dev/null; then
      log "Storage: ${mnt} ya en /etc/fstab; se omite."
    else
      log "Storage: añadiendo ${mnt} (UUID=${uuid}) a /etc/fstab…"
      opts="defaults,noatime,nofail,x-systemd.device-timeout=10"
      [[ "${fstype}" == "exfat" ]] && opts="defaults,noatime,uid=$(id -u),gid=$(id -g),umask=022,nofail,x-systemd.device-timeout=10"
      printf 'UUID=%s\t%s\t%s\t%s\t0 0\n' \
        "${uuid}" "${mnt}" "${fstype}" "${opts}" | sudo tee -a /etc/fstab >/dev/null
      sudo systemctl daemon-reload
    fi

    if ! mountpoint -q "${mnt}"; then
      sudo mount "${mnt}" || log "Storage: no se pudo montar ${mnt}; revisa manualmente."
    fi

    [[ -e "${link}" ]] || { ln -s "${mnt}" "${link}"; log "Storage: symlink ${link} → ${mnt}"; }
  done
}
