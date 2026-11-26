#!/usr/bin/env bash
# Utilidades genéricas compartidas por bootstrap.sh e install-packages.sh:
# nada aquí instala nada por sí solo, solo lo usan los scripts que sí lo hacen.

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

os_detect() {
  if [[ "${OSTYPE:-}" == "darwin"* ]]; then echo "macos"; return; fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release 2>/dev/null || true
    # Omarchy no altera /etc/os-release (queda ID=arch); detectarlo por su marca.
    if [[ "${ID:-}" == "arch" ]] \
        && { [[ -d "${HOME}/.local/share/omarchy" ]] || command -v omarchy >/dev/null 2>&1; }; then
      echo "omarchy"; return
    fi
    echo "${ID:-linux}"; return
  fi
  echo "unknown"
}

# ¿Hay GPU NVIDIA? Solo cuenta el hardware (lspci). NVIDIA_FORCE=1|0 lo fuerza (pruebas).
has_nvidia_gpu() {
  [[ -n "${NVIDIA_FORCE:-}" ]] && { [[ "${NVIDIA_FORCE}" == 1 ]]; return; }
  # Sin grep -q: cortar la tubería haría fallar a lspci bajo pipefail.
  exists lspci && lspci 2>/dev/null | grep -i nvidia >/dev/null
}

# ¿Es seguro afirmar que NO hay NVIDIA? Falso si lspci no responde: ante la duda no se limpia.
lacks_nvidia_gpu() {
  ! has_nvidia_gpu && { [[ -n "${NVIDIA_FORCE:-}" ]] || lspci >/dev/null 2>&1; }
}

# Placa y USB se leen de sysfs (no hay lsusb). SYSFS_ROOT cambia la raíz (pruebas).
has_msi_board() {
  grep -qs 'Micro-Star' "${SYSFS_ROOT:-/sys}/class/dmi/id/board_vendor"
}

has_usb_nzxt() {
  grep -qsix 1e71 "${SYSFS_ROOT:-/sys}"/bus/usb/devices/*/idVendor
}

# ¿Algo con RGB que maneje OpenRGB? NZXT, Lian Li (0cf2) o Keychron, este por texto:
# un K2 se anuncia con el vendor de Apple (05ac).
has_rgb_usb() {
  local usb="${SYSFS_ROOT:-/sys}/bus/usb/devices"
  has_usb_nzxt || grep -qsix 0cf2 "${usb}"/*/idVendor \
    || grep -qsi keychron "${usb}"/*/manufacturer "${usb}"/*/product
}

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Shared backup dir for this run; created lazily on first real file moved.
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

# Move a real (non-symlink) file out of the way before we overwrite it.
# Requiere ROOT_DIR definido por el script que la llama (bootstrap.sh).
backup_if_real() {
  local target="$1" rel="$2"
  [[ -e "${target}" && ! -L "${target}" ]] || return 0
  # No mover archivos que resuelven dentro del repo (symlinks folded de stow).
  case "$(readlink -f "${target}")" in "${ROOT_DIR}"/*) return 0 ;; esac
  mkdir -p "$(dirname "${BACKUP_DIR}/${rel}")"
  log "Backup ${target} → ${BACKUP_DIR}/${rel}"
  mv "${target}" "${BACKUP_DIR}/${rel}"
}
