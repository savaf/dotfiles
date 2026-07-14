#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW_CLI="${ROOT_DIR}/packages/brew-cli.txt"
BREW_CASKS="${ROOT_DIR}/packages/brew-casks.txt"
APT_CLI="${ROOT_DIR}/packages/apt-cli.txt"
DNF_CLI="${ROOT_DIR}/packages/dnf-cli.txt"
PACMAN_CLI="${ROOT_DIR}/packages/pacman-cli.txt"
ARCH_APPS="${ROOT_DIR}/packages/arch-apps.txt"
OMARCHY_WEBAPPS="${ROOT_DIR}/packages/omarchy-webapps.txt"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

# require_sudo: prompt único + keep-alive. Si se corre vía bootstrap.sh, hereda
# el keep-alive del padre y no repregunta.
source "${ROOT_DIR}/scripts/lib-sudo.sh"

os_detect() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"; return
  fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    # Omarchy no altera /etc/os-release (queda ID=arch); detectarlo por su marca.
    if [[ "${ID:-}" == "arch" ]] \
        && { [[ -d "${HOME}/.local/share/omarchy" ]] || command -v omarchy >/dev/null 2>&1; }; then
      echo "omarchy"; return
    fi
    echo "${ID:-linux}"; return
  fi
  echo "unknown"
}

# Login shell actual del usuario, de forma portable: macOS no tiene getent, así
# que se lee de Directory Services; en Linux, de /etc/passwd vía getent.
current_login_shell() {
  if [[ "${OS}" == "macos" ]]; then
    dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'
  else
    getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7
  fi
}

# Garantiza que zsh esté instalado, registrado en /etc/shells y fijado como login
# shell del usuario. Consolida lo que antes vivía duplicado (y con `|| true` mudo)
# en install_macos/ubuntu/fedora/arch. Idempotente: no reinstala ni re-chsh si ya
# está todo en su sitio, y nunca hace `chsh -s ""` cuando zsh falta.
ensure_zsh() {
  # 1) Instalar el binario si no vino en la lista de paquetes (o distro rara).
  if ! exists zsh; then
    log "zsh no encontrado; instalándolo…"
    case "${OS}" in
      macos)         exists brew && brew install zsh ;;   # macOS ya trae /bin/zsh; guard
      ubuntu|debian) sudo apt install -y zsh ;;
      fedora)        sudo dnf install -y zsh ;;
      bazzite)       sudo rpm-ostree install --idempotent --apply-live zsh \
                       || { sudo rpm-ostree install --idempotent zsh; \
                            log "zsh capeado; reinicia y re-ejecuta el bootstrap."; } ;;
      arch|omarchy)  sudo pacman -S --needed --noconfirm zsh ;;
      *)             log "No sé instalar zsh en '${OS}'; hazlo manual y re-ejecuta."; return 0 ;;
    esac
  fi

  # 2) Resolver la ruta real; si sigue sin existir, no forzar el cambio de shell.
  local zsh_bin
  zsh_bin="$(command -v zsh || true)"
  if [[ -z "${zsh_bin}" ]]; then
    log "zsh sigue sin estar disponible; se omite el cambio de shell."
    return 0
  fi

  # 3) Registrar en /etc/shells (chsh lo exige; el paquete no siempre lo añade).
  if [[ -r /etc/shells ]] && ! grep -qxF "${zsh_bin}" /etc/shells; then
    log "Añadiendo ${zsh_bin} a /etc/shells…"
    echo "${zsh_bin}" | sudo tee -a /etc/shells >/dev/null || true
  fi

  # 4) Fijar como login shell solo si aún no lo es.
  local cur
  cur="$(current_login_shell)"
  if [[ "${cur}" == "${zsh_bin}" ]]; then
    log "zsh ya es tu login shell (${zsh_bin}); se omite chsh."
  elif sudo chsh -s "${zsh_bin}" "$(id -un)"; then
    log "Login shell cambiado a ${zsh_bin}."
  else
    log "No se pudo cambiar el login shell a zsh (chsh falló); cámbialo manual: chsh -s ${zsh_bin}"
  fi
}

# El compilador C de treesitter viene de las Xcode Command Line Tools. El
# instalador de Homebrew ya las instala en un Mac limpio; esto es el guard por si
# brew preexistía sin ellas.
ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools ya presentes; se omite."
    return 0
  fi
  log "Instalando Xcode Command Line Tools (confirma el diálogo que aparece)…"
  # xcode-select --install abre un popup GUI; no hay forma 100%
  # headless sin trucos frágiles de softwareupdate. El usuario confirma una vez.
  xcode-select --install || true
}

