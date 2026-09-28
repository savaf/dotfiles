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
# ambos shells, configurado en starship/.config/starship.toml. Powerlevel10k
# queda como backup sin borrar — ver p10k/.p10k.zsh y el rollback comentado.

if ! command -v starship >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh 2>/dev/null | sh -s -- --yes --bin-dir "$HOME/.local/bin" >/dev/null 2>&1
fi
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# Rollback a Powerlevel10k:
# zinit ice depth=1; zinit light romkatv/powerlevel10k

# ============================================================================
# ZSH PLUGINS
# ============================================================================

# Essential plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

# Enhanced functionality
zinit light Aloxaf/fzf-tab
zinit light zap-zsh/fzf
zinit light MichaelAquilina/zsh-you-should-use

# ============================================================================
# OH-MY-ZSH SNIPPETS
# ============================================================================

# Core functionality
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
zinit snippet OMZP::colored-man-pages
zinit snippet OMZP::colorize

# Development tools
# nvm se carga manualmente en integrations.zsh (NVM_DIR canónico); evitar doble-load.
zinit snippet OMZP::node
zinit snippet OMZP::pm2
zinit snippet OMZP::bun
