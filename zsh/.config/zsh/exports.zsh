# ============================================================================
# LOCALE
# ============================================================================

# Pick the best available UTF-8 locale (works on both Ubuntu/WSL and macOS).
setup_locale() {
  # locale -a spells UTF-8 locales as "c.utf8"/"en_us.utf8"; normalize both
  # sides (lowercase, drop dashes) so our candidates actually match.
  local loc want available
  available=$(locale -a 2>/dev/null | tr 'A-Z' 'a-z' | tr -d '-')
  for loc in "C.UTF-8" "en_US.UTF-8"; do
    want=$(echo "$loc" | tr 'A-Z' 'a-z' | tr -d '-')
    if echo "$available" | grep -qx "$want"; then
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