install_macos() {
  ensure_xcode_clt

  if ! exists brew; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Detect real prefix: /opt/homebrew on Apple Silicon, /usr/local on Intel.
    local brew_bin
    brew_bin="$( [[ -x /opt/homebrew/bin/brew ]] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew )"
    echo "eval \"\$(${brew_bin} shellenv)\"" >> ~/.zprofile || true
    eval "$(${brew_bin} shellenv)"
  fi

  brew update
  # stdin redirection (not GNU `xargs -a`/`-r`) so this works on BSD
  # xargs too (macOS). The `-s` guards above stand in for `-r`.
  if [[ -s "${BREW_CLI}" ]]; then
    log "Installing Homebrew formulae..."
    xargs brew install < "${BREW_CLI}"
  fi
  if [[ -s "${BREW_CASKS}" ]]; then
    log "Installing Homebrew casks..."
    xargs brew install --cask < "${BREW_CASKS}"
  fi

  if exists fzf; then
    log "Configuring fzf key-bindings and completion..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc || true
  fi

  ensure_zsh
}

# lazygit is not reliably packaged in apt; try apt first, then fall back to the
# latest GitHub release binary. Works on x86_64 and arm64 (incl. WSL).
install_lazygit() {
  if exists lazygit; then
    log "lazygit ya instalado ($(lazygit --version 2>/dev/null | head -1))"
    return 0
  fi

  if exists apt; then
    log "Instalando lazygit (apt)…"
    if sudo apt install -y lazygit 2>/dev/null && exists lazygit; then
      return 0
    fi
  fi

  log "Descargando el último release de lazygit desde GitHub…"
  local arch tarball version tmp
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l|armhf) arch="armv6" ;;
    *) log "Arquitectura no soportada: $(uname -m); omitiendo lazygit"; return 0 ;;
  esac

  version="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name":\s*"v\K[^"]*' || true)"
  if [[ -z "${version}" ]]; then
    log "No se pudo determinar la versión de lazygit; omitiendo."
    return 0
  fi

  tmp="$(mktemp -d)"
  tarball="lazygit_${version}_Linux_${arch}.tar.gz"
  if curl -fsSL -o "${tmp}/${tarball}" \
      "https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"; then
    tar -xf "${tmp}/${tarball}" -C "${tmp}" lazygit
    sudo install "${tmp}/lazygit" /usr/local/bin/lazygit
    log "lazygit ${version} instalado en /usr/local/bin/lazygit"
  else
    log "Fallo al descargar lazygit; omitiendo."
  fi
  rm -rf "${tmp}"
}

# apt solo trae Neovim 0.9.x; LazyVim necesita >= 0.11.2. Instala el tarball
# oficial en /opt y lo enlaza a /usr/local/bin (que precede a /usr/bin en PATH).
ensure_neovim() {
  local NVIM_VERSION="v0.11.3"
  if exists nvim; then
    local major minor
    read -r major minor < <(nvim --version | sed -n '1s/^NVIM v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
    if [[ -n "${major}" && ( "${major}" -gt 0 || "${minor}" -ge 11 ) ]]; then
      log "Neovim ya >= 0.11 ($(nvim --version | head -1)); se omite."
      return 0
    fi
  fi

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) log "Arquitectura no soportada para Neovim tarball: $(uname -m); omitiendo."; return 0 ;;
  esac

  local tarball="nvim-linux-${arch}.tar.gz" tmp
  tmp="$(mktemp -d)"
  log "Descargando Neovim ${NVIM_VERSION} (${arch})…"
  if curl -fsSL -o "${tmp}/${tarball}" \
      "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/${tarball}"; then
    sudo rm -rf "/opt/nvim-linux-${arch}"
    sudo tar -xzf "${tmp}/${tarball}" -C /opt
    sudo ln -sf "/opt/nvim-linux-${arch}/bin/nvim" /usr/local/bin/nvim
    log "Neovim ${NVIM_VERSION} instalado en /usr/local/bin/nvim"
  else
    log "Fallo al descargar Neovim; omitiendo."
  fi
  rm -rf "${tmp}"
}

