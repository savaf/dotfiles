# ============================================================================
# PACKAGE MANAGERS (Homebrew)
# ============================================================================

# Homebrew - Linux
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Homebrew - macOS
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ============================================================================
# PATH
# ============================================================================

# Snap packages (Linux)
if [[ -d "/snap/bin" ]]; then
  export PATH="/snap/bin:$PATH"
fi

# User-local binaries
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"

# Android platform-tools oficiales (adb con `pair`; el de apt es viejo)
[[ -d "$HOME/platform-tools" ]] && export PATH="$HOME/platform-tools:$PATH"

# Shims de mise: las herramientas globales (nvim, lazygit, starship…) resuelven
# también fuera de la shell interactiva (popups de tmux, launchers, scripts).
[[ -d "$HOME/.local/share/mise/shims" ]] && export PATH="$HOME/.local/share/mise/shims:$PATH"

# ============================================================================
# PNPM
# ============================================================================

export PNPM_HOME="$HOME/.local/share/pnpm"
[[ -d "$PNPM_HOME" ]] && export PATH="$PNPM_HOME/bin:$PATH"
