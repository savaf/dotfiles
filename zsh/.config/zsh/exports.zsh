# ============================================================================
# LOCALE
# ============================================================================

# Pick the best available UTF-8 locale (works on both Ubuntu/WSL and macOS).
setup_locale() {
  local locales=("C.UTF-8" "en_US.UTF-8" "POSIX")
  for loc in "${locales[@]}"; do
    if locale -a 2>/dev/null | grep -q "^${loc}$"; then
      export LANG="$loc"
      export LC_ALL="$loc"
      return 0
    fi
  done
  unset LC_ALL
  export LANG=C
}
setup_locale 2>/dev/null

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

# Default editor
export EDITOR='nvim'
export VISUAL='nvim'

# Colors for ls and completion
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# History timestamp format
export HISTTIMEFORMAT="[%F %T] "

# FZF default options
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