# LazyVim necesita una Nerd Font para los iconos. La instala en el perfil del
# usuario (no requiere sudo). Misma fuente que el cask de macOS (Monaspace).
# En WSL la fuente real es la del terminal de Windows; esto solo
# aplica a Linux de escritorio. Inofensivo si se ejecuta en WSL.
ensure_nerd_font() {
  if fc-list 2>/dev/null | grep -qi 'Monaspace.*Nerd'; then
    log "Nerd Font (Monaspace) ya instalada; se omite."
    return 0
  fi
  if ! exists fc-cache; then
    log "fontconfig no disponible; se omite la Nerd Font."
    return 0
  fi

  local NF_VERSION="v3.4.0" font_dir="${HOME}/.local/share/fonts" tmp
  tmp="$(mktemp -d)"
  log "Descargando Nerd Font Monaspace ${NF_VERSION}…"
  if curl -fsSL -o "${tmp}/Monaspace.tar.xz" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/Monaspace.tar.xz"; then
    mkdir -p "${font_dir}"
    tar -xJf "${tmp}/Monaspace.tar.xz" -C "${font_dir}"
    fc-cache -f "${font_dir}" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
    log "Nerd Font Monaspace instalada en ${font_dir}"
  else
    log "Fallo al descargar la Nerd Font; se omite."
  fi
  rm -rf "${tmp}"
}

install_ubuntu() {
  log "Updating and upgrading Ubuntu packages..."
  sudo apt update && sudo apt upgrade -y

  if [[ -s "${APT_CLI}" ]]; then
    log "Installing apt packages from list..."
    PKGS=$(grep -Ev '^\s*#|^\s*$' "${APT_CLI}" | tr '\n' ' ')
    sudo apt install -y ${PKGS}
  fi

  if exists fdfind && ! exists fd; then
    log "Creating fd convenience symlink → fdfind"
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
  fi
  if exists batcat && ! exists bat; then
    log "Creating bat convenience symlink → batcat"
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
  fi

  install_lazygit
  ensure_neovim
  ensure_nerd_font

  ensure_zsh
}

