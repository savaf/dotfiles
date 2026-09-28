# ============================================================================
# BASH-COMPLETION
# ============================================================================
# El paquete bash-completion (ver packages/*.txt) no se auto-carga en shells
# interactivas no-login; hay que sourcearlo a mano.

if ! shopt -oq posix; then
  if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
  elif [[ -f /etc/bash_completion ]]; then
    source /etc/bash_completion
  elif command -v brew >/dev/null 2>&1 && [[ -r "$(brew --prefix)/etc/profile.d/bash_completion.sh" ]]; then
    source "$(brew --prefix)/etc/profile.d/bash_completion.sh"
  fi
fi

# ============================================================================
# OPCIONES DE SHELL RELACIONADAS
# ============================================================================
shopt -s globstar 2>/dev/null      # ** para globbing recursivo (≈ extended_glob de zsh)
shopt -s autocd 2>/dev/null        # escribir solo un directorio hace cd (bash >= 4)
shopt -s cdspell 2>/dev/null       # tolera typos menores en cd
shopt -s dirspell 2>/dev/null      # ídem, durante el completado
shopt -s checkwinsize 2>/dev/null  # recalcula LINES/COLUMNS tras cada comando
