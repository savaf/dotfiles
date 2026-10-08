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
  completion    # completion styling + compinit
  history       # history options
  options       # setopt (autocd, pushd, extended_glob...)
  keybindings   # key bindings
  aliases       # aliases
  functions     # utility functions
  integrations  # fzf, zoxide, nvm, fastfetch, ...
)

for _mod in "${zsh_modules[@]}"; do
  [[ -r "${ZSH_CONFIG_DIR}/${_mod}.zsh" ]] && source "${ZSH_CONFIG_DIR}/${_mod}.zsh"
done
unset _mod zsh_modules
