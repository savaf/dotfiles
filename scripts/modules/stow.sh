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
  # git solo guarda 644/755; ssh exige ~/.ssh 700, config 600 y las .pub usadas como IdentityFile 600.
  if [[ -d "${HOME}/.ssh" ]]; then
    chmod 700 "${HOME}/.ssh"
    [[ -e "${HOME}/.ssh/config" ]] && chmod 600 "${HOME}/.ssh/config"
    # OpenSSH 10.x rechaza como IdentityFile una .pub con permisos 644.
    chmod 600 "${HOME}"/.ssh/*.pub 2>/dev/null || true
    link_ssh_key
  fi
}

# Cada máquina firma y autentica con su propia llave: github.pub -> <hostname>.pub
# (hostname en minúsculas; stow deja la .pub en ~/.ssh antes de llamar aquí).
link_ssh_key() {
  local host link="${HOME}/.ssh/github.pub" key
  host="$(hostname -s | tr '[:upper:]' '[:lower:]')"
  key="${HOME}/.ssh/${host}.pub"
  if [[ ! -e "${key}" ]]; then
    log "AVISO: no hay ${key}; github.pub (SSH y firma de git) no queda enlazado."
  elif [[ -e "${link}" && ! -L "${link}" ]]; then
    log "${link} es un archivo real: no se pisa. Bórralo o muévelo y reejecuta."
  else
    ln -sfn "${key}" "${link}"
  fi
}
