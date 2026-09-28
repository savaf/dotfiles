# ============================================================================
# SHELL INTEGRATIONS
# ============================================================================
# Puerto de zsh/.config/zsh/integrations.zsh (--zsh → --bash, .zsh → .bash,
# init zsh → init bash donde aplica).

# macOS iTerm2 integration
if [[ $OSTYPE == darwin* ]]; then
  test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
fi

# ---- FZF -----
# Set up fzf key bindings and fuzzy completion
if command -v fzf >/dev/null 2>&1; then
  if fzf --help 2>&1 | grep -q -- '--bash'; then
    eval "$(fzf --bash)"
  else
    [[ -r ~/.fzf.bash ]] && source ~/.fzf.bash
    [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [[ -r /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
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
  eval "$(zoxide init bash)"
fi

# ---- NVM (Node Version Manager) ----
# La instalación la hace scripts/bootstrap.sh (ensure_node); aquí solo se carga.
export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                 # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ---- PHP Brew ----
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc

# ---- STARSHIP -----
# Unificado con zsh (ver zsh/.config/zsh/plugins.zsh): mismo prompt en ambos
# shells. Se instala solo si falta (ver plugins.sh).
_bde_ensure_starship
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
