# ============================================================================
# BASH CONFIG — entry point
# ============================================================================
# Shells no interactivas (scp, rsync -e, git sobre ssh, ...) no necesitan nada
# de esto.
case $- in
  *i*) ;;
  *) return ;;
esac

# ============================================================================
# BLE.SH (autosugerencias + syntax highlighting)
# ============================================================================
# Tiene que cargarse ANTES que cualquier otra cosa toque readline; se activa
# (ble-attach) al final de este archivo. Ver bash/.config/bash/plugins.sh para
# el instalador y docs/shell-and-dotfiles.md para el porqué del orden.

BASH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bash"
[[ -r "${BASH_CONFIG_DIR}/plugins.sh" ]] && source "${BASH_CONFIG_DIR}/plugins.sh"

_bde_ensure_blesh
BLESH_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh"
[[ -r "${BLESH_FILE}" ]] && source "${BLESH_FILE}" --noattach

# ============================================================================
# MODULE LOADER
# ============================================================================
# Configuración partida en módulos bajo ~/.config/bash/, mismo patrón que
# ~/.config/zsh/ (ver docs/shell-and-dotfiles.md). Se sourcean en orden
# determinista.

bash_modules=(
  exports       # locale + environment variables
  path          # Homebrew + PATH
  completion    # bash-completion + shopt varios
  history       # history options (shopt/HISTCONTROL)
  git           # aliases y funciones del plugin git de OMZ (gco, gst, ggp...)
  aliases       # aliases
  functions     # utility functions
  integrations  # fzf, zoxide, nvm, phpbrew, starship...
)

for _mod in "${bash_modules[@]}"; do
  [[ -r "${BASH_CONFIG_DIR}/${_mod}.sh" ]] && source "${BASH_CONFIG_DIR}/${_mod}.sh"
done
unset _mod bash_modules

# ============================================================================
# BLE.SH ATTACH
# ============================================================================
# Tiene que ser la ÚLTIMA línea del archivo (requisito de ble.sh).
[[ ${BLE_VERSION-} ]] && ble-attach
