#!/usr/bin/env bash
# Instalador de una línea (Linux/macOS/WSL):
#   curl -fsSL https://raw.githubusercontent.com/savaf/dotfiles/main/install.sh | bash
#   curl -fsSL …/install.sh | bash -s -- <args para bootstrap.sh>
#
# Asegura git, clona (HTTPS, el repo es público) o actualiza el repo y lanza
# scripts/bootstrap.sh. Es autocontenido: corre antes de que el repo exista, así
# que no puede usar scripts/lib/. Variables opcionales:
#   DOTFILES_DIR          destino (def. ~/dotfiles)
#   DOTFILES_REPO         URL del repo (def. https://github.com/savaf/dotfiles.git)
#   DOTFILES_BRANCH       rama (def. main)
#   DOTFILES_NO_BOOTSTRAP=1  solo clonar/actualizar, sin lanzar el bootstrap
#
# Todo vive dentro de main(): si la descarga se corta a medias, bash no llega a
# ejecutar un script parcial.

set -euo pipefail

log() { echo "[install] $*"; }
die() { echo "[install] ERROR: $*" >&2; exit 1; }
exists() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

ensure_git() {
  exists git && return 0
  log "git no está instalado; instalándolo…"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if exists brew; then
      brew install git
    else
      xcode-select --install || true
      die "Termina la instalación de las Command Line Tools de Xcode y vuelve a ejecutar este instalador."
    fi
  elif exists apt-get; then
    as_root apt-get update && as_root apt-get install -y git
  elif exists pacman; then
    as_root pacman -S --needed --noconfirm git
  else
    die "No sé instalar git en este sistema; instálalo a mano y vuelve a ejecutar."
  fi
  exists git || die "git sigue sin estar disponible."
}

# ¿El origin del repo existente es este repo? Acepta HTTPS/SSH de savaf/dotfiles
# o exactamente DOTFILES_REPO (permite forks/espejos locales).
is_our_repo() {
  local url
  url="$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  [[ -n "${url}" ]] || return 1
  [[ "${url}" == "$2" ]] && return 0
  case "${url}" in
    *savaf/dotfiles|*savaf/dotfiles.git) return 0 ;;
  esac
  return 1
}

clone_or_update() {
  local dir="$1" repo="$2" branch="$3"
  if [[ -d "${dir}/.git" ]]; then
    is_our_repo "${dir}" "${repo}" || die "${dir} ya existe y no es este repo; usa DOTFILES_DIR=<otra ruta>."
    if [[ -n "$(git -C "${dir}" status --porcelain)" ]]; then
      log "${dir} tiene cambios locales; se omite el pull."
    else
      log "Actualizando ${dir}…"
      git -C "${dir}" pull --ff-only || log "No se pudo hacer fast-forward; sigo con lo que hay."
    fi
  elif [[ -e "${dir}" ]]; then
    die "${dir} ya existe y no es un repo git; muévelo o usa DOTFILES_DIR=<otra ruta>."
  else
    log "Clonando ${repo} (${branch}) en ${dir}…"
    git clone --branch "${branch}" "${repo}" "${dir}"
    log "origin quedó en HTTPS. Cuando tengas SSH listo (docs/git-and-ssh.md):"
    log "  git -C ${dir} remote set-url origin git@github.com:savaf/dotfiles.git"
  fi
}

main() {
  local dir="${DOTFILES_DIR:-${HOME}/dotfiles}"
  local repo="${DOTFILES_REPO:-https://github.com/savaf/dotfiles.git}"
  local branch="${DOTFILES_BRANCH:-main}"

  ensure_git
  clone_or_update "${dir}" "${repo}" "${branch}"

  if [[ "${DOTFILES_NO_BOOTSTRAP:-}" == "1" ]]; then
    log "DOTFILES_NO_BOOTSTRAP=1: listo. Para instalar: ${dir}/scripts/bootstrap.sh"
    return 0
  fi

  local bootstrap="${dir}/scripts/bootstrap.sh"
  [[ -f "${bootstrap}" ]] || die "No encuentro ${bootstrap}."
  log "Lanzando el bootstrap…"
  # Con `curl | bash` el stdin es el pipe: dárselo a la terminal real para que
  # sudo/chsh puedan preguntar. Sin terminal (CI), se hereda el stdin tal cual.
  if { : </dev/tty; } 2>/dev/null; then
    exec bash "${bootstrap}" "$@" </dev/tty
  fi
  exec bash "${bootstrap}" "$@"
}

main "$@"
