# ============================================================================
# ZINIT PLUGIN MANAGER
# ============================================================================

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# ============================================================================
# PROMPT THEME (Starship)
# ============================================================================
# Unificado con bash (ver bash/.config/bash/integrations.sh): mismo prompt en
# ambos shells, configurado en starship/.config/starship.toml.

if ! command -v starship >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh 2>/dev/null | sh -s -- --yes --bin-dir "$HOME/.local/bin" >/dev/null 2>&1
fi
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# ============================================================================
# ZSH PLUGINS (turbo: se cargan tras mostrar el primer prompt)
# ============================================================================
# `wait lucid` difiere la carga hasta que zsh queda idle, así el prompt aparece
# al instante. compinit corre síncrono en completion.zsh (los módulos lo necesitan).

# zsh-completions (blockf: zinit gestiona fpath) + highlighting + fzf-tab
zinit wait lucid for \
  blockf atpull'zinit creinstall -q .' zsh-users/zsh-completions \
  Aloxaf/fzf-tab \
  zsh-users/zsh-syntax-highlighting \
  atload'_zsh_autosuggest_start' zsh-users/zsh-autosuggestions

# Enhanced functionality
zinit wait lucid for \
  zap-zsh/fzf \
  MichaelAquilina/zsh-you-should-use

# ============================================================================
# OH-MY-ZSH SNIPPETS
# ============================================================================
# nvm se carga manualmente en integrations.zsh (NVM_DIR canónico); evitar doble-load.
zinit wait lucid for \
  OMZP::git \
  OMZP::sudo \
  OMZP::command-not-found \
  OMZP::colored-man-pages \
  OMZP::colorize \
  OMZP::node \
  OMZP::pm2 \
  OMZP::bun
