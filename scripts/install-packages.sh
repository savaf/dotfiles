#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW_CLI="${ROOT_DIR}/packages/brew-cli.txt"
BREW_CASKS="${ROOT_DIR}/packages/brew-casks.txt"
APT_CLI="${ROOT_DIR}/packages/apt-cli.txt"

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
    echo "${ID:-linux}"; return
  fi
  echo "unknown"
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

  if ! grep -q "/bin/zsh" /etc/shells; then
    echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null || true
  fi
  sudo chsh -s /bin/zsh "$(id -un)" || true
}

# lazygit is not reliably packaged in apt; try apt first, then fall back to the
# latest GitHub release binary. Works on x86_64 and arm64 (incl. WSL).
install_lazygit() {
  if exists lazygit; then
    log "lazygit ya instalado ($(lazygit --version 2>/dev/null | head -1))"
    return 0
  fi

  log "Instalando lazygit (apt)…"
  if sudo apt install -y lazygit 2>/dev/null && exists lazygit; then
    return 0
  fi

  log "apt no tiene lazygit; descargando el último release de GitHub…"
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

  sudo chsh -s "$(command -v zsh)" "$(id -un)" || true
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
    *) echo "[setup] Unsupported or unknown OS: ${OS}"; exit 1 ;;
  esac
  post_checks
  log "Done. Restart your terminal or run: source ~/.zshrc"
}

main "$@"
