# ============================================================================
# SHELL INTEGRATIONS
# ============================================================================

# macOS iTerm2 integration
if [[ $OSTYPE == darwin* ]]; then
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# ---- FZF -----
# Set up fzf key bindings and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  if fzf --help 2>&1 | grep -q -- '--zsh'; then
    eval "$(fzf --zsh)"
  else
    [[ -r ~/.fzf.zsh ]] && source ~/.fzf.zsh
    [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# FZF theme configuration
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"
export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# ---- ZOXIDE -----
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ---- NVM (Node Version Manager) ----
NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  echo "nvm is not installed. Installing nvm..."
  mkdir -p "$(dirname "$NVM_DIR")"
  git clone --depth=1 https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  echo "nvm installed successfully."
fi
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# ---- PHP Brew ----
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc

# ============================================================================
# FINAL INITIALIZATION
# ============================================================================

# Show system info (after everything is loaded)
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
elif command -v neofetch >/dev/null 2>&1; then
  neofetch
fi
