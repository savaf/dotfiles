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

# ¿Esta máquina usa NVIDIA? Sí en "andrea" o si lspci ve una GPU NVIDIA. NVIDIA_FORCE=1|0 lo
# fuerza (pruebas); HOSTNAME_OVERRIDE sustituye a `hostname` (pruebas).
has_nvidia_gpu() {
  [[ -n "${NVIDIA_FORCE:-}" ]] && { [[ "${NVIDIA_FORCE}" == 1 ]]; return; }
  local host="${HOSTNAME_OVERRIDE:-$(hostname 2>/dev/null)}"
  host="${host%%.*}"
  [[ "${host,,}" == "andrea" ]] && return 0
  exists lspci && lspci 2>/dev/null | grep -qi nvidia
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
