# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# compinit va aquí, síncrono: integrations.zsh (fzf, zoxide) llama a compdef
# al cargarse y los plugins turbo de plugins.zsh lo necesitan ya definido.
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit 2>/dev/null
else
  compinit -C 2>/dev/null
fi

# Ignore missing completion files silently
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Create cache directory if it doesn't exist
[[ ! -d ~/.zsh/cache ]] && mkdir -p ~/.zsh/cache

# Suppress completion errors for missing files
setopt NO_NOMATCH 2>/dev/null

# ============================================================================
# COMPLETION STYLING
# ============================================================================

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags --height=50%
zstyle ':fzf-tab:complete:*:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls --color $realpath 2>/dev/null'

# FZF tab completion previews
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Skip global compinit to improve startup time
skip_global_compinit=1
