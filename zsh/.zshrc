# ============================================================================
# POWERLEVEL10K INSTANT PROMPT (backup, desactivado)
# ============================================================================
# El prompt activo ahora es Starship (ver plugins.zsh → PROMPT THEME),
# unificado con bash. Este mecanismo es específico de Powerlevel10k y queda
# comentado como rollback — ver docs/shell-and-dotfiles.md.

# typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# ============================================================================
# MODULE LOADER
# ============================================================================
# Configuration is split into focused modules under ~/.config/zsh/.
# They are sourced in a deterministic order.

ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

zsh_modules=(
  exports       # locale + environment variables
  path          # Homebrew + PATH
  plugins       # zinit, plugins, OMZ snippets, prompt theme
  completion    # compinit + completion styling
  history       # history options
  keybindings   # key bindings
  aliases       # aliases
  functions     # utility functions
  integrations  # fzf, zoxide, nvm, fastfetch, ...
)

for _mod in "${zsh_modules[@]}"; do
  [[ -r "${ZSH_CONFIG_DIR}/${_mod}.zsh" ]] && source "${ZSH_CONFIG_DIR}/${_mod}.zsh"
done
unset _mod zsh_modules

# ============================================================================
# POWERLEVEL10K PROMPT CONFIG (backup, sin usar)
# ============================================================================
# El prompt activo es Starship (ver plugins.zsh). Para volver a Powerlevel10k:
# descomenta esta línea y el bloque de zinit en plugins.zsh, y descomenta el
# instant prompt de arriba.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
