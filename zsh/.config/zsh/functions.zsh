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

# `claude` a secas pasa por el proxy de failover (teamclaude, ver docs/claude-code.md)
# si está arriba; si no, va directo. claude-profile usa `command claude` y no pasa por aquí.
function claude() {
  if curl -fs -m 1 -o /dev/null http://127.0.0.1:3456/teamclaude/status; then
    ANTHROPIC_BASE_URL=http://localhost:3456 command claude "$@"
  else
    command claude "$@"
  fi
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
  # Perfil work: proxy inverso (ccw primero, personal de respaldo) en :3457, si está arriba.
  if [[ "$profile" == work ]] && curl -fs -m 1 -o /dev/null http://127.0.0.1:3457/teamclaude/status; then
    ANTHROPIC_BASE_URL=http://localhost:3457 CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" command claude "$@"
    return
  fi
  CLAUDE_CONFIG_DIR="$HOME/.claude-$profile" command claude "$@"
}

# Workspaces de trabajo en herdr: un panel de claude por repo, a pantalla completa.
#   $1 = label del workspace   $2 = comando del panel   $3.. = directorios (una tab por directorio)
# Si el workspace ya existe no hace nada. Las tabs llevan el basename del directorio.
function _hw_workspace() {
  local label="$1" cmd="$2" dir created ws pane tab first=1
  shift 2
  herdr workspace list 2>/dev/null \
    | jq -e --arg n "$label" '.result.workspaces[]? | select(.label == $n)' >/dev/null && return
  for dir in "$@"; do
    if (( first )); then
      created=$(herdr workspace create --cwd "$dir" --label "$label" --no-focus)
      ws=$(jq -r '.result.workspace.workspace_id' <<<"$created")
      tab=$(jq -r '.result.tab.tab_id' <<<"$created")
      herdr tab rename "$tab" "${dir:t}" >/dev/null
      first=0
    else
      created=$(herdr tab create --workspace "$ws" --cwd "$dir" --label "${dir:t}" --no-focus)
    fi
    pane=$(jq -r '.result.root_pane.pane_id' <<<"$created")
    herdr pane run "$pane" "$cmd"
  done
}

# usage: hw   (sin argumentos)
#   Abre en herdr los workspaces de trabajo que falten, en este orden:
#     dotfiles, SlipStream (urbn, perfil work) y CNC (una tab por repo).
#   herdr no tiene grupos de workspaces: CNC es un workspace con una tab por repo.
#   Idempotente; termina enfocando dotfiles. Fuera de herdr attachea el cliente.
function hw() {
  _hw_workspace dotfiles    claude                  ~/dotfiles
  _hw_workspace SlipStream  'claude-profile work'   ~/Projects/urbn/SlipStream
  _hw_workspace CNC         claude                  ~/Projects/cnc/{vuf-portal,backoffice-vuf,b0-vuf-apis}

  herdr workspace focus "$(herdr workspace list | jq -r '.result.workspaces[] | select(.label == "dotfiles") | .workspace_id')" >/dev/null
  [[ -z "${HERDR_ENV:-}" ]] && herdr
}
