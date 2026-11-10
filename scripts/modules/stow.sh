#!/usr/bin/env bash
# Instala GNU stow si falta y enlaza los paquetes de config en $HOME.

# Config packages that get symlinked into $HOME via stow.
STOW_PACKAGES=(zsh bash git starship nvim tmux herdr shell lazygit claude mise ssh)

ensure_stow() {
  exists stow && return 0
  log "GNU stow no encontrado; instalando…"
  case "${OS}" in
    macos)        exists brew && brew install stow ;;
    ubuntu|debian) sudo apt install -y stow ;;
    arch|omarchy) sudo pacman -S --needed --noconfirm stow ;;
    *) log "Instala 'stow' manualmente y reintenta."; exit 1 ;;
  esac
}

# Back up any real (non-symlink) files that would collide, then stow.
stow_packages() {
  local pkg rel f
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ ! -d "${ROOT_DIR}/${pkg}" ]]; then
      log "Paquete '${pkg}' no existe; se omite."
      continue
    fi
    while IFS= read -r -d '' f; do
      rel="${f#"${ROOT_DIR}/${pkg}/"}"
      backup_if_real "${HOME}/${rel}" "${rel}"
    done < <(find "${ROOT_DIR}/${pkg}" -type f -print0)
  done
  log "Enlazando paquetes con stow: ${STOW_PACKAGES[*]}"
  # Modo link (sin --restow): idempotente con symlinks ya correctos, así que
  # re-ejecutar es seguro y evita la fase unstow que disparaba el bug cosmético
  # de stow ("BUG in find_stowed_path?"). No limpia links de paquetes eliminados.
  stow -d "${ROOT_DIR}" --no-folding --target="${HOME}" "${STOW_PACKAGES[@]}"
  # git solo guarda 644/755; ssh exige ~/.ssh 700 y config 600.
  if [[ -d "${HOME}/.ssh" ]]; then
    chmod 700 "${HOME}/.ssh"
    [[ -e "${HOME}/.ssh/config" ]] && chmod 600 "${HOME}/.ssh/config"
    link_host_conf
  fi
}

# ~/.config/git/host.conf (no versionado): git/.gitconfig lo incluye y fija la llave de
# firma de esta máquina (una por host). ssh no necesita nada: su config usa ~/.ssh/%L.pub.
link_host_conf() {
  local host
  host="$(hostname -s)"
  # Residuo de la versión anterior (~/.ssh/github.pub -> <host>.pub).
  [[ -L "${HOME}/.ssh/github.pub" ]] && rm "${HOME}/.ssh/github.pub"
  if [[ -f "${ROOT_DIR}/ssh/.ssh/${host}.pub" ]]; then
    mkdir -p "${HOME}/.config/git"
    printf '[user]\n\tsigningkey = ~/.ssh/%s.pub\n' "${host}" >"${HOME}/.config/git/host.conf"
  else
    # Sin .pub no hay llave que fijar: un host.conf viejo daría "Couldn't load public key".
    rm -f "${HOME}/.config/git/host.conf"
    log "Falta ssh/.ssh/${host}.pub: expórtala de Bitwarden y reejecuta (sin ella no se firma)."
  fi
}
