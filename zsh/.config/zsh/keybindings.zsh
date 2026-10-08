# ============================================================================
# KEY BINDINGS
# ============================================================================

# History search with arrow keys
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[w' kill-region

# Movimiento por palabras y teclas de edición
bindkey '^[[1;5C' forward-word      # Ctrl+→
bindkey '^[[1;5D' backward-word     # Ctrl+←
bindkey '^[[H' beginning-of-line    # Home
bindkey '^[[F' end-of-line          # End
bindkey '^[[3~' delete-char         # Delete
bindkey '^[[3;5~' kill-word         # Ctrl+Delete
bindkey '^H' backward-kill-word     # Ctrl+Backspace
bindkey '^[[Z' reverse-menu-complete # Shift+Tab

# Ctrl+X Ctrl+E: editar la línea actual en $EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line
