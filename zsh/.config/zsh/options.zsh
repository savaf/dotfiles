# ============================================================================
# SHELL OPTIONS
# ============================================================================
# Paridad con bash/.config/bash/completion.sh (autocd, cdspell, globstar).

setopt autocd              # escribir solo un directorio hace cd
setopt auto_pushd          # cd apila directorios (cd -1, dirs -v)
setopt pushd_ignore_dups
setopt pushd_silent
setopt extended_glob       # ^, ~, # en globs; ** ya es recursivo en zsh
setopt interactive_comments # permite # en la línea interactiva
setopt no_beep
setopt long_list_jobs
setopt complete_in_word    # completa desde el cursor, no solo al final
