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
# PROMPT THEME (Powerlevel10k)
# ============================================================================

zinit ice depth=1; zinit light romkatv/powerlevel10k

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
