# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

HISTSIZE=50000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=999

# History options
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
setopt extended_history       # guarda timestamp y duración
setopt hist_expire_dups_first # al recortar, descarta primero los duplicados
setopt hist_reduce_blanks     # quita espacios sobrantes
setopt hist_verify            # !! y !$ se muestran antes de ejecutar
