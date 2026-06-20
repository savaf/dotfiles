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

# ============================================================================
# PNPM
# ============================================================================

export PNPM_HOME="$HOME/.local/share/pnpm"
[[ -d "$PNPM_HOME" ]] && export PATH="$PNPM_HOME/bin:$PATH"
