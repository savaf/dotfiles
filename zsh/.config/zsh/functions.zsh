# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

### ARCHIVE EXTRACTION
# usage: ex <file>
function ex() {
  if [[ -z "$1" ]]; then
    # display usage if no parameters given
    echo "Usage: ex <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
  else
    for n in "$@"; do
      if [[ -f "$n" ]]; then
        case "${n%,}" in
          *.cbt|*.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.tar)
            tar xvf "$n" ;;
          *.lzma)      unlzma ./"$n" ;;
          *.bz2)       bunzip2 ./"$n" ;;
          *.cbr|*.rar) unrar x -ad ./"$n" ;;
          *.gz)        gunzip ./"$n" ;;
          *.cbz|*.epub|*.zip) unzip ./"$n" ;;
          *.z)         uncompress ./"$n" ;;
          *.7z|*.arj|*.cab|*.cb7|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.pkg|*.rpm|*.udf|*.wim|*.xar)
            7z x ./"$n" ;;
          *.xz)        unxz ./"$n" ;;
          *.exe)       cabextract ./"$n" ;;
          *.cpio)      cpio -id < ./"$n" ;;
          *.cba|*.ace) unace x ./"$n" ;;
          *)
            echo "ex: '$n' - unknown archive method"
            return 1 ;;
        esac
      else
        echo "'$n' - file does not exist"
        return 1
      fi
    done
  fi
}

# Create directory and navigate to it
function mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Quick find function
function ff() {
  find . -name "*$1*" -type f
}

# Quick grep in files
function fgrep_files() {
  grep -r "$1" . --include="*.$2"
}

# Git log with graph
function glog() {
  git log --oneline --graph --all --decorate "${@}"
}

# Quick weather check (requires curl)
function weather() {
  curl -s "wttr.in/${1:-}" | head -7
}

# Quick file backup
function backup() {
  cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
}

# Claude Code con un config dir aislado: credenciales, sesiones, historial y MCP
# propios por perfil. Sin perfil (`claude` a secas) se usa ~/.claude.
#   uso: claude-profile <perfil> [args de claude...]
function claude-profile() {
  if (( $# == 0 )); then
    echo "uso: claude-profile <perfil> [args de claude...]"
    return 1
  fi
  local profile="$1"; shift
  CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" command claude "$@"
}

# Coding cockpit: neovim + claude en tmux
#
# Layout: dos paneles a alto completo
#   +-----------------+------------+
#   |                 |            |
#   |      nvim       |   claude   |
#   |      (60%)      |   (40%)    |
#   +-----------------+------------+
#
# Arma el cockpit en la ventana destino. Captura pane-id en vez de .1/.2
# para ser robusto en macOS y WSL.
#   $1 = target tmux (session:window)   $2 = working dir   $3 = perfil (opcional)
function _nic_cockpit() {
  local win="$1" dir="$2" profile="${3:-}" cmd p_nvim p_claude
  cmd='claude'
  [[ -n "$profile" ]] && cmd="claude-profile $profile"
  p_nvim=$(tmux display-message -p -t "$win" '#{pane_id}')
  p_claude=$(tmux split-window -h -t "$win" -c "$dir" -l 40% -P -F '#{pane_id}')
  tmux send-keys -t "$p_nvim" 'nvim' C-m
  tmux send-keys -t "$p_claude" "$cmd" C-m
  tmux select-pane -t "$p_nvim"
}

# usage: nic [-p perfil] [name]   (default: basename del directorio actual)
#   - fuera de tmux: crea/attachea una sesión con el cockpit
#   - dentro de tmux: arma el cockpit en la ventana actual (un proyecto por ventana)
#   - -p <perfil>: el pane de claude usa ese config dir (ver claude-profile)
function nic() {
  local profile=""
  while [[ "${1:-}" == -* ]]; do
    case "$1" in
      -p) profile="${2:-}"; shift 2 ;;
      *)  echo "nic: opción desconocida '$1' (uso: nic [-p perfil] [nombre])"; return 1 ;;
    esac
  done
  if [[ -n "$profile" && ! -d "$HOME/.claude-$profile" ]]; then
    echo "nic: perfil '$profile' sin config dir (~/.claude-$profile); corre el bootstrap."
    return 1
  fi

  local name="${1:-$(basename "$PWD")}"
  name="${name//[.:]/_}"        # tmux no permite '.' ni ':' en nombres de sesión

  # Dentro de tmux: cockpit en la ventana ACTUAL
  if [[ -n "$TMUX" ]]; then
    local panes; panes=$(tmux display-message -p '#{window_panes}')
    if (( panes > 1 )); then
      echo "Esta ventana ya tiene paneles. Abre una vacía (prefix+c) y corre nic ahí."
      return 1
    fi
    local win; win=$(tmux display-message -p '#{session_name}:#{window_index}')
    tmux rename-window "$name"
    _nic_cockpit "$win" "$PWD" "$profile"
    return
  fi

  # Fuera de tmux: reusar sesión si existe
  if tmux has-session -t "$name" 2>/dev/null; then
    tmux attach-session -t "$name"
    return
  fi

  # Fuera de tmux: sesión nueva con cockpit
  tmux new-session -d -s "$name" -c "$PWD" -x "$(tput cols)" -y "$(tput lines)"
  _nic_cockpit "$name:1" "$PWD" "$profile"
  tmux attach-session -t "$name"
}
