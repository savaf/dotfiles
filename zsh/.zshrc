# ============================================================================
# POWERLEVEL10K INSTANT PROMPT
# ============================================================================
# Must stay near the top of ~/.zshrc. Code that may require console input
# (password prompts, [y/n] confirmations, etc.) must go ABOVE this block.

# Suppress instant prompt warnings for cleaner startup
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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
# POWERLEVEL10K PROMPT CONFIG
# ============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
