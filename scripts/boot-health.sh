#!/usr/bin/env bash
# Diagnóstico de salud del arranque (solo lectura, nunca falla).
# Detecta las causas de login lento vistas en la práctica: USB defectuoso que
# bloquea la enumeración en el initrd, e initramfs sin módulos NVIDIA (prompt
# de LUKS invisible). Correr manualmente cuando el boot se sienta lento; el
# bootstrap lo invoca al final en Linux.
set -uo pipefail

log() { echo "[boot-health] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

exists systemd-analyze || exit 0
systemd-analyze time >/dev/null 2>&1 || exit 0 # boot aún no terminado, etc.

# 1. Tiempos por fase. Fase kernel > 60s = sospecha de stall en initrd
# (incluye la espera del prompt de LUKS, así que el umbral es generoso).
times="$(systemd-analyze time 2>/dev/null | head -1)"
log "${times}"
kernel_s="$(echo "${times}" | grep -oE '[0-9min .]+s \(kernel\)' \
  | awk '{ if ($0 ~ /min/) { gsub(/min/,"",$1); gsub(/s/,"",$2); print $1*60 + $2 } else { gsub(/s/,"",$1); print $1 } }')"
if awk "BEGIN{exit !(${kernel_s:-0} > 60)}"; then
  log "AVISO: fase kernel de ${kernel_s}s — posible stall en el initrd (USB defectuoso"
  log "       o espera larga en el prompt). Detalle: journalctl -b -k"
else
  log "OK: tiempos de arranque normales."
fi

# 2. USB que no enumera: la firma exacta es una ráfaga de timeouts -110/-62
# que retrasa udev (y con él el teclado en el prompt de LUKS) hasta ~1 min.
usb_errs="$(journalctl -b -k --no-pager 2>/dev/null \
  | grep -cE 'device descriptor read.*error -110|device not accepting address|Timeout while waiting for setup device command')"
if (( usb_errs > 3 )); then
  log "AVISO: ${usb_errs} errores de enumeración USB en este boot. Dispositivo(s):"
  journalctl -b -k --no-pager | grep -oE 'usb [0-9]+-[0-9.]+: (device descriptor read.*|device not accepting.*)' \
    | sort | uniq -c | sort -rn | head -3 | while read -r l; do log "       ${l}"; done
  log "       Desconéctalo o cámbialo de puerto; frena el arranque ~1 min."
else
  log "OK: sin errores de enumeración USB."
fi

# 3. NVIDIA en el initramfs (mismo check que ensure_omarchy_initramfs en
# install-packages.sh, pero solo aviso; el fix es sudo limine-mkinitcpio).
uki="/boot/EFI/Linux/omarchy_linux.efi"
if [[ -f /etc/mkinitcpio.conf.d/nvidia.conf && -f "${uki}" ]] && exists objcopy && exists lsinitcpio; then
  tmp="$(mktemp)"
  if objcopy -O binary --only-section=.initrd "${uki}" "${tmp}" 2>/dev/null \
      && lsinitcpio "${tmp}" 2>/dev/null | grep -q '/nvidia\.ko'; then
    log "OK: initramfs incluye los módulos NVIDIA."
  else
    log "AVISO: initramfs SIN módulos NVIDIA — el prompt de LUKS quedará en negro."
    log "       Corrige con: sudo limine-mkinitcpio  (o re-ejecuta el bootstrap)."
  fi
  rm -f "${tmp}"
fi

exit 0
