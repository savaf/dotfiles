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

# Coding cockpit: neovim + claude + terminal en tmux
#
# Layout: nvim alto completo a la izquierda; claude + terminal en columna derecha
#   +-------------------+----------+
#   |                   |  claude  |
#   |       nvim        +----------+
#   |                   |   term   |
#   +-------------------+----------+
#
# Arma el cockpit en la ventana destino. Captura pane-id en vez de .1/.2
# para ser robusto en macOS y WSL.
#   $1 = target tmux (session:window)   $2 = working dir
function _nic_cockpit() {
  local win="$1" dir="$2" p_nvim p_claude
  p_nvim=$(tmux display-message -p -t "$win" '#{pane_id}')
  p_claude=$(tmux split-window -h -t "$win" -c "$dir" -l 35% -P -F '#{pane_id}')
  tmux split-window -v -t "$p_claude" -c "$dir" -l 30%
  tmux send-keys -t "$p_nvim" 'nvim' C-m
  tmux send-keys -t "$p_claude" 'claude' C-m
  tmux select-pane -t "$p_nvim"
}

# usage: nic [name]   (default: basename del directorio actual)
#   - fuera de tmux: crea/attachea una sesión con el cockpit
#   - dentro de tmux: arma el cockpit en la ventana actual (un proyecto por ventana)
function nic() {
  local name="${1:-$(basename "$PWD")}"

  # Dentro de tmux: cockpit en la ventana ACTUAL
  if [[ -n "$TMUX" ]]; then
    local panes; panes=$(tmux display-message -p '#{window_panes}')
    if (( panes > 1 )); then
      echo "Esta ventana ya tiene paneles. Abre una vacía (prefix+c) y corre nic ahí."
      return 1
    fi
    local win; win=$(tmux display-message -p '#{session_name}:#{window_index}')
    tmux rename-window "$name"
    _nic_cockpit "$win" "$PWD"
    return
  fi

  # Fuera de tmux: reusar sesión si existe
  if tmux has-session -t "$name" 2>/dev/null; then
    tmux attach-session -t "$name"
    return
  fi

  # Fuera de tmux: sesión nueva con cockpit
  tmux new-session -d -s "$name" -c "$PWD" -x "$(tput cols)" -y "$(tput lines)"
  _nic_cockpit "$name:1" "$PWD"
  tmux attach-session -t "$name"
}
