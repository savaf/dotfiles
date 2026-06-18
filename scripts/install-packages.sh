#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREW_CLI="${ROOT_DIR}/packages/brew-cli.txt"
BREW_CASKS="${ROOT_DIR}/packages/brew-casks.txt"
APT_CLI="${ROOT_DIR}/packages/apt-cli.txt"

log() { echo "[setup] $*"; }
exists() { command -v "$1" >/dev/null 2>&1; }

# Cache sudo credentials once and keep alive during script run (Linux only)
require_sudo() {
  if [[ "$OSTYPE" != darwin* ]]; then
    if ! exists sudo; then
      echo "[setup] sudo is required"; exit 1
    fi
    # Prompt once
    sudo -v
    # Keep sudo timestamp updated until this script exits
    # shellcheck disable=SC2064
    trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
    while true; do sudo -n true; sleep 60; done &
    SUDO_KEEPALIVE_PID=$!
  fi
}

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

install_macos() {
  if ! exists brew; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile || true
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  brew update
  if [[ -s "${BREW_CLI}" ]]; then
    log "Installing Homebrew formulae..."
    xargs -a "${BREW_CLI}" -r brew install
  fi
  if [[ -s "${BREW_CASKS}" ]]; then
    log "Installing Homebrew casks..."
    xargs -a "${BREW_CASKS}" -r brew install --cask
  fi

  if exists fzf; then
    log "Configuring fzf key-bindings and completion..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc || true
  fi

  if ! grep -q "/bin/zsh" /etc/shells; then
    echo "/bin/zsh" | sudo tee -a /etc/shells >/dev/null || true
  fi
  chsh -s /bin/zsh || true
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

  chsh -s "$(command -v zsh)" || true
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
