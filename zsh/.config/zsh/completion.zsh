# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Load completions with better performance and error handling
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

# Replay cached completions (suppress errors)
zinit cdreplay -q 2>/dev/null

# Suppress completion errors for missing files
setopt NO_NOMATCH 2>/dev/null

# ============================================================================
# COMPLETION STYLING
# ============================================================================

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# FZF tab completion previews
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Skip global compinit to improve startup time
skip_global_compinit=1