# Fedora clásica usa dnf. Bazzite (Fedora Atomic) es inmutable: no hay dnf en
# el host; los paquetes se capean con rpm-ostree. Misma lista para ambos.
install_fedora() {
  local pkgs
  pkgs="$(grep -Ev '^\s*#|^\s*$' "${DNF_CLI}" | tr '\n' ' ')"

  if exists rpm-ostree; then
    log "Sistema inmutable (rpm-ostree) detectado; capeando paquetes faltantes…"
    # rpm-ostree falla con paquetes ya presentes en la imagen base: filtrar.
    local p missing=()
    for p in ${pkgs}; do rpm -q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if ((${#missing[@]})); then
      # --apply-live aplica sin reboot; si no está soportado, capa normal.
      if ! sudo rpm-ostree install --idempotent --apply-live "${missing[@]}"; then
        sudo rpm-ostree install --idempotent "${missing[@]}"
        log "Paquetes capeados; reinicia para aplicarlos y re-ejecuta el bootstrap."
      fi
    else
      log "Todos los paquetes ya presentes; se omite."
    fi
  elif [[ -n "${pkgs// /}" ]]; then
    log "Installing dnf packages from list..."
    # shellcheck disable=SC2086
    sudo dnf install -y ${pkgs}
  fi

  install_lazygit
  ensure_neovim
  ensure_nerd_font

  ensure_zsh
}

# En Omarchy la sesión Hyprland/uwsm arranca con SHELL "congelado" y Alacritty
# (vía xdg-terminal-exec) toma el shell de $SHELL, no de /etc/passwd. Fijar el
# shell en el alacritty.toml del usuario hace que las ventanas nuevas abran zsh
# sin depender de un reboot. Idempotente: no duplica la clave si ya existe.
ensure_omarchy_zsh() {
  local cfg="${HOME}/.config/alacritty/alacritty.toml"
  [[ -f "${cfg}" ]] || { log "alacritty.toml no encontrado; se omite el pin de shell."; return 0; }
  if grep -qE '^\s*shell\s*=' "${cfg}"; then
    log "Pin de shell ya presente en alacritty.toml; se omite."
  elif grep -qE '^\s*\[terminal\]' "${cfg}"; then
    # Insertar la clave justo debajo del encabezado [terminal] existente.
    sed -i '/^\s*\[terminal\]/a shell = { program = "/usr/bin/zsh" }' "${cfg}"
    log "Pin de shell (zsh) añadido bajo [terminal] en alacritty.toml."
  else
    printf '\n[terminal]\nshell = { program = "/usr/bin/zsh" }\n' >> "${cfg}"
    log "Sección [terminal] con pin de shell (zsh) añadida a alacritty.toml."
  fi
  log "Reinicia o cierra sesión de Hyprland y vuelve a entrar para que \$SHELL se"
  log "actualice en toda la sesión; mientras tanto, las ventanas NUEVAS de Alacritty"
  log "ya abren zsh gracias al pin de arriba."
}

# Con NVIDIA + LUKS, el prompt de contraseña queda en negro si los módulos
# nvidia no están dentro del initramfs. Omarchy los configura en
# /etc/mkinitcpio.conf.d/nvidia.conf, pero si ese drop-in aparece (update,
# migración) DESPUÉS de la última regeneración, la imagen queda desactualizada.
# Aquí se detecta el caso inspeccionando el UKI real y se regenera si falta.
ensure_omarchy_initramfs() {
  local uki="/boot/EFI/Linux/omarchy_linux.efi"
  [[ -f /etc/mkinitcpio.conf.d/nvidia.conf && -f "${uki}" ]] || return 0
  exists limine-mkinitcpio || return 0
  local tmp
  tmp="$(mktemp)"
  if objcopy -O binary --only-section=.initrd "${uki}" "${tmp}" \
      && lsinitcpio "${tmp}" | grep -q '/nvidia\.ko'; then
    log "Initramfs ya incluye los módulos NVIDIA; se omite."
  else
    log "Initramfs sin módulos NVIDIA (sin video en el prompt de LUKS); regenerando..."
    sudo limine-mkinitcpio
  fi
  rm -f "${tmp}"
}

# Webapps de Omarchy (equivalente a casks sin buen paquete Linux). Lista en
# omarchy-webapps.txt con formato Nombre|URL|IconoURL, los 3 args no
# interactivos de omarchy-webapp-install.
ensure_omarchy_webapps() {
  exists omarchy-webapp-install || return 0
  while IFS='|' read -r name url icon; do
    [[ -z "${name}" || "${name}" =~ ^[[:space:]]*# ]] && continue
    if [[ -f "${HOME}/.local/share/applications/${name}.desktop" ]]; then
      log "Webapp '${name}' ya existe; se omite."
    else
      log "Creando webapp '${name}'..."
      omarchy-webapp-install "${name}" "${url}" "${icon}" || log "Fallo creando webapp '${name}' (¿sin red?); continúa."
    fi
  done < "${OMARCHY_WEBAPPS}"
}

# Arch/Omarchy: repos oficiales traen lazygit y neovim actuales, así que no
# hacen falta los fallbacks de GitHub. Omarchy ya trae casi todo (--needed salta).
install_arch() {
  local pkgs
  pkgs="$(grep -Ev '^\s*#|^\s*$' "${PACMAN_CLI}" | tr '\n' ' ')"

  if [[ -n "${pkgs// /}" ]]; then
    log "Installing pacman packages from list..."
    # shellcheck disable=SC2086
    sudo pacman -S --needed --noconfirm ${pkgs}
  fi

  # Apps GUI vía yay (repos + AUR); mismo mecanismo que usa Omarchy por defecto
  # (omarchy-pkg-aur-add es un wrapper de esto y solo existe en Omarchy).
  local apps
  apps="$(grep -Ev '^\s*#|^\s*$' "${ARCH_APPS}" | tr '\n' ' ')"
  if [[ -n "${apps// /}" ]]; then
    if exists yay; then
      log "Installing GUI apps with yay..."
      # shellcheck disable=SC2086
      yay -S --needed --noconfirm ${apps}
    else
      log "yay no encontrado; omito apps GUI (packages/arch-apps.txt). Instala yay y re-ejecuta."
    fi
  fi

  ensure_nerd_font

  ensure_zsh

  if [[ "${OS}" == "omarchy" ]]; then
    # Fijar el shell en Alacritty por el SHELL "congelado" de uwsm.
    ensure_omarchy_zsh
    ensure_omarchy_webapps
    ensure_omarchy_initramfs
  fi
}

post_checks() {
  echo "[versions]"
  exists zsh && zsh --version || echo "zsh: not found"
  exists brew && brew --version || true
  exists fzf && fzf --version || echo "fzf: not found"
  exists zoxide && zoxide --version || echo "zoxide: not found"
  exists eza && eza --version || echo "eza: not found"
  if exists bat; then bat --version; elif exists batcat; then batcat --version; else echo "bat/batcat: not found"; fi
  if exists nvim; then nvim --version >/dev/null || true; elif exists neovim; then neovim --version >/dev/null || true; else echo "neovim: not found"; fi
}

main() {
  OS="$(os_detect)"
  log "Detected OS: ${OS}"
  # Ensure single sudo prompt and keep-alive for Linux
  require_sudo
  case "${OS}" in
    macos) install_macos ;;
    ubuntu|debian) install_ubuntu ;;
    fedora|bazzite) install_fedora ;;
    arch|omarchy) install_arch ;;
    *) echo "[setup] Unsupported or unknown OS: ${OS}"; exit 1 ;;
  esac
  post_checks
  log "Done. Restart your terminal or run: source ~/.zshrc"
}

main "$@"
