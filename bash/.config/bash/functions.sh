# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
# Puerto casi literal de zsh/.config/zsh/functions.zsh: nada aquí era
# zsh-específico (case/for/[[ ]]/(( )) funcionan igual en bash).

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
  mkdir -p "$1" && cd "$1" || return
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

# ============================================================================
# COMMAND NOT FOUND (puerto parcial del snippet de Oh-My-Zsh/Ubuntu)
# ============================================================================
# Solo hace algo en Ubuntu/Debian (que trae /usr/lib/command-not-found); en el
# resto de plataformas, bash ya muestra su propio "command not found" y esto
# no interfiere.
if [[ -x /usr/lib/command-not-found ]]; then
  command_not_found_handle() {
    /usr/lib/command-not-found -- "$1"
    return $?
  }
fi
