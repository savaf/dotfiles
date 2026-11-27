# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

### SNAPSHOT-SAFE GIT SHORTCUTS
# gco/gp/gst vienen como aliases del plugin git de OMZ (plugins.zsh, cargado
# antes que este archivo); push es nuestro (ver aliases.zsh). Los cuatro se
# redefinen aquí como funciones porque el snapshot de shell de Claude Code
# hace `unalias -a` en cada sesión de comandos (ver docs/claude-code.md), y
# un alias no sobrevive eso aunque exista una función con el mismo nombre.
# zsh además exige el unalias previo: si el nombre sigue siendo alias al
# parsear `nombre() { ... }`, falla con "defining function based on alias".
unalias gco gp gst 2>/dev/null
gco() { git checkout "$@"; }
gp() { git push "$@"; }
gst() { git status "$@"; }  # 'status' es palabra reservada de zsh
push() { git push origin "$@"; }

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

# Claude Code con la cuenta `urbn` del swap de Omarchy, sea cual sea la activa
# (`claude` a secas usa la activa; ver docs/claude-code.md).
#   uso: ccw [args de claude...]
function ccw() {
  local home
  if ! command -v omarchy-agent-account-state >/dev/null 2>&1; then
    echo "ccw: requiere el swap de cuentas de Omarchy; no se abre Claude." >&2
    return 1
  fi
  home="$(omarchy-agent-account-state homes claude | awk -F'\t' '$1 == "urbn" { print $2 }')"
  if [[ -z "$home" ]]; then
    echo "ccw: no hay cuenta 'urbn' (créala con: omarchy agent account add claude urbn); no se abre Claude." >&2
    return 1
  fi
  CLAUDE_CONFIG_DIR="$home" command claude "$@"
}

# usage: hw   (sin argumentos)
#   Abre en herdr un solo workspace, `home`, con un claude en el Home Repo, y lo enfoca.
#   Ese agente abre los de cada proyecto cuando los necesita (ver su AGENTS.md).
#   Idempotente. Fuera de herdr attachea el cliente.
function hw() {
  local dir=~/Projects/home ws created
  if [[ ! -d "$dir" ]]; then
    echo "hw: falta $dir (clona git@github.com:savaf/home.git)." >&2
    return 1
  fi
  ws=$(herdr workspace list 2>/dev/null \
    | jq -r 'first(.result.workspaces[]? | select(.label == "home") | .workspace_id) // empty')
  if [[ -z "$ws" ]]; then
    created=$(herdr workspace create --cwd "$dir" --label home --no-focus) || return
    ws=$(jq -r '.result.workspace.workspace_id' <<<"$created")
    herdr pane run "$(jq -r '.result.root_pane.pane_id' <<<"$created")" claude
  fi
  herdr workspace focus "$ws" >/dev/null
  [[ -z "${HERDR_ENV:-}" ]] && herdr
  return 0
}
